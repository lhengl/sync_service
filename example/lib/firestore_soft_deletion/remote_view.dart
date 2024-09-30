part of 'firestore_soft_deletion.dart';

class SoftRemoteView extends GetView<FirestoreSoftDeletionController> {
  FakeFirestoreSoftRemoteRepo get remoteRepo => controller.remoteRepo;

  const SoftRemoteView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ListView(
        children: [
          OutlinedButton(
            onPressed: () {
              remoteRepo.create(controller.generateRandomData());
            },
            child: const Text('Create a data in remote repo'),
          ),
          OutlinedButton(
            onPressed: () async {
              await remoteRepo.deleteAll();
            },
            child: const Text('Delete all remote data'),
          ),
          OutlinedButton(
            onPressed: () async {
              await remoteRepo.disposeOldUserTrash(userId: Constants.userA);
              debugPrint('trash cleared');
            },
            child: const Text('Dispose old trash (signed)'),
          ),
          OutlinedButton(
            onPressed: () async {
              await remoteRepo.clearTrash();
              debugPrint('trash cleared');
            },
            child: const Text('Clear trash (unsigned)'),
          ),
          ExpansionTile(
            initiallyExpanded: true,
            title: Text('Remote records'),
            children: List.generate(controller.remoteData.length, (index) {
              return DataTile(data: controller.remoteData[index]);
            }),
          ),
          ExpansionTile(
            initiallyExpanded: true,
            title: Text('Remote trash'),
            children: List.generate(controller.remoteTrash.length, (index) {
              return DataTile(data: controller.remoteTrash[index]);
            }),
          ),
        ],
      );
    });
  }
}
