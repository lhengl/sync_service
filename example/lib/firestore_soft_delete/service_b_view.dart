part of 'firestore_soft_delete.dart';

class SoftServiceBView extends GetView<FirestoreSoftDeleteController> {
  FirestoreSoftSyncService get syncServiceB => Get.find(tag: Constants.serviceB);

  FakeFirestoreSoftSyncedRepo get syncedRepo => Get.find(tag: Constants.serviceB);

  const SoftServiceBView({super.key});

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
          controller.syncStateB.value == SyncState.stopped
              ? OutlinedButton(
                  onPressed: () {
                    syncServiceB.startSync(userId: Constants.userA);
                  },
                  child: const Text('Start sync'),
                )
              : OutlinedButton(
                  onPressed: () async {
                    await syncServiceB.stopSync();
                    // When the sync stop, the local database is closed, so all listeners will
                    // be retired. It might be a good idea to separate database connection and sync.
                  },
                  child: const Text('Stop sync'),
                ),
          OutlinedButton(
            onPressed: () async {
              await syncServiceB.disposeOldTrash();
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
                      DataCell(Text(syncServiceB.deviceId)),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('userId')),
                      DataCell(Text(syncServiceB.userId)),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('syncState')),
                      DataCell(Text(controller.syncStateB.value.name)),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          ExpansionTile(
            initiallyExpanded: true,
            title: Text('Cached records'),
            children: List.generate(controller.syncedDataB.length, (index) {
              return DataTile(data: controller.syncedDataB[index]);
            }),
          ),
          ExpansionTile(
            initiallyExpanded: true,
            title: Text('Cached trash'),
            children: List.generate(controller.trashDataB.length, (index) {
              return DataTile(data: controller.trashDataB[index]);
            }),
          ),
        ],
      );
    });
  }
}
