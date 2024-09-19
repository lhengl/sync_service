import 'dart:async';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:sembast/sembast.dart' as sb;
import 'package:sembast/sembast_memory.dart';
import 'package:sync_service/src/data/data.dart';
import 'package:sync_service/src/domain/domain.dart';

part 'mock_data.mapper.dart';

@MappableClass()
class MockSyncEntity extends SyncEntity with MockSyncEntityMappable {
  static const mockEntitiesCollectionPath = 'mockEntities';
  @override
  DateTime createdAt;

  @override
  String id;

  @override
  DateTime updatedAt;

  String message;

  @MappableConstructor()
  MockSyncEntity({
    required this.id,
    required this.message,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  @override
  MockSyncEntity clone() {
    return copyWith();
  }

  factory MockSyncEntity.fromJson(String json) => MockSyncEntityMapper.fromJson(json);
  factory MockSyncEntity.fromMap(Map<String, dynamic> map) => MockSyncEntityMapper.fromMap(map);
}

class FirestoreMockSyncEntityMapper extends JsonMapper<MockSyncEntity> {
  @override
  MockSyncEntity fromMap(Map<String, dynamic> map) {
    return MockSyncEntity.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(MockSyncEntity value) {
    return value.toMap();
  }
}

class SembastMockSyncEntityMapper extends JsonMapper<MockSyncEntity> {
  @override
  MockSyncEntity fromMap(Map<String, dynamic> map) {
    return MockSyncEntity.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(MockSyncEntity value) {
    return value.toMap();
  }
}

class FirestoreMockSyncedRepo extends FirestoreSyncedRepo<MockSyncEntity> {
  FirestoreMockSyncedRepo({
    required super.syncService,
    required super.collectionPath,
    required super.firestoreMapper,
    required super.sembastMapper,
  });

  @override
  Future<DateTime> get currentTime async => DateTime.now().toUtc();
}

class FirestoreMockRemoteRepo extends FirestoreRemoteRepo<MockSyncEntity> {
  FirestoreMockRemoteRepo({
    required super.syncService,
    required super.collectionPath,
    required super.firestoreMapper,
  });

  /// For equality checks, do not use utc because the conversion
  @override
  Future<DateTime> get currentTime async => DateTime.now().toUtc();
}

class MockFirestoreSyncService extends FirestoreSyncService {
  late sb.Database _mockDb;

  @override
  sb.Database get sembastDb => _mockDb;

  @override
  Future<DateTime> get currentTime async => DateTime.now().toUtc();

  MockFirestoreSyncService({
    required super.firestore,
    required super.delegates,
    super.offlineDeviceTtl,
    super.retriesOnFailure,
    super.retryInterval,
    super.signingDebounce,
    super.deletionRegistryPath,
  });

  @override
  Future<sb.Database> getOrOpenLocalDatabase() async {
    _mockDb = await newDatabaseFactoryMemory().openDatabase('$userId.db');
    return _mockDb;
  }
}
