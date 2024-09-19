import 'dart:async';

import '../../domain/entities/sync_entity.dart';
import '../services/sync_service.dart';

/// A convenient mixin for a syncable user data repository.
/// This mixin assumes that local and remote are synced via [SyncService] and [SyncDelegate]
/// On read, only local repository will be read
/// On write, both local and remote will be written to
/// On delete, both local and remote will be soft deleted only - it assumes that [SyncService] and [SyncDelegate]
/// will manage the permanent deletion.
abstract interface class SyncedRepo<T extends SyncEntity> {
  String get syncId;
  SyncService get syncService => SyncService.instanceFor(syncId);

  String get collectionPath;

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

/// Remote interface should not allow write operations
/// All write operations must be done through the cache which will sync to remote via [SyncService]
abstract interface class RemoteRepo<T extends SyncEntity> {
  Future<T?> get(String id);
  Future<List<T>> batchGet(Set<String> ids);
}
