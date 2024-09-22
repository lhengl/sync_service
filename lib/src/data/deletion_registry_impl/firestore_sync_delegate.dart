part of 'deletion_registry_impl.dart';

/// This implementation of SyncDelegate utilises Firestore as remote and Sembast as local storage
/// All synced data repository should implement [FirestoreSymbastSyncableRepo] interface to ensure data are read/write correctly
/// following a standard approach to soft delete amd read only from cache
/// Firestore has a TTL deletion that is perfect for this use case:
/// https://firebase.google.com/docs/firestore/ttl
class FirestoreSyncDelegate<T extends SyncEntity> extends SyncDelegate<T> with Loggable {
  /// A callback to retrieve the sync query for this delegate/collection
  final SyncQuery<T> syncQuery;

  final String collectionPath;

  /// The field name that stores updated timestamp. Defaults to "updatedAt".
  /// Override if this is different in the collection.
  final String updatedAtField;

  FirestoreSyncDelegate({
    this.updatedAtField = 'updatedAt',
    required this.collectionPath,
    required this.syncQuery,
    required this.firestoreMapper,
    required this.sembastMapper,
  });

  String get debugDetails => '[UID:$userId][DEVICE:$deviceId][COLLECTION:$collectionPath]';

  // service
  @override
  FirestoreSyncService get syncService => super.syncService as FirestoreSyncService;
  fs.FirebaseFirestore get firestore => syncService.firestore;
  sb.Database get sembastDb => syncService.sembastDb;

  // firestore
  final JsonMapper<T> firestoreMapper;
  late final fs.CollectionReference collection = firestore.collection(collectionPath);
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
  late final sb.StoreRef<String, Map<String, dynamic>> sembastStore = sb.StoreRef(collectionPath);

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

    final lastUpdatedAt = await getLastUpdatedAtFromCache();

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

  /// This method must be implemented to return the last updatedAt record in the cache.
  /// This will be used as the seed to fetch new data from remote to cache

  Future<DateTime?> getLastUpdatedAtFromCache() async {
    final record = await sembastStore.find(sembastDb,
        finder: sb.Finder(
          sortOrders: [sb.SortOrder(updatedAtField, false)],
          limit: 1,
        ));
    final value = sembastMapper.fromMapOrNull(record.firstOrNull?.value);
    return value?.updatedAt;
  }

  @override
  Future<void> clearCache() async {
    await sembastStore.delete(sembastDb);
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
        syncService.queueSigning(collectionPath, removedIds);
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
    await sembastStore.records(ids).put(sembastDb, sembastValues);
  }
}
