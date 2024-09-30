part of 'firestore_soft_deletion.dart';

class FirestoreSoftDeletionController extends GetxController with StateMixin {
  late final FakeFirebaseFirestore firestore;

  // Device A
  late final FirestoreSoftSyncService syncServiceA;
  late final FakeFirestoreSoftSyncedRepo syncedRepoA;
  final Rx<SyncState> syncStateA = SyncState.stopped.obs;
  final RxList<FakeSyncEntity> syncedDataA = <FakeSyncEntity>[].obs;
  final RxList<FakeSyncEntity> trashDataA = <FakeSyncEntity>[].obs;

  // Device B
  late final FirestoreSoftSyncService syncServiceB;
  late final FakeFirestoreSoftSyncedRepo syncedRepoB;
  final Rx<SyncState> syncStateB = SyncState.stopped.obs;
  final RxList<FakeSyncEntity> syncedDataB = <FakeSyncEntity>[].obs;
  final RxList<FakeSyncEntity> trashDataB = <FakeSyncEntity>[].obs;

  // REMOTE
  late final FakeFirestoreSoftRemoteRepo remoteRepo;
  final RxList<FakeSyncEntity> remoteData = <FakeSyncEntity>[].obs;
  final RxList<FakeSyncEntity> remoteTrash = <FakeSyncEntity>[].obs;

  // REGISTER
  Rx<TrashRegistry> registry = TrashRegistry(userId: '').obs;

  @override
  void onInit() async {
    super.onInit();

    // firestore
    firestore = FakeFirebaseFirestore();

    // DEVICE A
    syncServiceA = FirestoreSoftSyncService(
      firestore: firestore,
      databaseProvider: FakeDatabaseProvider(),
      deviceIdProvider: FakeDeviceIdProvider(Constants.deviceA),
      disposalAge: 5.seconds, // for testing, disposal age is kept at 5 seconds
      delegates: [
        syncedRepoA = FakeFirestoreSoftSyncedRepo(
          userQuery: (collection, userId) => collection,
        ),
      ],
    );

    // DEVICE B
    syncServiceB = FirestoreSoftSyncService(
      firestore: firestore,
      databaseProvider: FakeDatabaseProvider(),
      deviceIdProvider: FakeDeviceIdProvider(Constants.deviceB),
      disposalAge: 5.seconds, // for testing, disposal age is kept at 5 seconds
      delegates: [
        syncedRepoB = FakeFirestoreSoftSyncedRepo(
          userQuery: (collection, userId) => collection,
        ),
      ],
    );

    // REMOTE
    remoteRepo = FakeFirestoreSoftRemoteRepo(
      firestore: firestore,
      disposalAge: 5.seconds, // for testing, disposal age is kept at 5 seconds
      userTrashQuery: (collection, userId) => collection,
    );

    // start and wait for sync processes
    await Future.wait([
      syncServiceA.startSync(userId: Constants.userA),
      syncServiceB.startSync(userId: Constants.userA),
    ]);

    // remote watch
    remoteData.bindStream(remoteRepo.watchAll());
    remoteTrash.bindStream(remoteRepo.watchTrash());

    // A watch
    syncStateA.bindStream(syncServiceA.watchSyncState());
    syncedDataA.bindStream(syncedRepoA.watchAll());
    trashDataA.bindStream(syncedRepoA.watchTrash());

    // B watch
    syncStateB.bindStream(syncServiceB.watchSyncState());
    syncedDataB.bindStream(syncedRepoB.watchAll());
    trashDataB.bindStream(syncedRepoB.watchTrash());

    // registry watch
    registry.bindStream(syncServiceA.watchRegistry());
    change(true, status: RxStatus.success());
  }

  FakeSyncEntity generateRandomData() {
    final random = Random().nextInt(10000);
    return FakeSyncEntity(id: 'id$random', message: 'message$random');
  }
}
