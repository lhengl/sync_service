part of 'deletion_registry_impl.dart';

/// Sync service must be started each time a user logs into a session
/// It manages the lifecycle of each sync delegate during the user session
class FirestoreSyncService extends SyncService with Loggable {
  /// This is the time to live duration that a device can be offline before its cache may be invalidated.
  ///
  /// The reason why we need this is because if a device goes offline indefinitely,
  /// then it will never sign any deletion. Or if it goes offline for too long then the deletion
  /// registry may become to large which will slow the cleaning process and increase network egress.
  ///
  /// The default value is 14 days.
  ///
  /// This means that if a device goes offline for 14 days, then the next time it boots up, the registry will check
  /// if the device was the last synced. If it is, then the device is considered to be in sync because no other devices
  /// have tampered. However, if another device has synced, then the cache will be invalidated.
  final Duration offlineDeviceTtl;

  /// The number of retries when a sync operation fails. Defaults to 3.
  final int retriesOnFailure;

  /// The duration between retries when sync operation fails. Defaults to 3 seconds.
  final Duration retryInterval;

  /// The minimum interval for signing deletion. That is, signing will occur in real time,
  /// but is throttled to save writes. Defaults to 1 minute. So if a user deletes 1 document, then all synced services
  /// will delete that 1 document immediately. However, subsequent deletes won't be synced until after 1 minute.
  final Duration signingDebounce;

  final DatabaseProvider databaseProvider;

  FirestoreSyncService({
    required List<FirestoreSyncDelegate> delegates,
    super.deviceIdProvider,
    super.timestampProvider,
    required this.firestore,
    this.deletionRegistryPath = 'deletionRegistry',
    DatabaseProvider? databaseProvider,
    Duration? offlineDeviceTtl,
    int? retriesOnFailure = 3,
    Duration? retryInterval,
    Duration? signingDebounce,
  })  : offlineDeviceTtl = const Duration(days: 14),
        retriesOnFailure = retriesOnFailure ?? 3,
        retryInterval = retryInterval ?? const Duration(seconds: 3),
        signingDebounce = signingDebounce ?? const Duration(minutes: 1),
        databaseProvider = databaseProvider ?? DatabaseProvider(),
        super(delegates: delegates);

  // firestore
  final fs.FirebaseFirestore firestore;
  sb.Database get sembastDb => databaseProvider.sembastDb;

  @override
  List<FirestoreSyncDelegate> get delegates => super.delegates as List<FirestoreSyncDelegate>;

  // delete registry
  final String deletionRegistryPath;
  final FirestoreDeletionRegistryMapper _deletionRegistryMapper = FirestoreDeletionRegistryMapper();
  late final fs.CollectionReference deletionCollection = firestore.collection(deletionRegistryPath);
  late final fs.CollectionReference<DeletionRegistry> deletionTypedCollection = deletionCollection.withConverter(
    fromFirestore: (value, __) {
      return _deletionRegistryMapper.fromMap(value.data()!);
    },
    toFirestore: (value, __) {
      return _deletionRegistryMapper.toMap(value);
    },
  );

  @override
  Future<void> beforeStarting() async {
    devLog('$debugDetails beforeStarting: waiting for local database to be ready...');
    await databaseProvider.closeLocalDatabase(); // close the previous database
    await databaseProvider.getOrOpenLocalDatabase(userId: userId, deviceId: deviceId);

    devLog('$debugDetails beforeStarting: cleaning and validating registry...');
    await cleanAndValidateCache();
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
    await databaseProvider.closeLocalDatabase();
  }

  Future<void> cleanAndValidateCache() async {
    devLog('$debugDetails cleanAndValidate: signing registry for the first time...');

    final cleanedRegistry = await RetryHelper(
      retries: retriesOnFailure,
      retryInterval: retryInterval,
      future: () async {
        devLog('$debugDetails cleanAndValidate: cleaning registry...');
        return cleanRegistry();
      },
    ).retry();

    if (cleanedRegistry.cacheIsInvalid(deviceId)) {
      devLog('$debugDetails cleanAndValidate: No device found on registry. Cache is invalid and must be cleared.');
      await RetryHelper(
        retries: retriesOnFailure,
        retryInterval: retryInterval,
        future: () async {
          for (var delegate in delegates) {
            devLog('$debugDetails cleanAndValidate: Clearing cache for "${delegate.collectionPath}"...');
            await delegate.clearCache();
            devLog('$debugDetails cleanAndValidate: Cached cleared for "${delegate.collectionPath}".');
          }
        },
      ).retry();
    }
  }

