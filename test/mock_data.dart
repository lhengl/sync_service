import 'dart:async';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:sembast/sembast.dart' as sb;
import 'package:sembast/sembast_memory.dart';
import 'package:sync_service/srcs/data/data.dart';
import 'package:sync_service/srcs/domain/domain.dart';
import 'package:sync_service/srcs/helpers/helpers.dart';

part 'mock_data.mapper.dart';

@MappableClass()
class MockSyncEntity extends SyncEntity with MockSyncEntityMappable {
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
  static const mockEntities = 'mockEntities';

  @override
  late final FirestoreCollection<MockSyncEntity> fsCollection = FirestoreCollection(
    path: mockEntities,
    mapper: FirestoreMockSyncEntityMapper(),
    firestore: firestore,
  );

  @override
  late final SembastCollection<MockSyncEntity> sbCollection = SembastCollection(
    path: mockEntities,
    mapper: SembastMockSyncEntityMapper(),
    getDb: () => syncService.sembastDb,
  );

  FirestoreMockSyncedRepo({required super.syncId});

  @override
  Future<DateTime> get currentTime async => DateTime.now();
}

class FirestoreMockRemoteRepo extends FirestoreRemoteRepo<MockSyncEntity> {
  @override
  late final FirestoreCollection<MockSyncEntity> fsCollection = FirestoreCollection(
    path: 'mockEntities',
    mapper: FirestoreMockSyncEntityMapper(),
    firestore: FirestoreSyncService.instance.firestore,
  );

  /// For equality checks, do not use utc because the conversion
  @override
  Future<DateTime> get currentTime async => DateTime.now();
}

class MockFirestoreSyncService extends FirestoreSyncService {
  late sb.Database _mockDb;

  @override
  sb.Database get sembastDb => _mockDb;

  @override
  Future<DateTime> get currentTime async => DateTime.now();

  MockFirestoreSyncService({
    required super.syncId,
    required super.firestore,
    required super.deviceId,
    required super.delegates,
    super.offlineDeviceTtl,
    super.retriesOnFailure,
    super.retryInterval,
    super.signingDebounce,
    super.deletionRegistryPath,
  });

  Completer<bool> _localDbCompleter = Completer();
  @override
  Future<bool> get localDbIsReady => _localDbCompleter.future;

  @override
  Future<sb.Database?> openLocalDb(String userId) async {
    if (userId.isEmpty) {
      return throw Exception('To open a user database, userId must not be empty');
    }
    _localDbCompleter = Completer();

    _mockDb = await newDatabaseFactoryMemory().openDatabase('$userId.db');
    _localDbCompleter.complete(true);
    return _mockDb;
  }
}
