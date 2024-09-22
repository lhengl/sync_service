import 'package:flutter/material.dart';
import 'package:sync_service/sync_service.dart';

class DataTile extends StatelessWidget {
  const DataTile({
    super.key,
    required this.data,
  });

  final FakeSyncEntity data;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text("id:${data.id}\n"
          "message:${data.message}\n"
          "createdAt:${data.createdAt}\n"
          "updatedAt:${data.updatedAt}"),
    );
  }
}