  /// To clean the registry, it is important to do so in a transaction where
  /// the read and write operation must be done atomically to ensure that the cleaning is not
  /// tampered by another operation. The cleaning process is as follow:
  /// 1. Read registry from firestore
  /// 2. Read all documents that needs to be deleted from registry
  /// 3. Delete these documents from cache
  /// 4. Sign the registry
  /// 5. Clean the registry, which will remove ids that have been signed by all devices
  /// 6. Commit the transaction, if it fails, then all changes wll be rolled back.
  ///
  /// Returns a clean COPY of the registry
  Future<DeletionRegistry> cleanRegistry() async {
    final currentTime = await this.currentTime;
    devLog(
        '$debugDetails cleanRegistry: userId=$userId deviceId=$deviceId currentTime=$currentTime timeToLive=${offlineDeviceTtl.pretty()}');

    // cancel the next call to signing, because we are already signing during the cleaning.
    _resetSigningDebounce();

    final registry = await sembastDb.transaction((sembastTransaction) async {
      final registry = await firestore.runTransaction((firestoreTransaction) async {
        final docRef = deletionTypedCollection.doc(userId);
        final registry = (await firestoreTransaction.get(docRef)).data() ?? DeletionRegistry(userId: userId);

        devLog('$debugDetails cleanRegistry: signing deletions on registry');
        final idsByCollection = registry.groupIdsByCollection();
        for (var collection in idsByCollection.entries) {
          final collectionId = collection.key;
          final docIds = collection.value;
          if (docIds.isNotEmpty) {
            final removedIds =
                (await sb.StoreRef(collectionId).records(docIds).delete(sembastTransaction)).whereNotNull();

            if (removedIds.isNotEmpty) {
              devLog(
                  '$debugDetails cleanRegistry: removed ${removedIds.length} documents from "$collectionId" cache: $removedIds');
            }
          }
        }
        registry.signDeletions(deviceId: deviceId, idsByCollection: idsByCollection);

        devLog('$debugDetails cleanRegistry: cleaning registry');
        registry.cleanRegistry(
          deviceId: deviceId,
          currentTime: currentTime,
          timeToLive: offlineDeviceTtl,
        );

        devLog('$debugDetails cleanRegistry: submitting registry');
        firestoreTransaction.set(docRef, registry);
        return registry;
      });
      return registry;
    });
    return registry;
  }

  final Map<String, Set<String>> _singingQueue = {};

  /// This is called by delegates to queue a set of ids for deletion in a collection
  /// This will invoke [signDeletions] not more than once every [signingDebounce] interval
  void queueSigning(String collection, Set<String> ids) {
    (_singingQueue[collection] ??= {}).addAll(ids);
    signDeletions();
  }

  /// Keeps track of the number of calls to signDeletions
  int _signingCalls = 0;
  DateTime _signingDebounceExpiration = DateTime.now();
  String get _signingDebounceTag => 'signing_deletions_$deviceId';

  void _resetSigningDebounce() {
    EasyDebounce.cancel(_signingDebounceTag);
    _signingCalls = 0;
    _singingQueue.clear();
  }

  /// Sign the registry.
  /// It's OK to not sign in a transaction here because if the cache is deleted here
  /// and the we fail to write the registry we will simply try to clear the cache again.
  /// So for example, if we deleted 10 items, and we fail to sign, the 10 items are still
  /// pending deletion, so the next time we try to delete, we will try to delete the same 10 items
  /// from cache (even if it doesn't exist in cache).
  ///
  /// NOTE:
  /// Signing is not part of a transaction and can be delayed. So if a cleaning is done during this time,
  /// then signing may fire again - signing 'ids' that have already been removed. This will rectify itself when all
  /// devices complete their next clean up. However, this constant resigning can enter into an infinite cycle.
  /// To avoid this, the debounce must be cancelled if a cleaning is started.
  Future<void> signDeletions() async {
    _signingCalls++;
    devLog('$debugDetails signDeletions: _signingCalls=$_signingCalls');

    if (_signingCalls == 1) {
      _signingDebounceExpiration = DateTime.now().add(signingDebounce);
      EasyDebounce.debounce(_signingDebounceTag, signingDebounce, () async {
        if (_singingQueue.isEmpty) {
          devLog('$debugDetails signDeletions: nothing to sign, exiting...');
          return;
        }

        devLog('$debugDetails signDeletions: $_singingQueue');

        await sembastDb.transaction((sembastTransaction) async {
          final Map<String, dynamic> registryUpdate = {};

          for (var collection in _singingQueue.entries) {
            final collectionId = collection.key;
            final docIds = collection.value;
            if (docIds.isNotEmpty) {
              final removedIds =
                  (await sb.StoreRef(collectionId).records(docIds).delete(sembastTransaction)).whereNotNull();

              registryUpdate.addAll({
                'deletions.$deviceId.$collectionId': fs.FieldValue.arrayUnion(docIds.toList()),
              });

              if (removedIds.isNotEmpty) {
                devLog(
                    '$debugDetails signDeletions: removed ${removedIds.length} documents from "$collectionId" cache: $removedIds');
              }
            }
          }

          await deletionTypedCollection.doc(userId).update(registryUpdate);

          // clear queue after signing
          _singingQueue.clear();
          // reset call count
          _signingCalls = 0;
        });
      });
    } else if (_signingCalls == 2) {
      devLog('$debugDetails signDeletions: debounced, latest operation will run in '
          '${_signingDebounceExpiration.difference(DateTime.now()).pretty()}');
    }
  }

  /// Returns the deletion registry for the user, if empty set it first before returning it.
  Future<DeletionRegistry> getOrSetRegistry() async {
    devLog('$debugDetails getOrSetRegistry: userId=$userId');
    final doc = deletionTypedCollection.doc(userId);
    DeletionRegistry? registry = (await doc.get()).data();
    if (registry == null) {
      registry = DeletionRegistry(userId: userId);
      await doc.set(registry);
    }
    devLog('$debugDetails getRegistry: registry=$registry');
    return registry;
  }

  Stream<DeletionRegistry> watchRegistry() {
    return deletionTypedCollection.doc(userId).snapshots().map((e) => e.data() ?? DeletionRegistry(userId: userId));
  }
}
