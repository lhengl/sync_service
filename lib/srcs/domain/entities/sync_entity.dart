abstract class SyncEntity {
  abstract String id;
  abstract DateTime createdAt;
  abstract DateTime updatedAt;
  String? get idOrNull => id.isEmpty ? null : id;
  dynamic clone();
}
