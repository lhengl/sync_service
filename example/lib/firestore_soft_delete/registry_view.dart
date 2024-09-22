part of 'firestore_soft_delete.dart';

class DisposalRegistryView extends GetView<FirestoreSoftDeleteController> {
  const DisposalRegistryView({super.key});

  DisposalRegistry get registry => controller.registry.value;
  FirestoreSoftSyncService get syncServiceA => Get.find(tag: Constants.serviceA);

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
                      DataCell(Text(DisposalRegistry.userIdField)),
                      DataCell(Text(registry.userId)),
                    ]),
                    DataRow(cells: [
                      DataCell(Text(DisposalRegistry.lastDisposedByDeviceIdField)),
                      DataCell(Text('${registry.lastDisposedByDeviceId}')),
                    ]),
                    DataRow(cells: [
                      DataCell(Text(DisposalRegistry.disposalCutoffField)),
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
                """${DisposalRegistry.deviceLastDisposalField}:
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
