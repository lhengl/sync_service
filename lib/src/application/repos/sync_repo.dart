import 'dart:async';

import 'package:flutter_kronos/flutter_kronos.dart';

import '../../domain/entities/sync_entity.dart';
import '../../helpers/helpers.dart';
import '../services/sync_service.dart';

/// A synced repo assumes that the local database is synced by the SyncService so read from cache operation will
/// result in the return of synced data. Additional method implementation should follow this assumption.
abstract class SyncedRepo<T extends SyncEntity> with Loggable {
  final String collectionPath;

  final SyncService syncService;

  SyncedRepo({
    required this.collectionPath,
    required this.syncService,
  });

  String get debugDetails => '[DeviceId:${syncService.deviceId}]';

  Future<DateTime> get currentTime async => (await FlutterKronos.getNtpDateTime ?? DateTime.now()).toUtc();

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
