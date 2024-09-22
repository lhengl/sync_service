import 'package:sync_service/src/data/soft_deletion_impl/soft_deletion_impl.dart';

import 'fake_data.dart';

class FakeFirestoreSoftSyncedRepo extends FirestoreSoftSyncRepo<FakeSyncEntity> {
  FakeFirestoreSoftSyncedRepo({
    required super.syncService,
    required super.collectionPath,
  }) : super(
          firestoreMapper: FakeFirestoreSyncEntityMapper(),
          sembastMapper: FakeSembastSyncEntityMapper(),
        );

  @override
  Future<DateTime> get currentTime async => DateTime.now().toUtc();
}

class FakeFirestoreSoftRemoteRepo extends FirestoreSoftRemoteRepo<FakeSyncEntity> {
  FakeFirestoreSoftRemoteRepo({
    required super.syncService,
    required super.collectionPath,
  }) : super(
          firestoreMapper: FakeFirestoreSyncEntityMapper(),
        );

  /// For equality checks, do not use utc because the conversion
  @override
  Future<DateTime> get currentTime async => DateTime.now().toUtc();
}
