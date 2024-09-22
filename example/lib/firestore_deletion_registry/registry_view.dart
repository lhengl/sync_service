part of 'firestore_deletion_registry.dart';

class RegistryView extends GetView<FirestoreDeletionRegistryController> {
  const RegistryView({super.key});

  DeletionRegistry get registry => controller.registry.value;
  SyncService get syncServiceA => Get.find(tag: Constants.serviceA);

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
                      DataCell(Text('userId')),
                      DataCell(Text(registry.userId)),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('lastDeviceId')),
                      DataCell(Text('${registry.lastDeviceId}')),
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
                'deletions:'
                '${registry.deletions.entries.map((device) {
                  final deviceId = device.key;
                  final collections = device.value.entries.map((collection) {
                    final collectionId = collection.key;
                    final docIds = collection.value;
                    return '\n        collection: $collectionId'
                        '\n            ${docIds.join('\n            ')}';
                  }).join();
                  return '\n    device: $deviceId $collections';
                }).join()}',
              ),
            ),
          ),
          Card(
            color: Colors.blueGrey,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'deletionsByCollection:'
                '${registry.deletionsByCollection.entries.map((collection) {
                  final collectionId = collection.key;
                  final docs = collection.value.entries.map((doc) {
                    final docId = doc.key;
                    final deviceIds = doc.value;
                    return '\n        doc: $docId'
                        '\n            ${deviceIds.join('\n            ')}';
                  }).join();
                  return '\n    collection: $collectionId $docs';
                }).join()}',
              ),
            ),
          ),
          Card(
            color: Colors.blueGrey,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'lastSynced:'
                '${registry.deviceLastSynced.entries.map((device) {
                  final deviceId = device.key;
                  final lastSynced = device.value;
                  return '\n    $deviceId:\n        $lastSynced';
                }).join()}',
              ),
            ),
          ),
          Card(
            color: Colors.blueGrey,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('getAllDeviceIds:'
                  '\n    ${registry.getAllDeviceIds().join('\n    ')}'),
            ),
          ),
          SizedBox(height: 60),
        ],
      );
    });
  }
}
