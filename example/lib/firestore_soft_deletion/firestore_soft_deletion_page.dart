part of 'firestore_soft_deletion.dart';

class FirestoreSoftDeletionPage extends GetView<FirestoreSoftDeletionController> {
  const FirestoreSoftDeletionPage({super.key});
  @override
  Widget build(BuildContext context) {
    return controller.obx(
      (widget) {
        return DefaultTabController(
            initialIndex: 0,
            length: 4,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Firestore Soft Delete Implementation'),
                bottom: TabBar(tabs: [
                  Tab(child: Text('Remote')),
                  Tab(child: Text(Constants.deviceA)),
                  Tab(child: Text(Constants.deviceB)),
                  Tab(child: Text('Registry')),
                ]),
              ),
              body: TabBarView(
                children: [
                  SoftRemoteView(),
                  SoftServiceAView(),
                  SoftServiceBView(),
                  DisposalRegistryView(),
                ],
              ),
            ));
      },
    );
  }
}
