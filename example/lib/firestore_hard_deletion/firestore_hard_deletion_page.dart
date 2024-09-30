part of 'firestore_hard_deletion.dart';

class FirestoreHardDeletionPage extends GetView<FirestoreHardDeletionController> {
  const FirestoreHardDeletionPage({super.key});
  @override
  Widget build(BuildContext context) {
    return controller.obx(
      (widget) {
        return DefaultTabController(
            initialIndex: 0,
            length: 4,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Firestore Deletion Registry Implementation'),
                bottom: TabBar(tabs: [
                  Tab(child: Text('Remote')),
                  Tab(child: Text(Constants.deviceA)),
                  Tab(child: Text(Constants.deviceB)),
                  Tab(child: Text('Registry')),
                ]),
              ),
              body: TabBarView(
                children: [
                  RemoteView(),
                  ServiceAView(),
                  ServiceBView(),
                  RegistryView(),
                ],
              ),
            ));
      },
    );
  }
}
