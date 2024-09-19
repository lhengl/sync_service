import 'dart:async';

import 'package:duration/duration.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter_kronos/flutter_kronos.dart';
import 'package:sembast/sembast.dart' as semb;
import 'package:sync_service/srcs/application/services/sync_delegate.dart';

import '../../domain/entities/deletion_registry.dart';
import '../../helpers/error_handler.dart';
import '../../helpers/loggable.dart';

/// Sync service must be started each time a user logs into a session
/// It manages the lifecycle of each sync delegate during the user session
abstract class SyncService with Loggable {
  /// Instances are stored in a map
  static final Map<String, SyncService> _instances = {};

  static SyncService instanceFor([String name = 'default']) {
    final instance = _instances[name];
    if (instance == null) {
      throw Exception('Instance not found or not initialised, ensure to run '
          'SyncService.init and passing an implementation before accessing it.');
    }
    return instance;
  }

  /// Returns the default instance named 'default'
  static SyncService get instance {
    return instanceFor();
  }

  /// Initialise service singleton instance
  static T init<T extends SyncService>(T serviceImpl) {
    return _instances[serviceImpl.syncId] = serviceImpl;
  }

  /// This is the time to live duration that a device can be offline before its cache may be invalidated.
  ///
  /// The reason why we need this is because if a device goes offline indefinitely,
  /// then it will never sign any deletion. Or if it goes offline for too long then the deletion
  /// registry may become to large which will slow the cleaning process and increase network egress.
  ///
  /// The default value is 14 days.
  ///
  /// This means that if a device goes offline for 14 days, then the next time it boots up, the registry will check
  /// if the device was the last synced. If it is, then the device is considered to be in sync because no other devices
  /// have tampered. However, if another device has synced, then the cache will be invalidated.
  final Duration offlineDeviceTtl;

  /// The number of retries when a sync operation fails. Defaults to 3.
  final int retriesOnFailure;

  /// The duration between retries when sync operation fails. Defaults to 3 seconds.
  final Duration retryInterval;

  /// The device id that uniquely identifies the source of the sync
  final String deviceId;

  /// A list of sync delegates that manages the syncing operation per collection.
  /// The order of this list dictates the order of sync operation.
  List<SyncDelegate> get delegates;

  /// A unique id that identifies the instance of this service. This is used for testing purposes
  /// or in unique case where two sync instances are required in a single app.
  final String syncId;

  /// The minimum interval for signing deletion. That is, signing will occur in real time,
  /// but is throttled to save writes. Defaults to 1 minute. So if a user deletes 1 document, then all synced services
  /// will delete that 1 document immediately. However, subsequent deletes won't be synced until after 1 minute.
  final Duration signingDebounce;

  SyncService({
    required this.syncId,
    required this.deviceId,
    Duration? offlineDeviceTtl,
    int? retriesOnFailure = 3,
    Duration? retryInterval,
    Duration? signingDebounce,
  })  : offlineDeviceTtl = const Duration(days: 14),
        retriesOnFailure = retriesOnFailure ?? 3,
        retryInterval = retryInterval ?? const Duration(seconds: 3),
        signingDebounce = signingDebounce ?? const Duration(minutes: 1);

  String get debugDetails => '[UID:$userId][DEVICE:$deviceId]';

  String _userId = '';
  String get userId => _userId;

  Completer<bool> _completer = Completer();
  Future<bool> get isReady => _completer.future;

  Future<void> startSync({
    required String userId,
  }) async {
    try {
      _completer = Completer();
      _userId = userId;
      if (userId.isEmpty) {
        throw Exception('startSync: session userId must not be empty');
      }

      devLog('$debugDetails startSync: opening local database...');
      await openLocalDb(userId);

      devLog('$debugDetails startSync: cleaning registry...');
      await _cleanRegistry();

      devLog('$debugDetails startSync: starting sync...');
      for (var delegate in delegates) {
        await delegate.startSync(service: this);
      }

      devLog('$debugDetails startSync: waiting for initial changes to be ready...');
      await Future.wait(delegates.map((e) => e.isReady));
      _completer.complete(true);
      devLog('$debugDetails startSync: sync started successfully!');
    } catch (e, s) {
      devLog('$debugDetails Failed to start sync', error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<DateTime> get currentTime async => await FlutterKronos.getNtpDateTime ?? DateTime.now();

  Future<void> stopSync() async {
    for (var delegate in delegates) {
      await delegate.stopSync();
    }
    await closeLocalDb();
    devLog('$debugDetails stopSync: syncing stopped.');
  }

  Future<void> _cleanRegistry() async {
    devLog('$debugDetails _cleanRegistry: signing registry for the first time...');

    final shouldInvalidateCache = await RetryHelper(
      retries: retriesOnFailure,
      retryInterval: retryInterval,
      future: () async {
        devLog('$debugDetails _cleanRegistry: cleaning registry...');
        final shouldInvalidateCache = await cleanRegistry();
        return shouldInvalidateCache;
      },
    ).retry();

    if (shouldInvalidateCache) {
      devLog('$debugDetails _cleanRegistry: Cache is invalidated and must be cleared.');
      await RetryHelper(
        retries: retriesOnFailure,
        retryInterval: retryInterval,
        future: () async {
          for (var delegate in delegates) {
            devLog('$debugDetails _cleanRegistry: Clearing cache for "${delegate.syncedRepo.collectionPath}"...');
            await delegate.clearCache();
            devLog('$debugDetails _cleanRegistry: Cached cleared for "${delegate.syncedRepo.collectionPath}".');
          }
        },
      ).retry();
    }
  }

  final Map<String, Set<String>> _idsByCollection = {};

  /// This is called by delegates to queue a set of ids for deletion in a collection
  /// This will invoke [signDeletions] not more than once every [signingDebounce] interval
  void queueForDeletion(String collection, Set<String> ids) {
    devLog(
        '$debugDetails queueForDeletion: queueing ${ids.length} documents for deletion in "$collection" cache: $ids');
    (_idsByCollection[collection] ??= {}).addAll(ids);
    EasyDebounce.debounce(debugDetails, signingDebounce, () async {
      devLog('$debugDetails queueForDeletion debounced, '
          'next operation can be started in ${signingDebounce.pretty()}');
      await signDeletions(_idsByCollection);
      // clear to queue after signing
      _idsByCollection.clear();
    });
  }

  /// Sign the deletion of of all ids mapped by collection id
  /// Map{collectionId, docIds}
  Future<void> signDeletions(Map<String, Set<String>> idsQueuedForDeletion);

  /// Returns the deletion registry for the user, if empty set it first before returning it.
  Future<DeletionRegistry> getOrSetRegistry();

  /// This method should be implemented the clean the registry.
  /// A return value of true indicates that the caller must invalidate cache.
  Future<bool> cleanRegistry();

  /// Opens the local database used for syncing for the user
  Future<semb.Database?> openLocalDb(String userId);

  /// Close the local database used for syncing
  Future<void> closeLocalDb();

  /// Deletes the opened database if it exists
  Future<void> deleteLocalDb();
}

/// Not implemented yet - used to identify the sync state?
enum SyncState {
  starting,
  syncing, // including garbage collection and reconciliation
  synced,
  stopped,
}
