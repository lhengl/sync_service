part of 'firestore_deletion_registry.dart';

class FirestoreDeletionRegistryPage extends GetView<FirestoreDeletionRegistryController> {
  const FirestoreDeletionRegistryPage({super.key});
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
                  Tab(child: Text(Constants.serviceA)),
                  Tab(child: Text(Constants.serviceB)),
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
