part of 'soft_deletion_impl.dart';

/// This implementation of SyncDelegate utilises Firestore as remote and Sembast as local storage
/// All synced data repository should implement [FirestoreSymbastSyncableRepo] interface to ensure data are read/write correctly
/// following a standard approach to soft delete amd read only from cache
/// Firestore has a TTL deletion that is perfect for this use case:
/// https://firebase.google.com/docs/firestore/ttl
class FirestoreSoftSyncRepo<T extends SyncEntity> extends SyncRepo<T> with FirestoreHelper, Loggable {
  /// A callback to retrieve the sync query for this delegate/collection
  final FirestoreSyncQuery<T> syncQuery;

  // mappers
  final JsonMapper<T> firestoreMapper;
  final JsonMapper<T> sembastMapper;

  FirestoreSoftSyncRepo({
    required super.path,
    super.idField,
    super.updateField,
    super.createField,
    required this.syncQuery,
    required this.firestoreMapper,
    required this.sembastMapper,
  });

  // service
  @override
  FirestoreSoftSyncService get syncService => super.syncService as FirestoreSoftSyncService;
  Future<DateTime> get currentTime async => syncService.currentTime;
  fs.FirebaseFirestore get firestore => syncService.firestore;
  sb.Database get db => syncService.db;

  // collection
  late final fs.CollectionReference<JsonObject> collection = firestore.collection(path);
  late final fs.CollectionReference<T> typedCollection = collection.withConverter(
    fromFirestore: (value, __) => firestoreMapper.fromMap(value.data()!),
    toFirestore: (value, __) => firestoreMapper.toMap(value),
  );
  late final sb.StoreRef<String, JsonObject> store = sb.StoreRef(path);

  // trash
  late final sb.StoreRef<String, JsonObject> trashStore = sb.StoreRef(trashPath);
  late final fs.CollectionReference<JsonObject> trashCollection = firestore.collection(trashPath);
  late final fs.CollectionReference<T> trashTypedCollection = trashCollection.withConverter(
    fromFirestore: (value, __) => firestoreMapper.fromMap(value.data()!),
    toFirestore: (value, __) => firestoreMapper.toMap(value),
  );

  Completer<bool> _sessionCompleter = Completer();
  @override
  Future<bool> get sessionIsReady => _sessionCompleter.future;

  StreamSubscription? _syncSubscription;

  /// Starts the sync operation when user logs in
  @override
  Future<void> startSync() async {
    _sessionCompleter = Completer();

    if (userId.isEmpty) {
      throw Exception('$debugDetails startSync: session userId must not be empty');
    }

    devLog('$debugDetails startSync: initialising cache');

    final lastUpdatedAt = (await getLatestRecordFromCache())?[updateField];

    devLog('$debugDetails startSync: setting up sync listener');
    final stream = _watchRemoteChanges(
      lastUpdatedAt: lastUpdatedAt,
      userId: userId,
    ).handleError((error, stacktrace) {
      devLog('$debugDetails startSync: exception occurred while watching changes',
          error: error, stackTrace: stacktrace);
    });
    _syncSubscription = stream.listen(_handleRemoteChanges);

    devLog('$debugDetails startSync: sync session initialised');
  }

  /// Stops the sync operation when user logs out
  @override
  Future<void> stopSync() async {
    await _syncSubscription?.cancel();
  }

  /// Returns the last record in the cache.
  /// This will be used as the seed to fetch new data from remote to cache
  Future<JsonObject?> getLatestRecordFromCache() async {
    final record = await store.find(db,
        finder: sb.Finder(
          sortOrders: [sb.SortOrder(updateField, false)],
          limit: 1,
        ));
    return record.firstOrNull?.value;
  }

  /// Returns the last trash in the cache.
  Future<JsonObject?> getLatestTrashFromCache() async {
    final record = await trashStore.find(db,
        finder: sb.Finder(
          sortOrders: [sb.SortOrder(updateField, false)],
          limit: 1,
        ));
    return record.firstOrNull?.value;
  }

  @override
  Future<void> clearCache() async {
    await store.delete(db);
  }

  /// When the sync starts (when [startSync] is called), this method will be called to create a stream to retrieve
  /// data changes from remote. The stream is closed when [stopSync] is called.
  Stream<fs.QuerySnapshot<T>> _watchRemoteChanges({
    required DateTime? lastUpdatedAt,
    required String userId,
  }) {
    var query = syncQuery(typedCollection, userId);
    if (lastUpdatedAt != null) {
      devLog('$debugDetails watchChanges: watching documents where "updatedAt" > $lastUpdatedAt');
      query = query.where(updateField, isGreaterThan: lastUpdatedAt.toIso8601String());
    } else {
      devLog('$debugDetails watchChanges: watching all user documents in collection');
    }
    return query.snapshots();
  }

