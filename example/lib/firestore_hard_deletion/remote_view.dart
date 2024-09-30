part of 'firestore_hard_deletion.dart';

class RemoteView extends GetView<FirestoreHardDeletionController> {
  FakeFirestoreRemoteRepo get remoteRepo => controller.remoteRepo;

  const RemoteView({super.key});

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
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemBuilder: (__, index) => DataTile(data: controller.remoteData[index]),
            separatorBuilder: (__, index) => Divider(),
            itemCount: controller.remoteData.length,
          ),
        ],
      );
    });
  }
}
