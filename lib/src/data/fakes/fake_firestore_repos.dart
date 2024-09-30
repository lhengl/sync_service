import '../firestore_hard_deletion/firestore_hard_deletion.dart';
import 'fake_data.dart';

class FakeFirestoreSyncRepo extends FirestoreSyncRepo<FakeSyncEntity> {
  FakeFirestoreSyncRepo({
    super.path = FakeSyncEntity.collectionPath,
    required super.syncQuery,
    super.idField,
    super.updateField,
    super.createField,
    super.firestoreMapper = const FakeFirestoreSyncEntityMapper(),
    super.sembastMapper = const FakeSembastSyncEntityMapper(),
  });
}

class FakeFirestoreRemoteRepo extends FirestoreRemoteRepo<FakeSyncEntity> {
  FakeFirestoreRemoteRepo({
    super.path = FakeSyncEntity.collectionPath,
    super.idField,
    super.updateField,
    super.createField,
    required super.syncService,
    super.firestoreMapper = const FakeFirestoreSyncEntityMapper(),
  });
}
