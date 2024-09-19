import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sync_service/sync_service.dart';

import 'home_page.dart';
import 'home_page_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firestore = FakeFirebaseFirestore();
  // the default sync service
  final serviceA = Get.put(
      await FirestoreSyncService(
        firestore: firestore,
        // make the signing debounce shorter for testing purpose
        signingDebounce: Duration(seconds: 5),
        delegates: [
          FirestoreSyncDelegate<MockSyncEntity>(
            collectionPath: MockSyncEntity.mockEntitiesCollectionPath,
            syncQuery: (collection, userId) => collection,
            firestoreMapper: FirestoreMockSyncEntityMapper(),
            sembastMapper: SembastMockSyncEntityMapper(),
          ),
        ],
      ).init(),
      tag: Constants.serviceA);

  // create another instance of sync service to emulate multiple devices
  final serviceB = Get.put(
      await FirestoreSyncService(
        firestore: firestore,
        // make the signing debounce shorter for testing purpose
        signingDebounce: Duration(seconds: 5),
        delegates: [
          FirestoreSyncDelegate<MockSyncEntity>(
            collectionPath: MockSyncEntity.mockEntitiesCollectionPath,
            syncQuery: (collection, userId) => collection,
            firestoreMapper: FirestoreMockSyncEntityMapper(),
            sembastMapper: SembastMockSyncEntityMapper(),
          ),
        ],
      ).init(deviceId: Constants.deviceB),
      tag: Constants.serviceB);

  Get.put(
      FirestoreMockSyncedRepo(
        collectionPath: MockSyncEntity.mockEntitiesCollectionPath,
        syncService: serviceA,
        firestoreMapper: FirestoreMockSyncEntityMapper(),
        sembastMapper: SembastMockSyncEntityMapper(),
      ),
      tag: Constants.serviceA);
  Get.put(
      FirestoreMockSyncedRepo(
        collectionPath: MockSyncEntity.mockEntitiesCollectionPath,
        syncService: serviceB,
        firestoreMapper: FirestoreMockSyncEntityMapper(),
        sembastMapper: SembastMockSyncEntityMapper(),
      ),
      tag: Constants.serviceB);
  Get.put(
    FirestoreMockRemoteRepo(
      collectionPath: MockSyncEntity.mockEntitiesCollectionPath,
      syncService: serviceA,
      firestoreMapper: FirestoreMockSyncEntityMapper(),
    ),
  );

  // start the sync processes
  await serviceA.startSync(userId: Constants.userA);
  await serviceB.startSync(userId: Constants.userA);

  runApp(GetMaterialApp(
    title: 'Sync Service Example',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
    ),
    initialBinding: BindingsBuilder(() {
      Get.put(HomePageController());
    }),
    home: const HomePage(),
  ));
}
