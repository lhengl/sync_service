part of 'firestore_soft_deletion.dart';

class DisposalRegistryView extends GetView<FirestoreSoftDeletionController> {
  const DisposalRegistryView({super.key});

  TrashRegistry get registry => controller.registry.value;
  FirestoreSoftSyncService get syncServiceA => controller.syncServiceA;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ListView(
        children: [
          Card(
            color: Colors.blue,
            child: Column(
              children: [
                DataTable(
                  columns: [
                    DataColumn(label: Text('Field')),
                    DataColumn(label: Text('Value')),
                  ],
                  rows: [
                    DataRow(cells: [
                      DataCell(Text(TrashRegistry.userIdField)),
                      DataCell(Text(registry.userId)),
                    ]),
                    DataRow(cells: [
                      DataCell(Text(TrashRegistry.lastDisposedByDeviceIdField)),
                      DataCell(Text('${registry.lastDisposedByDeviceId}')),
                    ]),
                    DataRow(cells: [
                      DataCell(Text(TrashRegistry.disposalCutoffField)),
                      DataCell(Text('${registry.disposalCutoff}')),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          Card(
            color: Colors.blueGrey,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                """${TrashRegistry.deviceLastDisposalField}:
                ${registry.deviceLastDisposal.entries.map((device) {
                  final deviceId = device.key;
                  final lastSynced = device.value;
                  return '\n    $deviceId:\n        $lastSynced';
                }).join()}""",
              ),
            ),
          ),
          SizedBox(height: 60),
        ],
      );
    });
  }
}
