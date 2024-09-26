import '../deletion_registry_impl/deletion_registry_impl.dart';
import 'fake_data.dart';

class FakeFirestoreSyncedRepo extends FirestoreSyncedRepo<FakeSyncEntity> {
  FakeFirestoreSyncedRepo({
    required super.path,
    required super.syncService,
  }) : super(
          firestoreMapper: FakeFirestoreSyncEntityMapper(),
          sembastMapper: FakeSembastSyncEntityMapper(),
        );

  @override
  Future<DateTime> get currentTime async => DateTime.now().toUtc();
}

class FirestoreMockRemoteRepo extends FirestoreRemoteRepo<FakeSyncEntity> {
  FirestoreMockRemoteRepo({
    required super.syncService,
    required super.path,
    required super.collectionProvider,
  }) : super(
          firestoreMapper: FakeFirestoreSyncEntityMapper(),
        );
}
