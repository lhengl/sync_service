import 'dart:async';

import 'package:flutter_kronos/flutter_kronos.dart';

import '../../domain/entities/sync_entity.dart';
import '../../helpers/helpers.dart';
import '../services/sync_service.dart';

/// A remote repository will interface directly with the remote database and will ignore the cache.
/// Write operations will not write to cache.
/// On deletion, this repository will sign the registry as "remote" because it is not attached to a device.
/// Write operations should ideally be done by the SyncedRepo. However, I left the writing capability
/// in the remote repo for debugging purpose to imitate a delete from a remote source such as a web service.
/// You must always sign a deletion even when deleting from a remote source.
abstract class RemoteRepo<T extends SyncEntity> with Loggable {
  final String collectionPath;

  final SyncService syncService;

  RemoteRepo({
    required this.collectionPath,
    required this.syncService,
  });

  Future<DateTime> get currentTime async => await FlutterKronos.getNtpDateTime ?? DateTime.now();

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