  Future<void> _handleRemoteChanges(fs.QuerySnapshot<T> snapshot) async {
    if (snapshot.docChanges.isEmpty) {
      devLog('$debugDetails _handleRemoteChanges: no changes detected');
    } else {
      // ensure data is from remote
      if (snapshot.metadata.isFromCache) {
        return;
      }
      final changes = snapshot.docChanges.groupListsBy((e) => e.type);
      final added = changes[fs.DocumentChangeType.added]?.map((e) => e.doc) ?? [];
      final modified = changes[fs.DocumentChangeType.modified]?.map((e) => e.doc) ?? [];
      final updated = [...added, ...modified];
      final removed = changes[fs.DocumentChangeType.removed]?.map((e) => e.doc) ?? [];
      if (updated.isNotEmpty) {
        final putIds = updated.map((e) => e.id);
        putCache(updated).then((_) {
          devLog(
              '$debugDetails _handleRemoteChanges: found and cached ${putIds.length} documents from remote: $putIds');
        });
      }

      if (removed.isNotEmpty) {
        final removedIds = removed.map((e) => e.id).toSet();
        await moveToTrash(removed);
        devLog(
            '$debugDetails _handleRemoteChanges: found and removed ${removedIds.length} documents from cache: $removedIds');
      }
    }
    // signal that the first set of changes have been received
    if (!_sessionCompleter.isCompleted) {
      _sessionCompleter.complete(true);
    }
  }

  Future<void> putCache(List<fs.DocumentSnapshot<T>> values) async {
    final ids = values.map((e) => e.id);
    final sembastValues = values.map((e) => sembastMapper.toMap(e.data()!)).toList();
    await store.records(ids).put(db, sembastValues);
  }

  /// Move cached records to trash
  Future<void> moveToTrash(Iterable<fs.DocumentSnapshot<T>> values) async {
    final ids = values.map((e) => e.id);
    final sembastValues = values.map((e) => sembastMapper.toMap(e.data()!)).toList();
    await store.records(ids).delete(db);
    await trashStore.records(ids).put(db, sembastValues);
  }

  /// Dispose trash by removing anything that is older than cut off date
  Future<void> disposeTrash({required DateTime cutoff}) async {
    devLog('$debugDetails disposeTrash: disposing trash older than $cutoff');
    final cachedTrash = (await trashStore.find(
      db,
      finder: sb.Finder(
        filter: sb.Filter.lessThan(updateField, cutoff.toIso8601String()),
      ),
    ));
    final cachedTrashIds = cachedTrash.map((e) => e.key);
    await trashStore.records(cachedTrashIds).delete(db);
    devLog('$debugDetails disposeTrash: ${cachedTrash.length} trash disposed from cache: $cachedTrashIds');

    final remoteTrash = await trashTypedCollection
        .where(
          updateField,
          isLessThan: cutoff.toIso8601String(),
        )
        .get();
    final remoteTrashIds = remoteTrash.docs.map((e) => e.id);
    final batch = firestore.batch();
    for (var id in remoteTrashIds) {
      batch.delete(trashTypedCollection.doc(id));
    }
    await batch.commit();
    devLog('$debugDetails disposeTrash: ${remoteTrashIds.length} trash disposed on remote: $remoteTrashIds');
  }

  Future<List<T>> fetchTrashFromRemoteBefore(DateTime before) async {
    final remoteTrash = await trashTypedCollection
        .where(
          updateField,
          isLessThan: before.toIso8601String(),
        )
        .get();
    return remoteTrash.data;
  }

  /// Update local cache by fetching the latest records from remote
  /// 1. Get latest record from cache to determine updatedAt delta offset
  /// 2. Get latest trash from cache to determine updatedAt delta offset
  /// 3. Fetch the delta on remote to put into cache (ensuring that is is from remote and not from firestore cache)
  Future<void> updateCache() async {
    // get latest from cache
    final latestCachedRecord = await getLatestRecordFromCache();
    final lastUpdatedAt = latestCachedRecord?[updateField];

    // get latest trash from cache.
    final latestCachedTrash = await getLatestTrashFromCache();
    final lastTrashAt = latestCachedTrash?[updateField];

    // update records
    (typedCollection
            .where(
              updateField,
              isGreaterThan: lastUpdatedAt,
            )
            .get())
        .then(
      (snapshot) {
        // ensure data is from remote
        if (snapshot.metadata.isFromCache) {
          return;
        }
        final docs = snapshot.docs;
        final ids = docs.map((e) => e.id);
        final data = docs.map((e) => sembastMapper.toMap(e.data())).toList();
        store.records(ids).put(db, data);
      },
    );

    // update trash
    (trashTypedCollection
            .where(
              updateField,
              isGreaterThan: lastTrashAt,
            )
            .get())
        .then(
      (snapshot) {
        // ensure data is from remote
        if (snapshot.metadata.isFromCache) {
          return;
        }
        final docs = snapshot.docs;
        final ids = docs.map((e) => e.id);
        final sembastValues = docs.map((e) => sembastMapper.toMap(e.data())).toList();

        // move to trash
        db.transaction((transaction) async {
          await store.records(ids).delete(transaction);
          await trashStore.records(ids).put(transaction, sembastValues);
        });
      },
    );
  }

