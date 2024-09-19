import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_service/srcs/application/application.dart';
import 'package:sync_service/srcs/data/data.dart';

import 'mock_data.dart';

// https://firebase.flutter.dev/docs/testing/testing/
// https://pub.dev/packages/fake_cloud_firestore
void main() async {
  // Initialize Firebase before test
  const user1 = 'userA';
  // const user2 = 'user2';

  const syncA = 'syncA';
  const deviceA = 'deviceA';

  const syncB = 'syncB';
  const deviceB = 'deviceB';

  const syncC = 'syncC';
  const deviceC = 'deviceC';
  const mockEntities = FirestoreMockSyncedRepo.mockEntities;
  WidgetsFlutterBinding.ensureInitialized();
  final firestore = FakeFirebaseFirestore();
  final FirestoreSyncService syncServiceA = initSyncService(
    syncId: syncA,
    deviceId: deviceA,
    firestore: firestore,
  );
  final FirestoreSyncService syncServiceB = initSyncService(
    syncId: syncB,
    deviceId: deviceB,
    firestore: firestore,
  );
  final FirestoreSyncService syncServiceC = initSyncService(
    syncId: syncC,
    deviceId: deviceC,
    firestore: firestore,
  );
  await syncServiceA.startSync(userId: user1);
  await syncServiceB.startSync(userId: user1);
  await syncServiceC.startSync(userId: user1);

  final syncedRepoA = syncServiceA.delegates.first.syncedRepo as FirestoreSyncedRepo<MockSyncEntity>;
  final syncedRepoB = syncServiceB.delegates.first.syncedRepo as FirestoreSyncedRepo<MockSyncEntity>;
  final syncedRepoC = syncServiceC.delegates.first.syncedRepo as FirestoreSyncedRepo<MockSyncEntity>;
  tearDownAll(() async {
    await syncServiceA.deleteLocalDb();
    await syncServiceB.deleteLocalDb();
    await syncServiceC.deleteLocalDb();
  });

  test('Test create/update/delete should sync correctly', () async {
    // test create
    const singleObjectId = 'singleObjectId';
    final singleObject = await syncedRepoA.create(MockSyncEntity(
      id: singleObjectId,
      message: 'singleObject message',
    ));
    await Future.delayed(const Duration(milliseconds: 100)); // wait for sync
    final singleObjectA = await syncedRepoA.get(singleObjectId);
    final singleObjectB = await syncedRepoB.get(singleObjectId);
    final singleObjectC = await syncedRepoC.get(singleObjectId);
    expect(singleObject, singleObjectA);
    expect(singleObject, singleObjectB);
    expect(singleObject, singleObjectC);

    // test update
    singleObject.message = 'singleObject message changed';
    final updatedSingleObjectA = await syncedRepoA.update(singleObject);
    await Future.delayed(const Duration(milliseconds: 100)); // wait for sync
    final updatedObjectB = await syncedRepoB.get(singleObjectId);
    final updatedObjectC = await syncedRepoC.get(singleObjectId);
    expect(updatedSingleObjectA, updatedObjectB);
    expect(updatedSingleObjectA, updatedObjectC);

    // test delete
    await syncedRepoA.delete(singleObject);

    // wait for 100ms to wait for sync and check that all devices have signed the deletion
    await Future.delayed(const Duration(milliseconds: 100));
    final registryBeforeDebounce = await syncServiceA.getOrSetRegistry();
    expect(
      registryBeforeDebounce.isSigned(deviceId: deviceA, collectionId: mockEntities, docId: singleObjectId),
      true, // first device should have signed immediately
    );
    expect(
      registryBeforeDebounce.isSigned(deviceId: deviceB, collectionId: mockEntities, docId: singleObjectId),
      false, // second device should have debounced
    );
    expect(
      registryBeforeDebounce.isSigned(deviceId: deviceC, collectionId: mockEntities, docId: singleObjectId),
      false, // third device should have debounced
    );

    // wait for a further 5 seconds (longer than the debounce) to check that ids have been signed correctly
    await Future.delayed(const Duration(seconds: 5));
    final registryAfterDebounce = await syncServiceA.getOrSetRegistry();
    expect(
      registryAfterDebounce.isSignedByAllDevices(collectionId: mockEntities, docId: singleObjectId),
      true, // all devices should have signed
    );

    // all docs should be deleted from all devices
    final deletedSingleObjectA = await syncedRepoA.get(singleObjectId);
    final deletedSingleObjectB = await syncedRepoB.get(singleObjectId);
    final deletedSingleObjectC = await syncedRepoB.get(singleObjectId);
    expect(deletedSingleObjectA, deletedSingleObjectB);
    expect(deletedSingleObjectA, deletedSingleObjectC);

    // The registry should be clean (have no ids)
    await syncServiceA.cleanRegistry();
    final cleanedRegistry = await syncServiceA.getOrSetRegistry();
    expect(cleanedRegistry.isClean(), true);
  });

  test('Test batch create/update/delete should sync correctly', () async {
    // batch create
    final batchObjects = await syncedRepoA.batchCreate(List.generate(
      10,
      (index) => MockSyncEntity(id: 'batchObjectId $index', message: 'batchObjectMessage $index'),
    ));

    final batchIds = batchObjects.map((e) => e.id).toSet();

    // wait a bit to ensure all data is synced
    await Future.delayed(const Duration(milliseconds: 100));
    final batchObjectsA = (await syncedRepoA.batchGet(batchIds)).lastBy((e) => e.id);
    final batchObjectsB = (await syncedRepoB.batchGet(batchIds)).lastBy((e) => e.id);
    final batchObjectsC = (await syncedRepoC.batchGet(batchIds)).lastBy((e) => e.id);
    for (var object in batchObjects) {
      expect(object, batchObjectsA[object.id]);
      expect(object, batchObjectsB[object.id]);
      expect(object, batchObjectsC[object.id]);
    }

    // batch update / and test getAll (which should return all the updated records)
    for (var object in batchObjects) {
      object.message = '${object.message} updated';
    }
    final updatedObjects = await syncedRepoA.batchUpdate(batchObjects);

    // wait a bit to ensure all data is synced
    await Future.delayed(const Duration(milliseconds: 100));
    final updatedObjectsA = (await syncedRepoA.getAll()).lastBy((e) => e.id);
    final updatedObjectsB = (await syncedRepoB.getAll()).lastBy((e) => e.id);
    final updatedObjectsC = (await syncedRepoC.getAll()).lastBy((e) => e.id);
    for (var object in updatedObjects) {
      expect(object, updatedObjectsA[object.id]);
      expect(object, updatedObjectsB[object.id]);
      expect(object, updatedObjectsC[object.id]);
    }

    // since we have 10 items to delete, this is a good place to test all deletes:
    // delete, deleteById, batchDelete, batchDeleteByIds, deleteAll

    final singleDelete = updatedObjects.getRange(0, 1).first; // 1 count
    final singleDeleteById = updatedObjects.getRange(1, 2).first; // 1 count
    final batchDelete = updatedObjects.getRange(2, 5).toList(); // 3 count
    final batchDeleteByIds = updatedObjects.getRange(5, 8).map((e) => e.id); // 3 count

    final deleted = await syncedRepoA.delete(singleDelete);
    final deletedById = await syncedRepoA.deleteById(singleDeleteById.id);
    final batchDeleted = await syncedRepoA.batchDelete(batchDelete);
    final batchDeletedByIds = await syncedRepoA.batchDeleteByIds(batchDeleteByIds.toSet());

    final deletedObjectsA = [
      deleted,
      deletedById!,
      ...batchDeleted,
      ...batchDeletedByIds,
    ];
    final deletedIds = deletedObjectsA.map((e) => e.id).toSet();

    // wait for sync and check that all devices have signed the deletion
    await Future.delayed(const Duration(milliseconds: 100));
    final registryBeforeDebounce = await syncServiceA.getOrSetRegistry();

    expect(
      registryBeforeDebounce.areSigned(deviceId: deviceA, collectionId: mockEntities, docIds: deletedIds),
      true, // first device should have signed immediately
    );
    expect(
      registryBeforeDebounce.areSigned(deviceId: deviceB, collectionId: mockEntities, docIds: deletedIds),
      false, // second device should have debounced
    );
    expect(
      registryBeforeDebounce.areSigned(deviceId: deviceC, collectionId: mockEntities, docIds: deletedIds),
      false, // third device should have debounced
    );

    // wait for a further 5 seconds (longer than the debounce) to wait for debounce to fire
    await Future.delayed(const Duration(seconds: 5));
    final registryAfterDebounce = await syncServiceA.getOrSetRegistry();
    expect(
      registryAfterDebounce.areSignedByAllDevices(collectionId: mockEntities, docIds: deletedIds),
      true, // all devices should have signed all deleted ids
    );

    // there should be 2 remaining docs
    final remainingA = await syncedRepoA.getAll();
    final remainingB = await syncedRepoB.getAll();
    final remainingC = await syncedRepoC.getAll();
    expect(remainingA.length, 2);
    expect(remainingB.length, 2);
    expect(remainingC.length, 2);

    // now delete all docs
    await syncedRepoA.deleteAll();

    // wait for debounce to sync
    await Future.delayed(const Duration(seconds: 5));

    // all docs should be deleted from all devices
    final allA = await syncedRepoA.getAll();
    final allB = await syncedRepoB.getAll();
    final allC = await syncedRepoC.getAll();
    expect(allA.isEmpty, true);
    expect(allB.isEmpty, true);
    expect(allC.isEmpty, true);

    // The registry should be clean (have no ids)
    await syncServiceA.cleanRegistry();
    final cleanedRegistry = await syncServiceA.getOrSetRegistry();
    expect(cleanedRegistry.isClean(), true);
  });
}

FirestoreSyncService initSyncService({
  required String syncId,
  required String deviceId,
  required FirebaseFirestore firestore,
}) {
  return SyncService.init(
    MockFirestoreSyncService(
      syncId: syncId,
      deviceId: deviceId,
      firestore: firestore,
      // for testing purpose, make the debounce 3 seconds, to test the debounce make sure to delay more than 3 seconds
      signingDebounce: const Duration(seconds: 3),
      delegates: [
        FirestoreSyncDelegate<MockSyncEntity>(
          syncQuery: (collection, userId) {
            return collection;
          },
          syncedRepo: FirestoreMockSyncedRepo(syncId: syncId),
          remoteRepo: FirestoreMockRemoteRepo(),
        ),
      ],
    ),
  );
}
