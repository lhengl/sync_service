part of 'soft_deletion_impl.dart';

/// Sync service must be started each time a user logs into a session
/// It manages the lifecycle of each sync delegate during the user session
class FirestoreSoftSyncService extends SyncService with Loggable {
  /// The number of retries when a sync operation fails. Defaults to 3.
  final int retriesOnFailure;

  /// The duration between retries when sync operation fails. Defaults to 3 seconds.
  final Duration retryInterval;

  final DatabaseProvider databaseProvider;

  final GarbageCollector garbageCollector;

  FirestoreSoftSyncService({
    super.deviceIdProvider,
    super.timestampProvider,
    required super.collectionProvider,
    required this.firestore,
    this.retriesOnFailure = 3,
    this.retryInterval = const Duration(seconds: 3),
    required this.garbageCollector,
    required this.databaseProvider,
  }) : super(
            delegates: collectionProvider.collections
                .map(
                  (collectionInfo) => FirestoreSoftSyncDelegate(collectionInfo: collectionInfo),
                )
                .toList());

  // firestore
  final fs.FirebaseFirestore firestore;

  // database provider
  sb.Database get db => databaseProvider.db;

  @override
  List<FirestoreSoftSyncDelegate> get delegates => super.delegates as List<FirestoreSoftSyncDelegate>;

  @override
  Future<void> beforeStarting() async {
    devLog('$debugDetails beforeStarting: waiting for local database to be ready...');
    await databaseProvider.openDatabase(userId: userId);

    devLog('$debugDetails beforeStarting: waiting for garbage collector to be ready...');
    // wait for garbage collector to be ready
    await garbageCollector.startSession(userId: userId, deviceId: deviceId);

    devLog('$debugDetails beforeStarting: validating cache against remote...');
    final registry = await garbageCollector.getOrSetRegistry(userId: userId);
    await validateCache(registry);

    devLog('$debugDetails beforeStarting: updating cache against remote...');
    await updateCache();

    devLog('$debugDetails beforeStarting: disposing old records from trash...');

    await garbageCollector.disposeOldTrash();
  }

  /// Validates the cache against the remote by clearing cache if it is found to be invalid
  Future<DisposalRegistry> validateCache(DisposalRegistry registry) async {
    // cache is valid, nothing to do
    if (registry.cacheIsValid(deviceId)) {
      return registry;
    }
    devLog('$debugDetails validateCache: cache is invalid and must be cleared');
    for (var delegate in delegates) {
      await delegate.clearCache();
    }
    devLog('$debugDetails validateCache: cache invalidated');
    return registry;
  }

  /// For each delegate, update its local cache by:
  /// 1. Get latest record from cache to determine updatedAt delta offset
  /// 2. Get latest trash from cache to determine updatedAt delta offset
  /// 3. Fetch the delta on remote to put into cache (ensuring that is is from remote and not from firestore cache)
  Future<void> updateCache() async {
    for (var delegate in delegates) {
      await delegate.updateCache();
    }
  }
}