  //////////// CRUD OPTIONS

  @override
  Future<T?> get(String id) async {
    devLog('$debugDetails get: id=$id');
    final record = await store.record(id).get(db);
    return sembastMapper.fromMapOrNull(record);
  }

  @override
  Future<T> create(T value) async {
    devLog('$debugDetails create: id=${value.id}');

    // setup
    final T clone = value.clone();
    if (clone.id.isEmpty) {
      clone.id = typedCollection.doc().id;
    }
    clone.createdAt = clone.updatedAt = await currentTime;

    // transaction
    await db.transaction((transaction) async {
      await store.record(clone.id).put(transaction, sembastMapper.toMap(clone));
      await typedCollection.doc(clone.id).set(clone);
    });

    return clone;
  }

  @override
  Future<T> update(T value) async {
    devLog('$debugDetails update: id=${value.id}');

    // setup
    final T clone = value.clone();
    clone.updatedAt = await currentTime;

    // transaction
    await db.transaction((transaction) async {
      await store.record(clone.id).put(transaction, sembastMapper.toMap(clone));
      await typedCollection.doc(clone.id).set(clone, fs.SetOptions(merge: true));
    });
    return clone;
  }

  @override
  Future<T> upsert(T value) async {
    devLog('$debugDetails upsert: id=${value.id}');
    return update(value);
  }

  @override
  Future<T> delete(T value) async {
    devLog('$debugDetails delete: id=${value.id}');

    final T clone = value.clone();
    clone.updatedAt = await currentTime;

    // transaction
    await db.transaction((transaction) async {
      // move to trash in cache
      await store.record(clone.id).delete(transaction);
      await trashStore.record(clone.id).put(transaction, sembastMapper.toMap(clone));
      final batch = firestore.batch();
      // move to trash on remote
      batch.set(trashTypedCollection.doc(clone.id), clone);
      batch.delete(typedCollection.doc(clone.id));
      await batch.commit();
    });
    return clone;
  }

  @override
  Future<T?> deleteById(String id) async {
    devLog('$debugDetails deleteById: id=$id');
    final value = await get(id);
    if (value == null) {
      return null;
    }
    return delete(value);
  }

  //////////// BATCH OPTIONS

  @override
  Future<List<T>> batchGet(Set<String> ids) async {
    devLog('$debugDetails batchGet: count=${ids.length} ids=$ids');
    ids.remove('');
    if (ids.isEmpty) {
      return [];
    }
    final records = await store.records(ids).get(db);
    final objects = records.whereNotNull().map((e) => sembastMapper.fromMap(e));
    return objects.toList();
  }

  @override
  Future<List<T>> batchCreate(List<T> values) async {
    devLog('$debugDetails batchCreate: count=${values.length}');
    // if empty, nothing to do
    if (values.isEmpty) {
      return values;
    }

    // set up
    final now = await currentTime;
    final clones = values.map((e) => e.clone() as T).toList();
    for (var clone in clones) {
      clone.createdAt = clone.updatedAt = now;
    }
    final ids = clones.map((e) => e.id);
    final sembastValues = clones.map((e) => sembastMapper.toMap(e)).toList();
    final batch = firestore.batch();
    for (var clone in clones) {
      batch.set(typedCollection.doc(clone.id), clone);
    }

    // transaction
    await db.transaction((transaction) async {
      await store.records(ids).add(transaction, sembastValues);
      await batch.commit();
    });

    devLog('batchCreate: ${ids.length} documents created successfully!: $ids');
    return clones;
  }

  @override
  Future<List<T>> batchUpdate(List<T> values) async {
    devLog('$debugDetails batchUpdate: count=${values.length}');
    // if empty, nothing to do
    if (values.isEmpty) {
      return values;
    }

    // set up
    final now = await currentTime;
    final clones = values.map((e) => e.clone() as T).toList();
    for (var clone in clones) {
      clone.updatedAt = now;
    }

    final ids = clones.map((e) => e.id);
    final sembastValues = clones.map((e) => sembastMapper.toMap(e)).toList();

    // transaction
    await db.transaction((transaction) async {
      await store.records(ids).put(transaction, sembastValues);
      final batch = firestore.batch();
      for (var clone in clones) {
        batch.set(typedCollection.doc(clone.id), clone, fs.SetOptions(merge: true));
      }
      await batch.commit();
    });

    devLog('batchUpdate: ${ids.length} documents updated successfully!: $ids');
    return clones;
  }

