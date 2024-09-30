import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';

import '../../helpers/loggable.dart';
import '../repos/sync_repo.dart';
import 'device_id_provider.dart';
import 'timestamp_provider.dart';

/// Sync service must be started each time a user logs into a session
/// It manages the lifecycle of each sync delegate during the user session
abstract class SyncService with Loggable {
  /// The device id that uniquely identifies the source of the sync.
  /// If none provided, DeviceInfoPlugin will used to obtain device info,
  /// which will throw if the platform is not supported.
  /// For testing, provide a fake deviceId instead.
  String? _deviceId;
  String get deviceId {
    try {
      return _deviceId!;
    } catch (e) {
      throw Exception('Oops, did you forget to call startSync?');
    }
  }

  /// The user id that unique identifies the user for this sync session
  /// Each time startSync is called a new user will be allocated to this field
  String _userId = '';
  String get userId => _userId;

  /// A list of sync delegates that manages the syncing operation per collection.
  /// The order of this list dictates the order of sync operation.
  final Map<String, SyncRepo> _delegateMap;
  List<SyncRepo> get delegates => _delegateMap.values.toList();

  T? get<T extends SyncRepo>(String path) {
    final delegate = _delegateMap[path];
    if (delegate is T) {
      return delegate;
    }
    return null;
  }

  void registerDelegate(SyncRepo delegate) {
    _delegateMap[delegate.path] = delegate;
  }

  void removeDelegate(String path) {
    _delegateMap.remove(path);
  }

  final DeviceIdProvider deviceIdProvider;

  final TimestampProvider timestampProvider;

  SyncService({
    required Iterable<SyncRepo> delegates,
    this.deviceIdProvider = const DeviceInfoDeviceIdProvider(),
    this.timestampProvider = const KronosTimestampProvider(),
  }) : _delegateMap = delegates.lastBy((e) => e.path) {
    // attach service to delegate
    for (var delegate in delegates) {
      delegate.attachService(this);
    }
  }

  String get debugDetails => '[UID:$userId][DEVICE:$deviceId]';

  Future<DateTime> get currentTime async => (await timestampProvider.currentTime).toUtc();

  Completer<bool> _syncSessionCompleter = Completer();
  Future<bool> get syncSessionIsReady => _syncSessionCompleter.future;

  final StreamController<SyncState> _syncStateController = StreamController();
  Stream<SyncState> watchSyncState() => _syncStateController.stream;

  /// This method should be implemented to hook to the starting process of syncing
  Future<void> beforeStarting() async {}

  Future<void> startSync({required String userId}) async {
    try {
      if (userId.isEmpty) {
        throw Exception('startSync: session userId must not be empty');
      }
      _syncStateController.add(SyncState.starting);
      _syncSessionCompleter = Completer();
      _deviceId ??= await deviceIdProvider.getDeviceId();
      _userId = userId;

      await beforeStarting();

      devLog('$debugDetails startSync: starting sync...');
      for (var delegate in delegates) {
        await delegate.startSync();
      }

      devLog('$debugDetails startSync: waiting for initial changes to be ready...');
      await Future.wait(delegates.map((e) => e.sessionIsReady));

      _syncStateController.add(SyncState.syncing);

      _syncSessionCompleter.complete(true);

      devLog('$debugDetails startSync: sync started successfully!');
    } catch (e, s) {
      devLog('$debugDetails Failed to start sync', error: e, stackTrace: s);
      rethrow;
    }
  }

  @mustCallSuper
  Future<void> stopSync() async {
    for (var delegate in delegates) {
      await delegate.stopSync();
    }
    _syncStateController.add(SyncState.stopped);
    devLog('$debugDetails stopSync: syncing stopped.');
  }

  /// Stops the sync, close local database and stream controllers
  @mustCallSuper
  Future<void> dispose() async {
    await stopSync();
    await _syncStateController.close();
    devLog('$debugDetails dispose: service disposed.');
  }
}

/// Not implemented yet - used to identify the sync state?
enum SyncState {
  starting,
  syncing, // including garbage collection and reconciliation
  stopped,
}
