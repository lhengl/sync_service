import '../deletion_registry_impl/deletion_registry_impl.dart';
import 'fake_data.dart';

class FakeFirestoreSyncedRepo extends FirestoreSyncedRepo<FakeSyncEntity> {
  FakeFirestoreSyncedRepo({
    required super.syncService,
    required super.collectionPath,
    required super.firestoreMapper,
    required super.sembastMapper,
  });

  @override
  Future<DateTime> get currentTime async => DateTime.now().toUtc();
}

class FirestoreMockRemoteRepo extends FirestoreRemoteRepo<FakeSyncEntity> {
  FirestoreMockRemoteRepo({
    required super.syncService,
    required super.collectionPath,
    required super.firestoreMapper,
  });

  /// For equality checks, do not use utc because the conversion
  @override
  Future<DateTime> get currentTime async => DateTime.now().toUtc();
}
