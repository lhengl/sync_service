part of 'firestore_hard_deletion.dart';

class ServiceAView extends GetView<FirestoreHardDeletionController> {
  FirestoreHardSyncService get syncServiceA => controller.syncServiceA;
  FakeFirestoreHardSyncRepo get syncedRepoA => controller.syncedRepoA;

  const ServiceAView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ListView(
        children: [
          OutlinedButton(
            onPressed: () {
              syncedRepoA.create(controller.generateRandomData());
            },
            child: const Text('Create a data via synced repo'),
          ),
          OutlinedButton(
            onPressed: () async {
              await syncedRepoA.deleteAll();
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
              final registry = await syncServiceA.getOrSetRegistry();
              debugPrint('$registry');
            },
            child: const Text('syncServiceA.getOrSetRegistry'),
          ),
          OutlinedButton(
            onPressed: () async {
              await syncServiceA.cleanRegistry();
            },
            child: const Text('syncServiceA.cleanRegistry'),
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
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemBuilder: (__, index) => DataTile(data: controller.syncedDataA[index]),
            separatorBuilder: (__, index) => Divider(),
            itemCount: controller.syncedDataA.length,
          ),
        ],
      );
    });
  }
}
