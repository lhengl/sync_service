import 'package:sync_service/src/data/soft_deletion_impl/soft_deletion_impl.dart';

import 'fake_data.dart';

class FakeFirestoreSoftSyncedRepo extends FirestoreSoftSyncRepo<FakeSyncEntity> {
  FakeFirestoreSoftSyncedRepo({
    required super.path,
    required super.syncQuery,
    super.idField,
    super.updateField,
    super.createField,
  }) : super(
          firestoreMapper: FakeFirestoreSyncEntityMapper(),
          sembastMapper: FakeSembastSyncEntityMapper(),
        );
}

class FakeFirestoreSoftRemoteRepo extends FirestoreSoftRemoteRepo<FakeSyncEntity> {
  FakeFirestoreSoftRemoteRepo({
    required super.firestore,
    required super.path,
    super.idField,
    super.updateField,
    super.createField,
    super.timestampProvider,
  }) : super(
          firestoreMapper: FakeFirestoreSyncEntityMapper(),
        );
}
