part of 'firestore_soft_delete.dart';

class SoftServiceAView extends GetView<FirestoreSoftDeleteController> {
  FirestoreSoftSyncService get syncServiceA => Get.find(tag: Constants.serviceA);

  FakeFirestoreSoftSyncedRepo get syncedRepo => Get.find(tag: Constants.serviceA);

  const SoftServiceAView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ListView(
        children: [
          OutlinedButton(
            onPressed: () {
              syncedRepo.create(controller.generateRandomData());
            },
            child: const Text('Create a data via synced repo'),
          ),
          OutlinedButton(
            onPressed: () async {
              await syncedRepo.deleteAll();
            },
            child: const Text('Delete all data in cache'),
          ),
          // when I stopped the sync, the database will get closed,
          // which will cause any listeners to close as well
          controller.syncStateA.value == SyncState.stopped
              ? OutlinedButton(
                  onPressed: () {
                    syncServiceA.startSync(userId: Constants.userA);
                  },
                  child: const Text('Start sync'),
                )
              : OutlinedButton(
                  onPressed: () async {
                    await syncServiceA.stopSync();
                    // When the sync stop, the local database is closed, so all listeners will
                    // be retired. It might be a good idea to separate database connection and sync.
                  },
                  child: const Text('Stop sync'),
                ),
          OutlinedButton(
            onPressed: () async {
              await syncServiceA.disposeOldTrash();
            },
            child: const Text('Dispose old trash'),
          ),
          Card(
            color: Colors.blue,
            child: Column(
              children: [
                ListTile(
                  title: Text('Sync Details'),
                ),
                Divider(),
                DataTable(
                  columns: [
                    DataColumn(label: Text('Field')),
                    DataColumn(label: Text('Value')),
                  ],
                  rows: [
                    DataRow(cells: [
                      DataCell(Text('deviceId')),
                      DataCell(Text(syncServiceA.deviceId)),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('userId')),
                      DataCell(Text(syncServiceA.userId)),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('syncState')),
                      DataCell(Text(controller.syncStateA.value.name)),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          ExpansionTile(
            initiallyExpanded: true,
            title: Text('Cached records'),
            children: List.generate(controller.syncedDataA.length, (index) {
              return DataTile(data: controller.syncedDataA[index]);
            }),
          ),
          ExpansionTile(
            initiallyExpanded: true,
            title: Text('Cached trash'),
            children: List.generate(controller.trashDataA.length, (index) {
              return DataTile(data: controller.trashDataA[index]);
            }),
          ),
        ],
      );
    });
  }
}
