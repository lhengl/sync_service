part of 'firestore_hard_deletion.dart';

class ServiceBView extends GetView<FirestoreHardDeletionController> {
  FirestoreHardSyncService get syncServiceB => controller.syncServiceB;
  FakeFirestoreHardSyncRepo get syncedRepoB => controller.syncedRepoB;

  const ServiceBView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ListView(
        children: [
          OutlinedButton(
            onPressed: () {
              syncedRepoB.create(controller.generateRandomData());
            },
            child: const Text('Create a data via synced repo'),
          ),
          OutlinedButton(
            onPressed: () async {
              await syncedRepoB.deleteAll();
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
              final registry = await syncServiceB.getOrSetRegistry();
              debugPrint('$registry');
            },
            child: const Text('syncServiceB.getRegistry'),
          ),
          OutlinedButton(
            onPressed: () async {
              final registry = await syncServiceB.cleanRegistry();
              debugPrint('$registry');
            },
            child: const Text('syncServiceB.cleanRegistry'),
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
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemBuilder: (__, index) => DataTile(data: controller.syncedDataB[index]),
            separatorBuilder: (__, index) => Divider(),
            itemCount: controller.syncedDataB.length,
          ),
        ],
      );
    });
  }
}
