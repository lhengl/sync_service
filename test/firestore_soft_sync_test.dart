import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_service/src/application/application.dart';
import 'package:sync_service/src/data/data.dart';

// https://firebase.flutter.dev/docs/testing/testing/
// https://pub.dev/packages/fake_cloud_firestore
void main() async {
  // Initialize Firebase before test
  const user1 = 'userA';
  const deviceA = 'deviceA';
  const deviceB = 'deviceB';
  const deviceC = 'deviceC';
  WidgetsFlutterBinding.ensureInitialized();
  final firestore = FakeFirebaseFirestore();
  final syncServiceA = await initSyncService(
    deviceId: deviceA,
    firestore: firestore,
  );
  final syncServiceB = await initSyncService(
    deviceId: deviceB,
    firestore: firestore,
  );
  final syncServiceC = await initSyncService(
    deviceId: deviceC,
    firestore: firestore,
  );
  await syncServiceA.startSync(userId: user1);
  await syncServiceB.startSync(userId: user1);
  await syncServiceC.startSync(userId: user1);

  final syncedRepoA = FakeFirestoreSoftSyncedRepo(
    syncService: syncServiceA,
    collectionPath: FakeSyncEntity.collectionPath,
  );
  final syncedRepoB = FakeFirestoreSoftSyncedRepo(
    syncService: syncServiceB,
    collectionPath: FakeSyncEntity.collectionPath,
  );
  final syncedRepoC = FakeFirestoreSoftSyncedRepo(
    syncService: syncServiceC,
    collectionPath: FakeSyncEntity.collectionPath,
  );
  tearDownAll(() async {
    await syncServiceA.databaseProvider.deleteLocalDatabase();
    await syncServiceB.databaseProvider.deleteLocalDatabase();
    await syncServiceC.databaseProvider.deleteLocalDatabase();
  });

  test('Test create/update/delete should sync correctly', () async {
    // test create
    const singleObjectId = 'singleObjectId';
    final singleObject = await syncedRepoA.create(FakeSyncEntity(
      id: singleObjectId,
      message: 'singleObject message',
    ));
    await Future.delayed(const Duration(milliseconds: 100)); // wait for sync
    final singleObjectA = await syncedRepoA.get(singleObjectId);
    final singleObjectB = await syncedRepoB.get(singleObjectId);
    final singleObjectC = await syncedRepoC.get(singleObjectId);
    expect(singleObjectA, singleObject);
    expect(singleObjectB, singleObject);
    expect(singleObjectC, singleObject);

    // test update
    singleObject.message = 'singleObject message changed';
    final updatedSingleObjectA = await syncedRepoA.update(singleObject);
    await Future.delayed(const Duration(milliseconds: 100)); // wait for sync
    final updatedObjectB = await syncedRepoB.get(singleObjectId);
    final updatedObjectC = await syncedRepoC.get(singleObjectId);
    expect(updatedObjectB, updatedSingleObjectA);
    expect(updatedObjectC, updatedSingleObjectA);

    // test delete
    await syncedRepoA.delete(singleObject);

    // wait for 100ms to wait for sync and check that all devices have signed the deletion
    await Future.delayed(const Duration(milliseconds: 100));

    // all docs should be deleted from all devices
    final deletedSingleObjectA = await syncedRepoA.get(singleObjectId);
    final deletedSingleObjectB = await syncedRepoB.get(singleObjectId);
    final deletedSingleObjectC = await syncedRepoB.get(singleObjectId);
    expect(deletedSingleObjectA, isNull);
    expect(deletedSingleObjectB, isNull);
    expect(deletedSingleObjectC, isNull);
  });

  test('Test batch create/update/delete should sync correctly', () async {
    // batch create
    final batchObjects = await syncedRepoA.batchCreate(List.generate(
      10,
      (index) => FakeSyncEntity(id: 'batchObjectId$index', message: 'batchObjectMessage$index'),
    ));

    final batchIds = batchObjects.map((e) => e.id).toSet();

    // wait a bit to ensure all data is synced
    await Future.delayed(const Duration(milliseconds: 100));
    final batchObjectsA = (await syncedRepoA.batchGet(batchIds)).lastBy((e) => e.id);
    final batchObjectsB = (await syncedRepoB.batchGet(batchIds)).lastBy((e) => e.id);
    final batchObjectsC = (await syncedRepoC.batchGet(batchIds)).lastBy((e) => e.id);
    for (var object in batchObjects) {
      expect(batchObjectsA[object.id], object);
      expect(batchObjectsB[object.id], object);
      expect(batchObjectsC[object.id], object);
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
      expect(updatedObjectsA[object.id], object);
      expect(updatedObjectsB[object.id], object);
      expect(updatedObjectsC[object.id], object);
    }

    // since we have 10 items to delete, this is a good place to test all deletes:
    // delete, deleteById, batchDelete, batchDeleteByIds, deleteAll

    final singleDelete = updatedObjects.getRange(0, 1).first; // 1 count
    final singleDeleteById = updatedObjects.getRange(1, 2).first; // 1 count
    final batchDelete = updatedObjects.getRange(2, 5).toList(); // 3 count
    final batchDeleteByIds = updatedObjects.getRange(5, 8).map((e) => e.id); // 3 count

    await syncedRepoA.delete(singleDelete);
    await syncedRepoA.deleteById(singleDeleteById.id);
    await syncedRepoA.batchDelete(batchDelete);
    await syncedRepoA.batchDeleteByIds(batchDeleteByIds.toSet());

    // wait for sync and check that all devices have signed the deletion
    await Future.delayed(const Duration(milliseconds: 100));

    // there should be 2 remaining docs
    final remainingA = await syncedRepoA.getAll();
    final remainingB = await syncedRepoB.getAll();
    final remainingC = await syncedRepoC.getAll();
    expect(remainingA.length, 2);
    expect(remainingB.length, 2);
    expect(remainingC.length, 2);

    // now delete all docs
    await syncedRepoA.deleteAll();

    // wait for sync
    await Future.delayed(const Duration(milliseconds: 100));

    // all docs should be deleted from all devices
    final allA = await syncedRepoA.getAll();
    final allB = await syncedRepoB.getAll();
    final allC = await syncedRepoC.getAll();
    expect(allA.isEmpty, true);
    expect(allB.isEmpty, true);
    expect(allC.isEmpty, true);
  });
}

Future<FirestoreSoftSyncService> initSyncService({
  required String deviceId,
  required FirebaseFirestore firestore,
}) async {
  return FirestoreSoftSyncService(
    databaseProvider: FakeDatabaseProvider(),
    timestampProvider: const FakeTimeStampProvider(),
    deviceIdProvider: FakeDeviceIdProvider(deviceId),
    firestore: firestore,
    // for testing purpose, make the debounce 3 seconds, to test the debounce make sure to delay more than 3 seconds
    delegates: [
      FirestoreSoftSyncDelegate<FakeSyncEntity>(
        collectionPath: FakeSyncEntity.collectionPath,
        syncQuery: (collection, userId) => collection,
        firestoreMapper: FakeFirestoreSyncEntityMapper(),
        sembastMapper: FakeSembastSyncEntityMapper(),
      ),
    ],
  );
}
