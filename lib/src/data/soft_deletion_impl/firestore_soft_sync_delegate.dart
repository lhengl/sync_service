part of 'soft_deletion_impl.dart';

/// This implementation of SyncDelegate utilises Firestore as remote and Sembast as local storage
/// All synced data repository should implement [FirestoreSymbastSyncableRepo] interface to ensure data are read/write correctly
/// following a standard approach to soft delete amd read only from cache
/// Firestore has a TTL deletion that is perfect for this use case:
/// https://firebase.google.com/docs/firestore/ttl
class FirestoreSoftSyncDelegate extends SyncDelegate with FirestoreHelper, Loggable {
  FirestoreSoftSyncDelegate({
    required super.collectionInfo,
  });

  /// A callback to retrieve the sync query for this delegate/collection
  FirestoreSyncQuery get syncQuery => collectionInfo.syncQuery;

  // service
  @override
  FirestoreSoftSyncService get syncService => super.syncService as FirestoreSoftSyncService;
  fs.FirebaseFirestore get firestore => syncService.firestore;
  sb.Database get db => syncService.db;

  // collection
  late final fs.CollectionReference<JsonObject> collection = firestore.collection(path);
  late final sb.StoreRef<String, JsonObject> store = sb.StoreRef(path);

  // trash
  late final sb.StoreRef<String, JsonObject> trashStore = sb.StoreRef(trashPath);
  late final fs.CollectionReference<JsonObject> trashCollection = firestore.collection(trashPath);

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
  Stream<fs.QuerySnapshot<JsonObject>> _watchRemoteChanges({
    required DateTime? lastUpdatedAt,
    required String userId,
  }) {
    var query = syncQuery(collection, userId);
    if (lastUpdatedAt != null) {
      devLog('$debugDetails watchChanges: watching documents where "updatedAt" > $lastUpdatedAt');
      query = query.where(updateField, isGreaterThan: lastUpdatedAt.toIso8601String());
    } else {
      devLog('$debugDetails watchChanges: watching all user documents in collection');
    }
    return query.snapshots();
  }

  Future<void> _handleRemoteChanges(fs.QuerySnapshot<JsonObject> snapshot) async {
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

  Future<void> putCache(List<fs.DocumentSnapshot<JsonObject>> values) async {
    final ids = values.map((e) => e.id);
    final sembastValues = values.map((e) => e.data()!).toList();
    await store.records(ids).put(db, sembastValues);
  }

  /// Move cached records to trash
  Future<void> moveToTrash(Iterable<fs.DocumentSnapshot<JsonObject>> values) async {
    final ids = values.map((e) => e.id);
    final sembastValues = values.map((e) => e.data()!).toList();
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

    final remoteTrash = await trashCollection
        .where(
          updateField,
          isLessThan: cutoff.toIso8601String(),
        )
        .get();
    final remoteTrashIds = remoteTrash.docs.map((e) => e.id);
    final batch = firestore.batch();
    for (var id in remoteTrashIds) {
      batch.delete(trashCollection.doc(id));
    }
    await batch.commit();
    devLog('$debugDetails disposeTrash: ${remoteTrashIds.length} trash disposed on remote: $remoteTrashIds');
  }

  Future<List<JsonObject>> fetchTrashFromRemoteBefore(DateTime before) async {
    final remoteTrash = await trashCollection
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
    (collection
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
        final data = docs.map((e) => e.data()).toList();
        store.records(ids).put(db, data);
      },
    );

    // update trash
    (trashCollection
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
        final data = docs.map((e) => e.data()).toList();

        // move to trash
        db.transaction((transaction) async {
          await store.records(ids).delete(transaction);
          await trashStore.records(ids).put(transaction, data);
        });
      },
    );
  }
}
