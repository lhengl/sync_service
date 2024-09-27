import '../deletion_registry_impl/deletion_registry_impl.dart';
import 'fake_data.dart';

class FakeFirestoreSyncRepo extends FirestoreSyncRepo<FakeSyncEntity> {
  FakeFirestoreSyncRepo({
    required super.path,
    required super.syncQuery,
    super.idField,
    super.updateField,
    super.createField,
  }) : super(
          firestoreMapper: FakeFirestoreSyncEntityMapper(),
          sembastMapper: FakeSembastSyncEntityMapper(),
        );

  @override
  Future<DateTime> get currentTime async => DateTime.now().toUtc();
}

class FakeFirestoreRemoteRepo extends FirestoreRemoteRepo<FakeSyncEntity> {
  FakeFirestoreRemoteRepo({
    required super.path,
    super.idField,
    super.updateField,
    super.createField,
    required super.syncService,
  }) : super(
          firestoreMapper: FakeFirestoreSyncEntityMapper(),
        );
}
