part of 'soft_deletion_impl.dart';

class GarbageCollector with Loggable {
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

  // disposal registry
  final String disposalRegistryPath;

  final DeviceIdProvider deviceIdProvider;

  final TimestampProvider timestampProvider;
  Future<DateTime> get currentTime async => (await timestampProvider.currentTime).toUtc();

  final CollectionProvider collectionProvider;

  final DatabaseProvider databaseProvider;

  GarbageCollector({
    required this.firestore,
    required this.collectionProvider,
    required this.databaseProvider,
    this.disposalAge = const Duration(days: 14),
    this.disposalRegistryPath = 'disposalRegistry',
    this.deviceIdProvider = const DeviceInfoDeviceIdProvider(),
    this.timestampProvider = const KronosTimestampProvider(),
  });

  final FirestoreDisposalRegistryMapper _registryMapper = FirestoreDisposalRegistryMapper();
  late final fs.CollectionReference registryCollection = firestore.collection(disposalRegistryPath);
  late final fs.CollectionReference<DisposalRegistry> registryTypedCollection = registryCollection.withConverter(
    fromFirestore: (value, __) {
      return _registryMapper.fromMap(value.data()!);
    },
    toFirestore: (value, __) {
      return _registryMapper.toMap(value);
    },
  );

  // firestore
  final fs.FirebaseFirestore firestore;

  // database provider
  sb.Database get db => databaseProvider.db;

  String _userId = '';
  String get userId => _userId;

  String? _deviceId;
  String get deviceId => _deviceId!;

  Future<void> startSession({required String userId, String? deviceId}) async {
    _userId = userId;
    _deviceId ??= deviceId ?? await deviceIdProvider.getDeviceId();
  }

  /// Dispose trash by removing any records that are older than the cutoff date
  Future<DisposalRegistry> disposeOldTrash() async {
    final registry = await getOrSetRegistry(userId: userId);
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
    // devLog('disposeOldTrash: registering disposal attempt: $update');
    // ensure to use the same collection for updates to trigger collection listeners
    // There was a bug where if we update using a normal collection, that the watchRegistry stream does
    // not get triggered because it was expecting to listen to a typedCollection
    await registryTypedCollection.doc(userId).update(update);

    // Disposal should be done in a batch to ensure that it succeeds and write to registry in one single
    // operation. Although there is a limitation of 500 documents per batch... So therefore its
    // probably best to batch it per delegate
    for (var collection in collectionProvider.collections) {
      await disposeOldTrashByCollection(cutoff: newCutoff, collectionInfo: collection);
    }
    return registry;
  }

  /// For each delegate, dispose trash by removing anything that is older than cut off date
  Future<void> disposeOldTrashByCollection({
    required DateTime cutoff,
    required FirestoreCollectionInfo collectionInfo,
  }) async {
    final updateField = collectionInfo.updateField;
    final trashPath = collectionInfo.trashPath;
    final trashStore = sb.StoreRef<String, Map<String, dynamic>>(collectionInfo.trashPath);
    final trashCollection = firestore.collection(trashPath);

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

    final remoteSnapshot = await trashCollection
        .where(
          updateField,
          isLessThan: cutoff.toIso8601String(),
        )
        .get();
    final remoteTrashIds = remoteSnapshot.docs.map((doc) => doc.id);
    final batch = firestore.batch();
    for (var id in remoteTrashIds) {
      batch.delete(trashCollection.doc(id));
    }
    await batch.commit();
    devLog('disposeOldTrashInCollection: ${remoteTrashIds.length} records disposed from remote: $remoteTrashIds');
  }

  /// Returns the disposal registry for the user, if empty set it first before returning it.
  Future<DisposalRegistry> getOrSetRegistry({required String userId}) async {
    devLog('getOrSetRegistry: userId=$userId');
    final doc = registryTypedCollection.doc(userId);
    DisposalRegistry? registry = (await doc.get()).data();
    if (registry == null) {
      registry = DisposalRegistry(
        userId: userId,
        disposalCutoff: calculateDisposalCutoff(await currentTime),
      );
      await doc.set(registry);
      devLog('getOrSetRegistry: created new registry: $registry');
    }
    return registry;
  }

  Stream<DisposalRegistry> watchRegistry() {
    return registryTypedCollection.doc(userId).snapshots().map(
          (e) => e.data() ?? DisposalRegistry(userId: userId),
        );
  }

  DateTime calculateDisposalCutoff(DateTime currentTime) {
    return currentTime.subtract(disposalAge);
  }
}
