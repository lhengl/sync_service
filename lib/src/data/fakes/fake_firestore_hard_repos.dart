import '../firestore_hard_deletion/firestore_hard_deletion.dart';
import 'fake_data.dart';

class FakeFirestoreHardSyncRepo extends FirestoreHardSyncRepo<FakeSyncEntity> {
  FakeFirestoreHardSyncRepo({
    super.path = FakeSyncEntity.collectionPath,
    required super.syncQuery,
    super.idField,
    super.updateField,
    super.createField,
    super.firestoreMapper = const FakeFirestoreSyncEntityMapper(),
    super.sembastMapper = const FakeSembastSyncEntityMapper(),
  });
}

class FakeFirestoreRemoteRepo extends FirestoreHardRemoteRepo<FakeSyncEntity> {
  FakeFirestoreRemoteRepo({
    super.path = FakeSyncEntity.collectionPath,
    super.idField,
    super.updateField,
    super.createField,
    required super.syncService,
    super.firestoreMapper = const FakeFirestoreSyncEntityMapper(),
  });
}
