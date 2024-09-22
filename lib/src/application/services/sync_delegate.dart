import 'dart:async';

import 'package:sync_service/src/application/services/sync_service.dart';

import '../../domain/entities/sync_entity.dart';
import '../../helpers/loggable.dart';
import '../repos/sync_repo.dart';

/// Each collection that requires sync must implement this class
/// All synced data repository should implement [SyncedRepo] interface to ensure data are read/write correctly
/// following a standard approach to register the delete and read only from cache
abstract class SyncDelegate<T extends SyncEntity> with Loggable {
  SyncDelegate();

  late SyncService _syncService;
  SyncService get syncService => _syncService;
  String get deviceId => _syncService.deviceId;
  String get userId => syncService.userId;

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
}