  @override
  Future<List<T>> batchUpsert(List<T> values) async {
    devLog('$debugDetails batchUpsert: count=${values.length}');
    return batchUpdate(values);
  }

  @override
  Future<List<T>> batchDelete(List<T> values) async {
    devLog('$debugDetails batchDelete: count=${values.length}');
    // if empty, nothing to do
    if (values.isEmpty) {
      return values;
    }

    // set up
    final now = await currentTime;
    final clones = values.map((e) => e.clone() as T).toList();
    for (var clone in clones) {
      clone.updatedAt = now;
    }
    final sembastValues = clones.map((e) => sembastMapper.toMap(e)).toList();
    final ids = clones.map((e) => e.id);

    // transaction
    await db.transaction((transaction) async {
      // move to trash in cache
      await store.records(ids).delete(transaction);
      await trashStore.records(ids).put(transaction, sembastValues);

      final batch = firestore.batch();
      for (var clone in clones) {
        // move to trash on remote
        batch.set(trashTypedCollection.doc(clone.id), clone);
        batch.delete(typedCollection.doc(clone.id));
      }
      await batch.commit();
    });

    devLog('batchDelete: ${ids.length} documents deleted successfully!: $ids');
    return clones;
  }

  @override
  Future<List<T>> batchDeleteByIds(Set<String> ids) async {
    devLog('$debugDetails batchDeleteByIds: ids=$ids');
    final values = await batchGet(ids);
    return batchDelete(values);
  }

  //////////// DEBUG OPTIONS

  @override
  Future<List<T>> getAll() async {
    devLog('$debugDetails getAll');
    final records = await store.find(db);
    final objects = records.whereNotNull().map((e) => sembastMapper.fromMap(e.value));
    return objects.toList();
  }

  @override
  Stream<List<T>> watchAll() {
    devLog('$debugDetails watchAll');
    return store.query().onSnapshots(db).map((snapshots) {
      return snapshots.map((record) {
        return sembastMapper.fromMap(record.value);
      }).toList();
    });
  }

  @override
  Future<List<T>> deleteAll() async {
    devLog('$debugDetails deleteAll');
    List<T> cachedDocs = [];

    // Get all documents from cache to delete from cache and remote
    cachedDocs = await getAll();
    await batchDelete(cachedDocs);
    devLog('$debugDetails deleteAll: Deleted ${cachedDocs.length} from cache/remote documents');

    // Also retrieve documents from remote in case cache is not in sync
    final remoteDocs = (await typedCollection.get()).docs.map((e) => e.data()).toList();
    if (remoteDocs.isEmpty) return cachedDocs;
    devLog('$debugDetails deleteAll: Found and deleted ${remoteDocs.length} remote documents not in cache.');
    await batchDelete(remoteDocs);

    return [...cachedDocs, ...remoteDocs];
  }

  //////////// TRASH

  Future<List<T>> getTrash() async {
    devLog('getTrash');
    final records = await trashStore.find(db);
    final objects = records.whereNotNull().map((e) => sembastMapper.fromMap(e.value));
    return objects.toList();
  }

  Stream<List<T>> watchTrash() {
    devLog('$debugDetails watchTrash');
    return trashStore.query().onSnapshots(db).map((snapshots) {
      return snapshots.map((record) {
        return sembastMapper.fromMap(record.value);
      }).toList();
    });
  }

  /// For each delegate, dispose trash by removing anything that is older than cut off date
  Future<void> disposeOldTrash({
    required DateTime cutoff,
  }) async {
    devLog('disposeOldTrashInCollection: disposing trash older than $cutoff in $trashPath');
    final cachedTrashRecords = (await trashStore.find(
      db,
      finder: sb.Finder(
        filter: sb.Filter.lessThan(updateField, cutoff.toIso8601String()),
      ),
    ))
        .map((e) => e);
    final cachedTrashIds = cachedTrashRecords.map((e) => e.key);
    await trashStore.records(cachedTrashIds).delete(db);
    devLog('disposeOldTrashInCollection: ${cachedTrashIds.length} records disposed from cache: $cachedTrashIds');

    final remoteSnapshot = await trashTypedCollection
        .where(
          updateField,
          isLessThan: cutoff.toIso8601String(),
        )
        .get();
    final remoteTrashIds = remoteSnapshot.docs.map((doc) => doc.id);
    final batch = firestore.batch();
    for (var id in remoteTrashIds) {
      batch.delete(trashTypedCollection.doc(id));
    }
    await batch.commit();
    devLog('disposeOldTrashInCollection: ${remoteTrashIds.length} records disposed from remote: $remoteTrashIds');
  }
}
