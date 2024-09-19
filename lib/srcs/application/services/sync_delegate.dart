import 'dart:async';

import 'package:sync_service/srcs/application/services/sync_service.dart';

import '../../domain/entities/sync_entity.dart';
import '../../helpers/loggable.dart';
import '../repos/sync_repo.dart';

/// Each collection that requires sync must implement this class
/// All synced data repository should implement [SyncedRepo] interface to ensure data are read/write correctly
/// following a standard approach to soft delete amd read only from cache
abstract class SyncDelegate<T extends SyncEntity, S> with Loggable {
  /// The name of the collection this sync delegate is responsible for

  /// The field name that stores updated timestamp. Defaults to "updatedAt".
  /// Override if this is different in the collection.
  final String updatedAtField;

  SyncedRepo<T> get syncedRepo;

  RemoteRepo<T> get remoteRepo;

  SyncDelegate({
    this.updatedAtField = 'updatedAt',
  });

  String get collectionPath => syncedRepo.collectionPath;

  String get debugDetails => '[UID:$userId][DEVICE:$deviceId][COLLECTION:$collectionPath]';

  late SyncService _syncService;
  SyncService get syncService => _syncService;
  String get deviceId => _syncService.deviceId;
  String get syncId => _syncService.syncId;
  String get userId => syncService.userId;

  StreamSubscription? _syncSubscription;

  Completer<bool> _completer = Completer();
  Future<bool> get isReady => _completer.future;

  /// Starts the sync operation when user logs in
  Future<void> startSync({
    required SyncService service,
  }) async {
    _syncService = service;
    _completer = Completer();
    if (userId.isEmpty) {
      throw Exception('$debugDetails startSync: session userId must not be empty');
    }

    devLog('$debugDetails startSync: initialising cache');

    final lastUpdatedAt = await getLastUpdatedAtFromCache();

    devLog('$debugDetails startSync: setting up sync listener');
    final stream = watchRemoteChanges(
      lastUpdatedAt: lastUpdatedAt,
      userId: userId,
    ).handleError((error, stacktrace) {
      devLog('$debugDetails startSync: exception occurred while watching changes',
          error: error, stackTrace: stacktrace);
    });

    _syncSubscription = stream.listen(_onRemoteChanged);
    devLog('$debugDetails startSync: sync session initialised');
  }

  /// Handles the changes from remote
  Future<void> _onRemoteChanged(SyncChangeSet<T> changeSet) async {
    if (changeSet.isEmpty) {
      devLog('$debugDetails _onRemoteChanged: no changes detected');
    }

    if (changeSet.put.isNotEmpty) {
      devLog('$debugDetails _onRemoteChanged: found ${changeSet.put.length} changed documents on remote');
      final putIds = changeSet.put.map((e) => e.id);
      devLog('$debugDetails _onRemoteChanged: caching ${putIds.length} documents');
      await putCache(changeSet.put);
    }

    if (changeSet.remove.isNotEmpty) {
      devLog('$debugDetails _onRemoteChanged: found ${changeSet.remove.length} removed documents on remote');
      final removedIds = changeSet.remove.map((e) => e.id).toSet();
      syncService.queueForDeletion(collectionPath, removedIds);
    }
    // signal that the first set of changes have been received
    if (!_completer.isCompleted) {
      _completer.complete(true);
    }
  }

  /// Stops the sync operation when user logs out
  Future<void> stopSync() async {
    await _syncSubscription?.cancel();
  }

  /// When the sync starts (when [startSync] is called), this method will be called to create a stream to retrieve
  /// data changes from remote. The stream is closed when [stopSync] is called.
  Stream<SyncChangeSet<T>> watchRemoteChanges({
    required S? lastUpdatedAt,
    required String userId,
  });

  /// This method must be implemented to return the last updatedAt record in the cache.
  /// This will be used as the seed to fetch new data from remote to cache
  Future<S?> getLastUpdatedAtFromCache();

  /// This method must be implemented to clear the cache when the sync state cannot be reconciled
  Future<void> clearCache();

  /// This method must be implemented to put changes into cache
  Future<void> putCache(List<T> values);
}

class SyncChangeSet<T extends SyncEntity> {
  final List<T> put;
  final List<T> remove;

  factory SyncChangeSet({
    List<T>? put,
    List<T>? remove,
  }) {
    return SyncChangeSet.required(
      put: put ?? [],
      remove: remove ?? [],
    );
  }

  SyncChangeSet.required({
    required this.put,
    required this.remove,
  });

  int get length => put.length + remove.length;

  bool get isEmpty => length == 0;
  bool get isNotEmpty => !isEmpty;
}
