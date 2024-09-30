import '../firestore_soft_deletion/firestore_soft_deletion.dart';
import 'fake_data.dart';

class FakeFirestoreSoftSyncedRepo extends FirestoreSoftSyncRepo<FakeSyncEntity> {
  FakeFirestoreSoftSyncedRepo({
    super.path = FakeSyncEntity.collectionPath,
    required super.userQuery,
    super.idField,
    super.updateField,
    super.createField,
    super.firestoreMapper = const FakeFirestoreSyncEntityMapper(),
    super.sembastMapper = const FakeSembastSyncEntityMapper(),
  });
}

class FakeFirestoreSoftRemoteRepo extends FirestoreSoftRemoteRepo<FakeSyncEntity> {
  FakeFirestoreSoftRemoteRepo({
    required super.firestore,
    super.path = FakeSyncEntity.collectionPath,
    super.idField,
    super.updateField,
    super.createField,
    super.timestampProvider,
    super.disposalAge,
    super.trashRegistryPath,
    required super.userTrashQuery,
    super.firestoreMapper = const FakeFirestoreSyncEntityMapper(),
  });
}
