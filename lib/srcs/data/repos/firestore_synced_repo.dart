import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:collection/collection.dart';
import 'package:sembast/sembast.dart' as semb;

import '../../application/repos/sync_repo.dart';
import '../../application/services/sync_service.dart';
import '../../domain/entities/deletion_registry.dart';
import '../../domain/entities/sync_entity.dart';
import '../../helpers/firestore_helper.dart';
import '../../helpers/loggable.dart';
import '../../helpers/sembast_helper.dart';
import '../services/firestore_sync_service.dart';

/// This implementation is an offline first approach. It assumes that the [db] local database
/// is synced by the SyncService so a get from cache operation will result in the return of synced data.
/// Additional method implementation should follow this assumption.
///
/// READ
/// [get], [batchGet], [getAll], [watchAll]
/// will read from cache only to save on read and egress
///
/// CREATE/UPDATE
/// [create],[update], [upsert], [batchCreate], [batchUpdate],[batchUpsert] will write to both cache/remote
///
/// DELETION
/// [delete], [deleteById], [batchDelete], [batchDeleteByIds], [deleteAll]
/// will permanently delete from both cache/remote
abstract class FirestoreSyncedRepo<T extends SyncEntity> with FirestoreHelper, Loggable implements SyncedRepo<T> {
  @override
  final String syncId;

  FirestoreSyncedRepo({required this.syncId});

  // service
  @override
  FirestoreSyncService get syncService => SyncService.instanceFor(syncId) as FirestoreSyncService;

  fs.FirebaseFirestore get firestore => syncService.firestore;

  // firestore
  FirestoreCollection<T> get fsCollection;
  @override
  String get collectionPath => fsCollection.path;
  fs.CollectionReference<T> get fsTypedCollection => fsCollection.typedCollection;

  // sembast
  SembastCollection<T> get sbCollection;

  // deletion
  FirestoreCollection<DeletionRegistry> get deletionCollection => syncService.deletionCollection;

  //////////// CRUD OPTIONS

  String get debugDetails => '[SyncId:$syncId]';

  @override
  Future<T?> get(String id) async {
    devLog('$debugDetails get: id=$id');
    final record = await sbCollection.store.record(id).get(sbCollection.db);
    return sbCollection.fromSembastOrNull(record);
  }

  @override
  Future<T> create(T value) async {
    devLog('$debugDetails create: id=${value.id}');

    // setup
    value = value.clone();
    if (value.id.isEmpty) {
      value.id = fsCollection.typedCollection.doc().id;
    }
    value.createdAt = value.updatedAt = await currentTime;

    // transaction
    await sbCollection.db.transaction((transaction) async {
      await sbCollection.store.record(value.id).put(transaction, sbCollection.toSembast(value));
      await fsCollection.typedCollection.doc(value.id).set(value);
    });
    return value;
  }

  @override
  Future<T> update(T value) async {
    devLog('$debugDetails update: id=${value.id}');

    // setup
    value = value.clone();
    value.updatedAt = await currentTime;

    // transaction
    await sbCollection.db.transaction((transaction) async {
      await sbCollection.store.record(value.id).put(transaction, sbCollection.toSembast(value));
      await fsCollection.typedCollection.doc(value.id).set(value, fs.SetOptions(merge: true));
    });
    return value;
  }

  @override
  Future<T> upsert(T value) async {
    devLog('$debugDetails upsert: id=${value.id}');
    return update(value);
  }

  @override
  Future<T> delete(T value) async {
    devLog('$debugDetails delete: id=${value.id}');

    // transaction
    await sbCollection.db.transaction((transaction) async {
      await sbCollection.store.record(value.id).delete(transaction);
      final batch = firestore.batch();
      batch.delete(fsCollection.typedCollection.doc(value.id));
      // Deletion signage must be done as part of a transaction to ensure integrity of data
      await signDeletions(ids: {value.id}, batch: batch);
      await batch.commit();
    });
    return value;
  }

  @override
  Future<T?> deleteById(String id) async {
    devLog('$debugDetails deleteById: id=$id');
    final value = await get(id);
    if (value == null) {
      return null;
    }
    return delete(value);
  }

  //////////// BATCH OPTIONS

  @override
  Future<List<T>> batchGet(Set<String> ids) async {
    devLog('$debugDetails batchGet: count=${ids.length} ids=$ids');
    ids.remove('');
    if (ids.isEmpty) {
      return [];
    }
    final records = await sbCollection.store.records(ids).get(sbCollection.db);
    final objects = records.whereNotNull().map((e) => sbCollection.fromSembast(e));
    return objects.toList();
  }

  @override
  Future<List<T>> batchCreate(List<T> values) async {
    devLog('$debugDetails batchCreate: count=${values.length}');
    // if empty, nothing to do
    if (values.isEmpty) {
      return values;
    }

    // set up
    final now = await currentTime;
    for (var value in values) {
      value = value.clone();
      value.createdAt = value.updatedAt = now;
    }
    final ids = values.map((e) => e.id);
    final sembastValues = values.map((e) => sbCollection.toSembast(e)).toList();
    final batch = firestore.batch();
    for (var value in values) {
      batch.set(fsCollection.typedCollection.doc(value.id), value);
    }

    // transaction
    await sbCollection.db.transaction((transaction) async {
      await sbCollection.store.records(ids).add(transaction, sembastValues);
      await batch.commit();
    });

    devLog('batchCreate: ${ids.length} documents created successfully!: $ids');
    return values;
  }

