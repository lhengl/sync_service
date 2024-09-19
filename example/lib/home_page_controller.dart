import 'dart:math';

import 'package:get/get.dart';
import 'package:sync_service/sync_service.dart';

/// Storing all dependencies in this class to easily reference them.
class Constants {
  static const userA = 'userA';
  static const serviceA = 'serviceA';
  static const serviceB = 'serviceB';
  static const deviceB = 'deviceB';
}

class HomePageController extends GetxController with StateMixin {
  SyncService get syncServiceA => Get.find(tag: Constants.serviceA);
  SyncService get syncServiceB => Get.find(tag: Constants.serviceB);
  FirestoreMockSyncedRepo get syncedRepoA => Get.find(tag: Constants.serviceA);
  FirestoreMockSyncedRepo get syncedRepoB => Get.find(tag: Constants.serviceB);
  FirestoreMockRemoteRepo get remoteRepo => Get.find();

  /// Store all synced data here
  final RxList<MockSyncEntity> syncedDataA = <MockSyncEntity>[].obs;
  final RxList<MockSyncEntity> syncedDataB = <MockSyncEntity>[].obs;

  /// Store the sync state
  Rx<SyncState> syncStateA = SyncState.stopped.obs;
  Rx<SyncState> syncStateB = SyncState.stopped.obs;

  /// Store all remote data here
  final RxList<MockSyncEntity> remoteData = <MockSyncEntity>[].obs;

  /// Store the deletion registry to review what has changed
  Rx<DeletionRegistry> registry = DeletionRegistry(userId: '').obs;

  @override
  void onInit() async {
    super.onInit();
    syncedDataA.bindStream(syncedRepoA.watchAll());
    syncedDataB.bindStream(syncedRepoB.watchAll());
    remoteData.bindStream(remoteRepo.watchAll());
    syncStateA.bindStream(syncServiceA.watchSyncState());
    syncStateB.bindStream(syncServiceB.watchSyncState());
    registry.bindStream(syncServiceA.watchRegistry());
    change(true, status: RxStatus.success());
  }

  MockSyncEntity generateRandomData() {
    final random = Random().nextInt(10000);
    return MockSyncEntity(id: 'id$random', message: 'message$random');
  }
}
