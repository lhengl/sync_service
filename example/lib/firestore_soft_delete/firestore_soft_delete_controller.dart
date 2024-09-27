part of 'firestore_soft_delete.dart';

/// Storing all dependencies in this class to easily reference them.
class Constants {
  static const userA = 'userA';
  static const deviceA = 'deviceA';
  static const deviceB = 'deviceB';
}

class FirestoreSoftDeleteController extends GetxController with StateMixin {
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
  Rx<DisposalRegistry> registry = DisposalRegistry(
    userId: '',
    disposalCutoff: null,
  ).obs;

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
          path: FakeSyncEntity.collectionPath,
          syncQuery: (collection, userId) => collection,
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
          path: FakeSyncEntity.collectionPath,
          syncQuery: (collection, userId) => collection,
        ),
      ],
    );

    // REMOTE
    remoteRepo = FakeFirestoreSoftRemoteRepo(
      path: FakeSyncEntity.collectionPath,
      firestore: firestore,
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
