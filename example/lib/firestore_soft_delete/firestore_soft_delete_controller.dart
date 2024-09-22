part of 'firestore_soft_delete.dart';

/// Storing all dependencies in this class to easily reference them.
class Constants {
  static const userA = 'userA';
  static const serviceA = 'serviceA';
  static const serviceB = 'serviceB';
  static const deviceB = 'deviceB';
}

class FirestoreSoftDeleteController extends GetxController with StateMixin {
  FirestoreSoftSyncService get syncServiceA => Get.find(tag: Constants.serviceA);
  FirestoreSoftSyncService get syncServiceB => Get.find(tag: Constants.serviceB);
  FakeFirestoreSoftSyncedRepo get syncedRepoA => Get.find(tag: Constants.serviceA);
  FakeFirestoreSoftSyncedRepo get syncedRepoB => Get.find(tag: Constants.serviceB);
  FakeFirestoreSoftRemoteRepo get remoteRepo => Get.find();

  /// Store all synced data here
  final RxList<FakeSyncEntity> syncedDataA = <FakeSyncEntity>[].obs;
  final RxList<FakeSyncEntity> syncedDataB = <FakeSyncEntity>[].obs;

  /// Store the sync state
  Rx<SyncState> syncStateA = SyncState.stopped.obs;
  Rx<SyncState> syncStateB = SyncState.stopped.obs;

  /// Store all remote data here
  final RxList<FakeSyncEntity> remoteData = <FakeSyncEntity>[].obs;

  final RxList<FakeSyncEntity> trashDataA = <FakeSyncEntity>[].obs;
  final RxList<FakeSyncEntity> trashDataB = <FakeSyncEntity>[].obs;
  final RxList<FakeSyncEntity> remoteTrash = <FakeSyncEntity>[].obs;

  /// Store the deletion registry to review what has changed
  Rx<DisposalRegistry> registry = DisposalRegistry(
    userId: '',
    disposalCutoff: null,
  ).obs;

  @override
  void onInit() async {
    super.onInit();
    final firestore = FakeFirebaseFirestore();
    // the default sync service
    final serviceA = Get.put(
        FirestoreSoftSyncService(
          // for testing, disposal age is kept at 1 minute
          // meaning that after one minute of deletion, if disposal is invoked, trash older than 1 minute will be removed
          disposalAge: 5.seconds,
          firestore: firestore,
          delegates: [
            FirestoreSoftSyncDelegate<FakeSyncEntity>(
              collectionPath: FakeSyncEntity.collectionPath,
              syncQuery: (collection, userId) => collection,
              firestoreMapper: FakeFirestoreSyncEntityMapper(),
              sembastMapper: FakeSembastSyncEntityMapper(),
            ),
          ],
        ),
        tag: Constants.serviceA);

    // create another instance of sync service to emulate multiple devices
    final serviceB = Get.put(
        FirestoreSoftSyncService(
          // for testing, disposal age is kept at 1 minute
          // meaning that after one minute of deletion, if disposal is invoked, trash older than 1 minute will be removed
          disposalAge: 5.seconds,
          firestore: firestore,
          delegates: [
            FirestoreSoftSyncDelegate<FakeSyncEntity>(
              collectionPath: FakeSyncEntity.collectionPath,
              syncQuery: (collection, userId) => collection,
              firestoreMapper: FakeFirestoreSyncEntityMapper(),
              sembastMapper: FakeSembastSyncEntityMapper(),
            ),
          ],
          deviceIdProvider: FakeDeviceIdProvider(Constants.deviceB),
        ),
        tag: Constants.serviceB);

    Get.put(
        FakeFirestoreSoftSyncedRepo(
          collectionPath: FakeSyncEntity.collectionPath,
          syncService: serviceA,
        ),
        tag: Constants.serviceA);
    Get.put(
        FakeFirestoreSoftSyncedRepo(
          collectionPath: FakeSyncEntity.collectionPath,
          syncService: serviceB,
        ),
        tag: Constants.serviceB);
    Get.put(
      FakeFirestoreSoftRemoteRepo(
        collectionPath: FakeSyncEntity.collectionPath,
        syncService: serviceA,
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
    trashDataA.bindStream(syncedRepoA.watchTrash());
    trashDataB.bindStream(syncedRepoB.watchTrash());
    remoteTrash.bindStream(remoteRepo.watchTrash());
    change(true, status: RxStatus.success());
  }

  FakeSyncEntity generateRandomData() {
    final random = Random().nextInt(10000);
    return FakeSyncEntity(id: 'id$random', message: 'message$random');
  }
}
