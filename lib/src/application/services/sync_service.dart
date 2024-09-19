import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_kronos/flutter_kronos.dart';
import 'package:sync_service/src/application/services/sync_delegate.dart';

import '../../domain/entities/deletion_registry.dart';
import '../../helpers/error_handler.dart';
import '../../helpers/loggable.dart';

/// Sync service must be started each time a user logs into a session
/// It manages the lifecycle of each sync delegate during the user session
abstract class SyncService with Loggable {
  static const defaultSyncId = 'default';

  /// The device id that uniquely identifies the source of the sync.
  /// If none provided, DeviceInfoPlugin will used to obtain device info,
  /// which will throw if the platform is not supported.
  /// For testing, provide a fake deviceId instead.
  late final String _deviceId;
  String get deviceId {
    try {
      return _deviceId;
    } catch (e) {
      throw Exception('Oops, did you forget to call init?');
    }
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

  /// A list of sync delegates that manages the syncing operation per collection.
  /// The order of this list dictates the order of sync operation.
  final List<SyncDelegate> delegates;

  /// The minimum interval for signing deletion. That is, signing will occur in real time,
  /// but is throttled to save writes. Defaults to 1 minute. So if a user deletes 1 document, then all synced services
  /// will delete that 1 document immediately. However, subsequent deletes won't be synced until after 1 minute.
  final Duration signingDebounce;

  SyncService({
    required this.delegates,
    Duration? offlineDeviceTtl,
    int? retriesOnFailure = 3,
    Duration? retryInterval,
    Duration? signingDebounce,
  })  : offlineDeviceTtl = const Duration(days: 14),
        retriesOnFailure = retriesOnFailure ?? 3,
        retryInterval = retryInterval ?? const Duration(seconds: 3),
        signingDebounce = signingDebounce ?? const Duration(minutes: 1) {
    // attach service to delegate and repo
    for (var delegate in delegates) {
      delegate.attachService(this);
    }
  }
  Future<SyncService> init({String? deviceId}) async {
    _deviceId = deviceId ?? await _getDeviceId();
    return this;
  }

  Future<String> _getDeviceId() async {
    var deviceId = '';
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? '';
    }
    return _cleanFieldName(deviceId);
  }

  // https://firebase.google.com/docs/firestore/quotas#limits
  // If dots are used in field names, then will break the mapping process during an update
  String _cleanFieldName(String fieldName) {
    fieldName = fieldName.replaceAll(RegExp(r'[^\w-]'), '_'); // Replace invalid characters

    // Ensure it doesn't start or end with double underscores
    if (fieldName.startsWith('__')) {
      fieldName = fieldName.substring(2);
    }
    if (fieldName.endsWith('__')) {
      fieldName = fieldName.substring(0, fieldName.length - 2);
    }

    return fieldName;
  }

  final StreamController<SyncState> _syncStateController = StreamController();

  String get debugDetails => '[UID:$userId][DEVICE:$deviceId]';

  String _userId = '';
  String get userId => _userId;

  Completer<bool> _syncSessionCompleter = Completer();
  Future<bool> get syncSessionIsReady => _syncSessionCompleter.future;

  Future<void> startSync({
    required String userId,
  }) async {
    try {
      _syncStateController.add(SyncState.starting);
      _syncSessionCompleter = Completer();
      _userId = userId;
      if (userId.isEmpty) {
        throw Exception('startSync: session userId must not be empty');
      }

      devLog('$debugDetails startSync: waiting for local database to be ready...');
      await getOrOpenLocalDatabase();

      devLog('$debugDetails startSync: cleaning and validating registry...');
      await cleanAndValidateCache();

      devLog('$debugDetails startSync: starting sync...');
      for (var delegate in delegates) {
        await delegate.startSync();
      }

      devLog('$debugDetails startSync: waiting for initial changes to be ready...');
      await Future.wait(delegates.map((e) => e.sessionIsReady));
      _syncSessionCompleter.complete(true);
      devLog('$debugDetails startSync: sync started successfully!');
    } catch (e, s) {
      devLog('$debugDetails Failed to start sync', error: e, stackTrace: s);
      rethrow;
    }
    _syncStateController.add(SyncState.syncing);
  }

  Stream<SyncState> watchSyncState() => _syncStateController.stream;

  Future<DateTime> get currentTime async => await FlutterKronos.getNtpDateTime ?? DateTime.now();

  Future<void> stopSync() async {
    for (var delegate in delegates) {
      await delegate.stopSync();
    }
    // we don't actually want to close the database, a user can stop the sync
    // but still be able to access the database. Database must be closed on dispose
    // await closeLocalDatabase();
    _syncStateController.add(SyncState.stopped);
    devLog('$debugDetails stopSync: syncing stopped.');
  }

  Future<void> cleanAndValidateCache() async {
    devLog('$debugDetails cleanAndValidate: signing registry for the first time...');

    final cleanedRegistry = await RetryHelper(
      retries: retriesOnFailure,
      retryInterval: retryInterval,
      future: () async {
        devLog('$debugDetails cleanAndValidate: cleaning registry...');
        return cleanRegistry();
      },
    ).retry();

    if (cleanedRegistry.cacheIsInvalid(deviceId)) {
      devLog('$debugDetails cleanAndValidate: No device found on registry. Cache is invalid and must be cleared.');
      await RetryHelper(
        retries: retriesOnFailure,
        retryInterval: retryInterval,
        future: () async {
          for (var delegate in delegates) {
            devLog('$debugDetails cleanAndValidate: Clearing cache for "${delegate.collectionPath}"...');
            await delegate.clearCache();
            devLog('$debugDetails cleanAndValidate: Cached cleared for "${delegate.collectionPath}".');
          }
        },
      ).retry();
    }
  }

  /// This is called by delegates to queue a set of ids for signing in a collection
  /// This will invoke [signDeletions] not more than once every [signingDebounce] interval
  void queueSigning(String collection, Set<String> ids);

  /// Sign the deletion of of all ids mapped by collection id
  /// Map{collectionId, docIds}
  Future<void> signDeletions();

  /// Returns the deletion registry for the user, if empty set it first before returning it.
  Future<DeletionRegistry> getOrSetRegistry();

  Stream<DeletionRegistry> watchRegistry();

  /// This method should be implemented the clean the registry.
  /// A return value of true indicates that the caller must invalidate cache.
  Future<DeletionRegistry> cleanRegistry();

  /// Opens the local database used for syncing for the user
  Future<dynamic> getOrOpenLocalDatabase();

  /// Close the local database used for syncing
  Future<void> closeLocalDatabase();

  /// Deletes the opened database if it exists
  Future<void> deleteLocalDatabase();

  /// Stops the sync, close local database and stream controllers
  Future<void> dispose() async {
    await stopSync();
    await closeLocalDatabase();
    await _syncStateController.close();
  }
}

/// Not implemented yet - used to identify the sync state?
enum SyncState {
  starting,
  syncing, // including garbage collection and reconciliation
  stopped,
}
