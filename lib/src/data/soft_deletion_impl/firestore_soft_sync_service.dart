part of 'soft_deletion_impl.dart';

/// Sync service must be started each time a user logs into a session
/// It manages the lifecycle of each sync delegate during the user session
class FirestoreSoftSyncService extends SyncService with Loggable {
  /// This is the offset duration that a device can be offline before its cache may be invalidated.
  /// The default value is 14 days.
  ///
  /// This is needed to support the disposal of old trash. When old trash is disposed of, it will use this value
  /// to determine the cutoff time of the disposal. If the device comes back online after this cut off time,
  /// and itself wasn't the last disposer, then there is a chance that its cache may have deleted/disposed records.
  ///
  /// Example without disposalAge and disposalCutoff:
  /// deviceA goes offline, deviceB deletes 10 records, deviceB dispose trash and those records are gone.
  /// deviceA comes back online and queries the delta and find no results. deviceA will have 10 ghost records in cache.
  ///
  /// Example with disposalAge and disposalCutoff of 14 days (with invalid cache):
  /// deviceA goes offline on 1st Jan, deviceB deletes 10 records on 2nd Jan, deviceB dispose trash on 17th Jan and
  /// signed a new cutOff time of 3rd Jan. At this point, the 10 records are permanently gone.
  /// deviceA comes back online on 18th Jan, it checks the registry and determined that the last time it was online,
  /// is before the cutOff time, and it wasn't the last device that was doing the disposing, so it invalidates its
  /// cache and resync with the server.
  ///
  /// Example with disposalAge and disposalCutoff of 14 days (but with valid cache):
  /// deviceA goes offline on 14th Jan, deviceB deletes 10 records on 2nd Jan, deviceB dispose trash on 17th Jan and
  /// signed a new cutOff time of 3rd Jan. At this point, the 10 records are permanently gone.
  /// deviceA comes back online on 18th Jan, it checks the registry and determined that the last time it was online,
  /// is after the cutOff time, so it assumes that the cache is valid and fetch the deltas normally.
  ///
  /// Example with disposalAge and disposalCutoff of 14 days (but only 1 device is syncing):
  /// deviceA goes offline on 1st Jan, deviceA comes back online on 31st of Jan. It checks the registry and determined
  /// that it is the last device that synced, therefore its cache is still valid and fetch deltas normally.
  final Duration disposalAge;

  /// The number of retries when a sync operation fails. Defaults to 3.
  final int retriesOnFailure;

  /// The duration between retries when sync operation fails. Defaults to 3 seconds.
  final Duration retryInterval;

  final DatabaseProvider databaseProvider;

  FirestoreSoftSyncService({
    required List<FirestoreSoftSyncDelegate> delegates,
    super.deviceIdProvider,
    super.timestampProvider,
    required this.firestore,
    this.disposalRegistryPath = 'disposalRegistry',
    this.disposalAge = const Duration(days: 14),
    this.retriesOnFailure = 3,
    this.retryInterval = const Duration(seconds: 3),
    DatabaseProvider? databaseProvider,
  })  : databaseProvider = databaseProvider ?? DatabaseProvider(),
        super(delegates: delegates);

  // firestore
  final fs.FirebaseFirestore firestore;
  sb.Database get sembastDb => databaseProvider.sembastDb;

  @override
  List<FirestoreSoftSyncDelegate> get delegates => super.delegates as List<FirestoreSoftSyncDelegate>;

  // disposal registry
  final String disposalRegistryPath;
  final FirestoreDisposalRegistryMapper _disposalRegistryMapper = FirestoreDisposalRegistryMapper();
  late final fs.CollectionReference<Map<String, dynamic>> registryCollection =
      firestore.collection(disposalRegistryPath);
  late final fs.CollectionReference<DisposalRegistry> registryTypedCollection = registryCollection.withConverter(
    fromFirestore: (value, __) {
      return _disposalRegistryMapper.fromMap(value.data()!);
    },
    toFirestore: (value, __) {
      return _disposalRegistryMapper.toMap(value);
    },
  );

  @override
  Future<void> beforeStarting() async {
    devLog('$debugDetails beforeStarting: waiting for local database to be ready...');
    await databaseProvider.getOrOpenLocalDatabase(userId: userId, deviceId: deviceId);

    devLog('$debugDetails beforeStarting: validating cache against remote...');
    final registry = await validateCache();

    devLog('$debugDetails beforeStarting: updating cache against remote...');
    await updateCache();

    devLog('$debugDetails beforeStarting: disposing old records from trash...');
    await disposeOldTrash(registry);
  }

  /// Validates the cache against the remote by clearing cache if it is found to be invalid
  Future<DisposalRegistry> validateCache([DisposalRegistry? registry]) async {
    registry ??= await getOrSetRegistry();
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

  DateTime calculateDisposalCutoff(DateTime currentTime) {
    return currentTime.subtract(disposalAge);
  }

  /// Returns the cut off time of disposal based disposalAge
  Future<DateTime> get disposalCutoff async {
    final now = await currentTime;
    return now.subtract(disposalAge);
  }

  /// Dispose trash by removing any records that are older than the cutoff date
  Future<DisposalRegistry> disposeOldTrash([DisposalRegistry? registry]) async {
    registry ??= await getOrSetRegistry();
    final currentCutoff = registry.disposalCutoff;
    final now = await currentTime;
    final newCutoff = calculateDisposalCutoff(now);
    if (newCutoff.isBefore(currentCutoff)) {
      throw StateError('New cutoff ($newCutoff) cannot be before current cutoff ($currentCutoff)');
    }

    // before we do anything, sign the disposal to move the cutoff forward
    final update = {
      DisposalRegistry.lastDisposedByDeviceIdField: deviceId,
      DisposalRegistry.disposalCutoffField: newCutoff.toIso8601String(),
      '${DisposalRegistry.deviceLastDisposalField}.$deviceId': now.toIso8601String(),
    };
    // devLog('$debugDetails disposeOldTrash: registering disposal attempt: $update');
    // ensure to use the same collection for updates to trigger collection listeners
    // There was a bug where if we update using a normal collection, that the watchRegistry stream does
    // not get triggered because it was expecting to listen to a typedCollection
    await registryTypedCollection.doc(userId).update(update);

    // Disposal should be done in a batch to ensure that it succeeds and write to registry in one single
    // operation. Although there is a limitation of 500 documents per batch... So therefore its
    // probably best to batch it per delegate
    for (var delegate in delegates) {
      await delegate.disposeTrash(cutoff: newCutoff);
    }
    return registry;
  }

  /// Returns the disposal registry for the user, if empty set it first before returning it.
  Future<DisposalRegistry> getOrSetRegistry() async {
    devLog('$debugDetails getOrSetRegistry: userId=$userId');
    final doc = registryTypedCollection.doc(userId);
    DisposalRegistry? registry = (await doc.get()).data();
    if (registry == null) {
      registry = DisposalRegistry(
        userId: userId,
        disposalCutoff: calculateDisposalCutoff(await currentTime),
      );
      await doc.set(registry);
    }
    return registry;
  }

  Stream<DisposalRegistry> watchRegistry() {
    return registryTypedCollection.doc(userId).snapshots().map(
          (e) => e.data() ?? DisposalRegistry(userId: userId),
        );
  }
}
