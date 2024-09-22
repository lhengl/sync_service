import 'package:dart_mappable/dart_mappable.dart';
import 'package:sync_service/src/data/data.dart';
import 'package:sync_service/src/domain/domain.dart';

part 'fake_data.mapper.dart';

@MappableClass()
class FakeSyncEntity extends SyncEntity with FakeSyncEntityMappable {
  static const collectionPath = 'fakes';
  @override
  DateTime createdAt;

  @override
  String id;

  @override
  DateTime updatedAt;

  String message;

  @MappableConstructor()
  FakeSyncEntity({
    required this.id,
    required this.message,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  @override
  FakeSyncEntity clone() {
    return copyWith();
  }

  factory FakeSyncEntity.fromJson(String json) => FakeSyncEntityMapper.fromJson(json);
  factory FakeSyncEntity.fromMap(Map<String, dynamic> map) => FakeSyncEntityMapper.fromMap(map);
}

class FakeFirestoreSyncEntityMapper extends JsonMapper<FakeSyncEntity> {
  @override
  FakeSyncEntity fromMap(Map<String, dynamic> map) {
    return FakeSyncEntity.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(FakeSyncEntity value) {
    return value.toMap();
  }
}

class FakeSembastSyncEntityMapper extends JsonMapper<FakeSyncEntity> {
  @override
  FakeSyncEntity fromMap(Map<String, dynamic> map) {
    return FakeSyncEntity.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(FakeSyncEntity value) {
    return value.toMap();
  }
}
