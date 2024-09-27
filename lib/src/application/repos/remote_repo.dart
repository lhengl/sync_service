import 'dart:async';

import '../../domain/entities/sync_entity.dart';
import '../../helpers/helpers.dart';
import '../services/timestamp_provider.dart';

/// A remote repository will interface directly with the remote database and will ignore the cache.
/// Write operations will not write to cache.
/// On deletion, this repository will sign the registry as "remote" because it is not attached to a device.
/// Write operations should ideally be done by the SyncedRepo. However, I left the writing capability
/// in the remote repo for debugging purpose to imitate a delete from a remote source such as a web service.
/// You must always sign a deletion even when deleting from a remote source.
abstract class RemoteRepo<T extends SyncEntity> with Loggable {
  final String path;
  String get trashPath => '${path}_trash';
  final String idField;
  final String updateField;
  final String createField;

  RemoteRepo({
    required this.path,
    this.idField = 'id',
    this.updateField = 'updatedAt',
    this.createField = 'createdAt',
    this.timestampProvider = const KronosTimestampProvider(),
  });

  // timestamp provider
  final TimestampProvider timestampProvider;
  Future<DateTime> get currentTime async => (await timestampProvider.currentTime).toUtc();

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
