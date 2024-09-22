part of 'soft_deletion_impl.dart';

/// This implementation of SyncDelegate utilises Firestore as remote and Sembast as local storage
/// All synced data repository should implement [FirestoreSymbastSyncableRepo] interface to ensure data are read/write correctly
/// following a standard approach to soft delete amd read only from cache
/// Firestore has a TTL deletion that is perfect for this use case:
/// https://firebase.google.com/docs/firestore/ttl
class FirestoreSoftSyncDelegate<T extends SyncEntity> extends SyncDelegate<T> with FirestoreHelper, Loggable {
  /// A callback to retrieve the sync query for this delegate/collection
  final SyncQuery<T> syncQuery;

  final String collectionPath;

  final String idField;

  /// The field name that stores updated timestamp. Defaults to "updatedAt".
  /// Override if this is different in the collection.
  final String updatedAtField;

  FirestoreSoftSyncDelegate({
    this.updatedAtField = 'updatedAt',
    this.idField = 'id',
    required this.collectionPath,
    required this.syncQuery,
    required this.firestoreMapper,
    required this.sembastMapper,
  });

  String get debugDetails => '[UID:$userId][DEVICE:$deviceId][COLLECTION:$collectionPath]';

  // service
  @override
  FirestoreSoftSyncService get syncService => super.syncService as FirestoreSoftSyncService;
  fs.FirebaseFirestore get firestore => syncService.firestore;
  sb.Database get db => syncService.sembastDb;

  // firestore
  final JsonMapper<T> firestoreMapper;
  late final fs.CollectionReference<Map<String, dynamic>> collection = firestore.collection(collectionPath);
  late final fs.CollectionReference<T> typedCollection = collection.withConverter(
    fromFirestore: (value, __) {
      return firestoreMapper.fromMap(value.data()!);
    },
    toFirestore: (value, __) {
      return firestoreMapper.toMap(value);
    },
  );
  // sembast
  final JsonMapper<T> sembastMapper;
  late final sb.StoreRef<String, Map<String, dynamic>> store = sb.StoreRef(collectionPath);
  late final sb.StoreRef<String, Map<String, dynamic>> trashStore = sb.StoreRef(trashCollectionPath);

  String get trashCollectionPath => '${collectionPath}_trash';
  late final fs.CollectionReference trashCollection = firestore.collection(trashCollectionPath);
  late final fs.CollectionReference<T> trashTypedCollection = trashCollection.withConverter(
    fromFirestore: (value, __) {
      return firestoreMapper.fromMap(value.data()!);
    },
    toFirestore: (value, __) {
      return firestoreMapper.toMap(value);
    },
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

    final lastUpdatedAt = (await getLatestRecordFromCache())?.updatedAt;

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
  Future<T?> getLatestRecordFromCache() async {
    final record = await store.find(db,
        finder: sb.Finder(
          sortOrders: [sb.SortOrder(updatedAtField, false)],
          limit: 1,
        ));
    final value = sembastMapper.fromMapOrNull(record.firstOrNull?.value);
    return value;
  }

  /// Returns the last trash in the cache.
  Future<T?> getLatestTrashFromCache() async {
    final record = await trashStore.find(db,
        finder: sb.Finder(
          sortOrders: [sb.SortOrder(updatedAtField, false)],
          limit: 1,
        ));
    final value = sembastMapper.fromMapOrNull(record.firstOrNull?.value);
    return value;
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
      query = query.where(updatedAtField, isGreaterThan: lastUpdatedAt.toIso8601String());
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
      final added = changes[fs.DocumentChangeType.added]?.map((e) => e.doc.data()).whereNotNull().toList() ?? [];
      final modified = changes[fs.DocumentChangeType.modified]?.map((e) => e.doc.data()).whereNotNull().toList() ?? [];
      final updated = [...added, ...modified];
      final removed = changes[fs.DocumentChangeType.removed]?.map((e) => e.doc.data()).whereNotNull().toList() ?? [];
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

  Future<void> putCache(List<T> values) async {
    final ids = values.map((e) => e.id);
    final sembastValues = values.map((e) => sembastMapper.toMap(e)).toList();
    await store.records(ids).put(db, sembastValues);
  }

  /// Move cached records to trash
  Future<void> moveToTrash(List<T> values) async {
    final ids = values.map((e) => e.id);
    final sembastValues = values.map((e) => sembastMapper.toMap(e)).toList();
    await store.records(ids).delete(db);
    await trashStore.records(ids).put(db, sembastValues);
  }

  /// Dispose trash by removing anything that is older than cut off date
  Future<void> disposeTrash({required DateTime cutoff}) async {
    devLog('$debugDetails disposeTrash: disposing trash older than $cutoff');

    final cachedTrash = (await trashStore.find(
      db,
      finder: sb.Finder(
        filter: sb.Filter.lessThan(updatedAtField, cutoff.toIso8601String()),
      ),
    ))
        .map((e) => sembastMapper.fromMap(e.value));
    final cachedTrashIds = cachedTrash.map((e) => e.id);
    await trashStore.records(cachedTrashIds).delete(db);
    devLog('$debugDetails disposeTrash: ${cachedTrash.length} trash disposed from cache: $cachedTrashIds');

    final remoteTrash = await trashTypedCollection
        .where(
          updatedAtField,
          isLessThan: cutoff.toIso8601String(),
        )
        .get();
    final remoteTrashIds = remoteTrash.data.map((e) => e.id);
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
          updatedAtField,
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
    final lastUpdatedAt = latestCachedRecord?.updatedAt;

    // get latest trash from cache.
    final latestCachedTrash = await getLatestTrashFromCache();
    final lastTrashAt = latestCachedTrash?.updatedAt;

    // update records
    (collection
            .where(
              updatedAtField,
              isGreaterThan: lastUpdatedAt?.toIso8601String(),
            )
            .get())
        .then(
      (doc) {
        // ensure data is from remote
        if (doc.metadata.isFromCache) {
          return;
        }
        final remoteRecords = doc.data;
        final ids = remoteRecords.map((e) => e[idField] as String);
        store.records(ids).put(db, remoteRecords);
      },
    );

    // update trash
    (trashTypedCollection
            .where(
              updatedAtField,
              isGreaterThan: lastTrashAt?.toIso8601String(),
            )
            .get())
        .then(
      (doc) {
        // ensure data is from remote
        if (doc.metadata.isFromCache) {
          return;
        }
        final remoteRecords = doc.data;
        final sembastValues = remoteRecords.map((e) => sembastMapper.toMap(e)).toList();
        final ids = remoteRecords.map((e) => e.id);
        // move to trash
        db.transaction((transaction) async {
          await store.records(ids).delete(transaction);
          await trashStore.records(ids).put(transaction, sembastValues);
        });
      },
    );
  }
}
