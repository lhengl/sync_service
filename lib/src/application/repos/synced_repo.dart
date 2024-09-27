import 'dart:async';

import 'package:sync_service/src/application/services/sync_service.dart';

import '../../domain/entities/sync_entity.dart';
import '../../helpers/loggable.dart';

/// Each collection that requires sync must implement this class
/// All synced data repository should implement [SyncRepo] interface to ensure data are read/write correctly
/// following a standard approach to register the delete and read only from cache
abstract class SyncRepo<T extends SyncEntity> with Loggable {
  final String path;
  String get trashPath => '${path}_trash';
  final String idField;
  final String updateField;
  final String createField;

  SyncRepo({
    required this.path,
    this.idField = 'id',
    this.updateField = 'updatedAt',
    this.createField = 'createdAt',
  });

  late SyncService _syncService;
  SyncService get syncService => _syncService;
  String get deviceId => _syncService.deviceId;
  String get userId => syncService.userId;

  String get debugDetails => '[UID:$userId][DEVICE:$deviceId][COLLECTION:$path]';

  /// This is called by SyncService to attach itself to the delegates
  void attachService(SyncService service) {
    _syncService = service;
  }

  Future<bool> get sessionIsReady;

  /// Starts the sync operation when user logs in
  Future<void> startSync();

  /// Stops the sync operation when user logs out
  Future<void> stopSync();

  /// This method must be implemented to clear the cache when the sync state cannot be reconciled
  Future<void> clearCache();

  // CRUD OPTIONS

  Future<T?> get(String id);
  Future<T> create(T value);
  Future<T> update(T value);
  Future<T> upsert(T value);
  Future<T> delete(T value);
  Future<T?> deleteById(String id);

  // BATCH OPTIONS

  Future<List<T>> batchGet(Set<String> ids);
  Future<List<T>> batchCreate(List<T> values);
  Future<List<T>> batchUpdate(List<T> values);
  Future<List<T>> batchUpsert(List<T> values);
  Future<List<T>> batchDelete(List<T> values);
  Future<List<T>> batchDeleteByIds(Set<String> ids);

  // DEBUG OPTIONS

  Future<List<T>> getAll();
  Stream<List<T>> watchAll();
  Future<List<T>> deleteAll();
}
