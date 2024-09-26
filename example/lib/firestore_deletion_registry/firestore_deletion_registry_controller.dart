part of 'firestore_deletion_registry.dart';

/// Storing all dependencies in this class to easily reference them.
class Constants {
  static const userA = 'userA';
  static const serviceA = 'serviceA';
  static const serviceB = 'serviceB';
  static const deviceB = 'deviceB';
}

class FirestoreDeletionRegistryController extends GetxController with StateMixin {
  FirestoreSyncService get syncServiceA => Get.find(tag: Constants.serviceA);
  FirestoreSyncService get syncServiceB => Get.find(tag: Constants.serviceB);
  FakeFirestoreSyncedRepo get syncedRepoA => Get.find(tag: Constants.serviceA);
  FakeFirestoreSyncedRepo get syncedRepoB => Get.find(tag: Constants.serviceB);
  FirestoreMockRemoteRepo get remoteRepo => Get.find();

  /// Store all synced data here
  final RxList<FakeSyncEntity> syncedDataA = <FakeSyncEntity>[].obs;
  final RxList<FakeSyncEntity> syncedDataB = <FakeSyncEntity>[].obs;

  /// Store the sync state
  Rx<SyncState> syncStateA = SyncState.stopped.obs;
  Rx<SyncState> syncStateB = SyncState.stopped.obs;

  /// Store all remote data here
  final RxList<FakeSyncEntity> remoteData = <FakeSyncEntity>[].obs;

  /// Store the deletion registry to review what has changed
  Rx<DeletionRegistry> registry = DeletionRegistry(userId: '').obs;

  @override
  void onInit() async {
    super.onInit();
    final firestore = FakeFirebaseFirestore();
    final collectionProvider = CollectionProvider(
      collections: [
        FirestoreCollectionInfo(
          path: FakeSyncEntity.collectionPath,
          syncQuery: (collection, userId) => collection,
        ),
        // Example of collection that is not synced but still needs to be garbage collected
        // CollectionInfo(path: 'unSyncedCollection'),
      ],
    );
    // the default sync service
    final serviceA = Get.put(
        FirestoreSyncService(
          firestore: firestore,
          // make the signing debounce shorter for testing purpose
          signingDebounce: Duration(seconds: 5),
          collectionProvider: collectionProvider,
        ),
        tag: Constants.serviceA);

    // create another instance of sync service to emulate multiple devices
    final serviceB = Get.put(
        FirestoreSyncService(
          firestore: firestore,
          // make the signing debounce shorter for testing purpose
          signingDebounce: Duration(seconds: 5),
          collectionProvider: collectionProvider,
          deviceIdProvider: FakeDeviceIdProvider(Constants.deviceB),
        ),
        tag: Constants.serviceB);

    Get.put(
        FakeFirestoreSyncedRepo(
          path: FakeSyncEntity.collectionPath,
          syncService: serviceA,
        ),
        tag: Constants.serviceA);
    Get.put(
        FakeFirestoreSyncedRepo(
          path: FakeSyncEntity.collectionPath,
          syncService: serviceB,
        ),
        tag: Constants.serviceB);
    Get.put(
      FirestoreMockRemoteRepo(
        path: FakeSyncEntity.collectionPath,
        syncService: serviceA,
        collectionProvider: collectionProvider,
      ),
    );

    // start the sync processes
    await serviceA.startSync(userId: Constants.userA);
    await serviceB.startSync(userId: Constants.userA);
    syncedDataA.bindStream(syncedRepoA.watchAll());
    syncedDataB.bindStream(syncedRepoB.watchAll());
    remoteData.bindStream(remoteRepo.watchAll());
    syncStateA.bindStream(syncServiceA.watchSyncState());
    syncStateB.bindStream(syncServiceB.watchSyncState());
    registry.bindStream(syncServiceA.watchRegistry());
    change(true, status: RxStatus.success());
  }

  FakeSyncEntity generateRandomData() {
    final random = Random().nextInt(10000);
    return FakeSyncEntity(id: 'id$random', message: 'message$random');
  }
}
