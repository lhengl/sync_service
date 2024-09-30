part of 'firestore_hard_deletion.dart';

class FirestoreHardDeletionController extends GetxController with StateMixin {
  late final FakeFirebaseFirestore firestore;

  // Device A
  late final FirestoreSyncService syncServiceA;
  late final FakeFirestoreSyncRepo syncedRepoA;
  final Rx<SyncState> syncStateA = SyncState.stopped.obs;
  final RxList<FakeSyncEntity> syncedDataA = <FakeSyncEntity>[].obs;

  // Device B
  late final FirestoreSyncService syncServiceB;
  late final FakeFirestoreSyncRepo syncedRepoB;
  final Rx<SyncState> syncStateB = SyncState.stopped.obs;
  final RxList<FakeSyncEntity> syncedDataB = <FakeSyncEntity>[].obs;

  // REMOTE
  late final FakeFirestoreRemoteRepo remoteRepo;
  final RxList<FakeSyncEntity> remoteData = <FakeSyncEntity>[].obs;

  /// Store the deletion registry to review what has changed
  Rx<DeletionRegistry> registry = DeletionRegistry(userId: '').obs;

  @override
  void onInit() async {
    super.onInit();
    // firestore
    firestore = FakeFirebaseFirestore();

    // DEVICE A
    syncServiceA = FirestoreSyncService(
      firestore: firestore,
      databaseProvider: FakeDatabaseProvider(),
      // make the signing debounce shorter for testing purpose
      signingDebounce: Duration(seconds: 5),
      delegates: [
        syncedRepoA = FakeFirestoreSyncRepo(
          syncQuery: (collection, userId) => collection,
        ),
      ],
    );

    // DEVICE B
    syncServiceB = FirestoreSyncService(
      firestore: firestore,
      // make the signing debounce shorter for testing purpose
      signingDebounce: Duration(seconds: 5),
      databaseProvider: FakeDatabaseProvider(),
      deviceIdProvider: FakeDeviceIdProvider(Constants.deviceB),
      delegates: [
        syncedRepoB = FakeFirestoreSyncRepo(
          syncQuery: (collection, userId) => collection,
        ),
      ],
    );

    // REMOTE
    remoteRepo = FakeFirestoreRemoteRepo(
      syncService: syncServiceA,
    );

    // start the sync processes
    await syncServiceA.startSync(userId: Constants.userA);
    await syncServiceB.startSync(userId: Constants.userA);
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
