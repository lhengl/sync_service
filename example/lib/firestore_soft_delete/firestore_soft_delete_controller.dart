part of 'firestore_soft_delete.dart';

/// Storing all dependencies in this class to easily reference them.
class Constants {
  static const userA = 'userA';
  static const deviceA = 'deviceA';
  static const deviceB = 'deviceB';
}

class FirestoreSoftDeleteController extends GetxController with StateMixin {
  final firestore = FakeFirebaseFirestore();

  final CollectionProvider collectionProvider = CollectionProvider(
    collections: [
      FirestoreCollectionInfo(
        path: FakeSyncEntity.collectionPath,
        syncQuery: (collection, userId) => collection,
      ),
      // Example of collection that is not synced but still needs to be garbage collected
      // CollectionInfo(path: 'unSyncedCollection'),
    ],
  );

  // Device A
  late final DatabaseProvider databaseProviderA;
  late final FirestoreSoftSyncService syncServiceA;
  GarbageCollector get garbageCollectorA => syncServiceA.garbageCollector;
  late final FakeFirestoreSoftSyncedRepo syncedRepoA;
  final RxList<FakeSyncEntity> syncedDataA = <FakeSyncEntity>[].obs;
  final Rx<SyncState> syncStateA = SyncState.stopped.obs;
  final RxList<FakeSyncEntity> trashDataA = <FakeSyncEntity>[].obs;

  // Device B
  late final DatabaseProvider databaseProviderB;
  late final FirestoreSoftSyncService syncServiceB;
  GarbageCollector get garbageCollectorB => syncServiceB.garbageCollector;
  late final FakeFirestoreSoftSyncedRepo syncedRepoB;
  final RxList<FakeSyncEntity> syncedDataB = <FakeSyncEntity>[].obs;
  final Rx<SyncState> syncStateB = SyncState.stopped.obs;
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

    // DEVICE A
    databaseProviderA = FakeDatabaseProvider();
    syncServiceA = FirestoreSoftSyncService(
      firestore: firestore,
      collectionProvider: collectionProvider,
      deviceIdProvider: FakeDeviceIdProvider(Constants.deviceA),
      garbageCollector: GarbageCollector(
        firestore: firestore,
        databaseProvider: databaseProviderA,
        collectionProvider: collectionProvider,
        disposalAge: 5.seconds, // for testing, disposal age is kept at 5 seconds
      ),
      databaseProvider: databaseProviderA,
    );
    syncedRepoA = FakeFirestoreSoftSyncedRepo(
      path: FakeSyncEntity.collectionPath,
      syncService: syncServiceA,
    );

    // DEVICE B
    databaseProviderB = FakeDatabaseProvider();
    syncServiceB = FirestoreSoftSyncService(
      firestore: firestore,
      collectionProvider: collectionProvider,
      deviceIdProvider: FakeDeviceIdProvider(Constants.deviceB),
      garbageCollector: GarbageCollector(
        firestore: firestore,
        databaseProvider: databaseProviderB,
        collectionProvider: collectionProvider,
        disposalAge: 5.seconds, // for testing, disposal age is kept at 5 seconds
      ),
      databaseProvider: databaseProviderB,
    );
    syncedRepoB = FakeFirestoreSoftSyncedRepo(
      path: FakeSyncEntity.collectionPath,
      syncService: syncServiceB,
    );

    // REMOTE
    remoteRepo = FakeFirestoreSoftRemoteRepo(
      path: FakeSyncEntity.collectionPath,
      firestore: firestore,
      collectionProvider: collectionProvider,
    );

    // start and want for sync processes
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
    registry.bindStream(garbageCollectorA.watchRegistry());
    change(true, status: RxStatus.success());
  }

  FakeSyncEntity generateRandomData() {
    final random = Random().nextInt(10000);
    return FakeSyncEntity(id: 'id$random', message: 'message$random');
  }
}
