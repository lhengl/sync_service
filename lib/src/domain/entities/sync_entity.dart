abstract class SyncEntity {
  abstract String id;
  abstract DateTime createdAt;
  abstract DateTime updatedAt;
  dynamic clone();
  String? get idOrNull => id.isEmpty ? null : id;
}