  @override
  Future<List<T>> batchUpdate(List<T> values) async {
    devLog('$debugDetails batchUpdate: count=${values.length}');
    // if empty, nothing to do
    if (values.isEmpty) {
      return values;
    }

    // set up

    final now = await currentTime;
    for (var value in values) {
      value = value.clone();
      value.updatedAt = now;
    }

    final ids = values.map((e) => e.id);
    final sembastValues = values.map((e) => sbCollection.toSembast(e)).toList();

    // transaction
    await sbCollection.db.transaction((transaction) async {
      await sbCollection.store.records(ids).put(transaction, sembastValues);
      final batch = firestore.batch();
      for (var value in values) {
        batch.set(fsCollection.typedCollection.doc(value.id), value, fs.SetOptions(merge: true));
      }
      await batch.commit();
    });

    devLog('batchUpdate: ${ids.length} documents updated successfully!: $ids');
    return values;
  }

  @override
  Future<List<T>> batchUpsert(List<T> values) async {
    devLog('$debugDetails batchUpsert: count=${values.length}');
    return batchUpdate(values);
  }

  @override
  Future<List<T>> batchDelete(List<T> values) async {
    devLog('$debugDetails batchDelete: count=${values.length}');
    // if empty, nothing to do
    if (values.isEmpty) {
      return values;
    }

    // set up
    final now = await currentTime;
    for (var value in values) {
      value = value.clone();
      value.updatedAt = now;
    }
    final ids = values.map((e) => e.id);

    // transaction
    await sbCollection.db.transaction((transaction) async {
      await sbCollection.store.records(ids).delete(transaction);
      // sign deletion registry in a transaction to ensure it is deleted
      final batch = firestore.batch();
      for (var value in values) {
        batch.delete(fsCollection.typedCollection.doc(value.id));
      }
      // Deletion signage must be done as part of a transaction to ensure integrity of data
      await signDeletions(ids: ids.toSet(), batch: batch);

      await batch.commit();
    });

    devLog('batchDelete: ${ids.length} documents deleted successfully!: $ids');
    return values;
  }

  @override
  Future<List<T>> batchDeleteByIds(Set<String> ids) async {
    devLog('$debugDetails batchDeleteByIds: ids=$ids');
    final values = await batchGet(ids);
    return batchDelete(values);
  }

  //////////// DEBUG OPTIONS

  @override
  Future<List<T>> getAll() async {
    devLog('$debugDetails getAll');
    final records = await sbCollection.store.find(sbCollection.db);
    final objects = records.whereNotNull().map((e) => sbCollection.fromSembast(e.value));
    return objects.toList();
  }

  @override
  Stream<List<T>> watchAll() {
    devLog('$debugDetails watchAll');
    return sbCollection.store.query().onSnapshots(sbCollection.db).map((snapshots) {
      return snapshots.map((record) {
        return sbCollection.fromSembast(record.value);
      }).toList();
    });
  }

  @override
  Future<List<T>> deleteAll() async {
    devLog('$debugDetails deleteAll');
    List<T> cachedDocs = [];

    // Get all documents from cache to delete from cache and remote
    cachedDocs = await getAll();
    await batchDelete(cachedDocs);
    devLog('$debugDetails deleteAll: Deleted ${cachedDocs.length} from cache/remote documents');

    // Also retrieve documents from remote in case cache is not in sync
    final remoteDocs = (await fsCollection.typedCollection.get()).data;
    if (remoteDocs.isEmpty) return cachedDocs;
    devLog('$debugDetails deleteAll: Found and deleted ${remoteDocs.length} remote documents not in cache.');
    await batchDelete(remoteDocs);

    return [...cachedDocs, ...remoteDocs];
  }

  /// A special method that signs a deletion in a registry.
  /// This registry ensures that deletions are synced across multiple devices.
  /// If you are deleting a document, use [delete], [deleteById], [batchDelete], [batchDeleteByIds], [deleteAll].
  /// Doing so will sign the registry for deletion.
  /// However, if you need to delete a record outside of these default methods, ensure to call [signDeletions]
  /// as part of a batch operation. Otherwise the devices will go out of sync without notice.
  /// [FirestoreSyncDelegate.watchRemoteChanges] will also sign the registry during a deletion,
  /// but is only intended only for other devices not the same device. It does not guarantee atomicity.
  ///
  /// ----- SO DON'T FORGET to sign the registry on each deletion. ------
  Future<fs.WriteBatch> signDeletions({
    required Set<String> ids,
    required fs.WriteBatch batch,
  }) async {
    batch.update(deletionCollection.typedCollection.doc(syncService.userId), {
      'deletions.${syncService.deviceId}.${fsCollection.path}': fs.FieldValue.arrayUnion(ids.toList()),
    });
    return batch;
  }
}
