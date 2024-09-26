part of 'soft_deletion_impl.dart';

/// This implementation is an offline first approach. It assumes that the [db] local database
/// is synced by the SyncService so a get from cache operation will result in the return of synced data.
/// Additional method implementation should follow this assumption.
///
/// READ
/// [get], [batchGet], [getAll], [watchAll]
/// - Will read from cache only to save on read and egress
///
/// CREATE/UPDATE
/// [create],[update], [upsert], [batchCreate], [batchUpdate],[batchUpsert]
/// - Will write to both cache/remote
/// - Will update the createdAt/updatedAt fields used for discriminating data for syncing
///
/// DELETION
/// [delete], [deleteById], [batchDelete], [batchDeleteByIds], [deleteAll]
/// - Will move the record to a trash collection to ensure deletion have a grace period for syncing
/// - Always delete items using one of these methods to ensure deletions are synced across multiple devices.
abstract class FirestoreSoftSyncRepo<T extends SyncEntity> extends SyncedRepo<T> with Loggable {
  FirestoreSoftSyncRepo({
    required super.path,
    required super.syncService,
    required this.firestoreMapper,
    required this.sembastMapper,
  });

  // service
  @override
  FirestoreSoftSyncService get syncService => super.syncService as FirestoreSoftSyncService;
  fs.FirebaseFirestore get firestore => syncService.firestore;
  sb.Database get db => syncService.db;

  // mappers
  final JsonMapper<T> firestoreMapper;
  final JsonMapper<T> sembastMapper;

  // collection
  late final fs.CollectionReference<JsonObject> collection = firestore.collection(path);
  late final sb.StoreRef<String, JsonObject> store = sb.StoreRef(path);

  // trash
  late final fs.CollectionReference<JsonObject> trashCollection = firestore.collection(trashPath);
  late final sb.StoreRef<String, JsonObject> trashStore = sb.StoreRef(trashPath);

  //////////// CRUD OPTIONS

  @override
  Future<T?> get(String id) async {
    devLog('$debugDetails get: id=$id');
    final record = await store.record(id).get(db);
    return sembastMapper.fromMapOrNull(record);
  }

  @override
  Future<T> create(T value) async {
    devLog('$debugDetails create: id=${value.id}');

    // setup
    final T clone = value.clone();
    if (clone.id.isEmpty) {
      clone.id = collection.doc().id;
    }
    clone.createdAt = clone.updatedAt = await currentTime;

    // transaction
    await db.transaction((transaction) async {
      await store.record(clone.id).put(transaction, sembastMapper.toMap(clone));
      await collection.doc(clone.id).set(firestoreMapper.toMap(clone));
    });

    return clone;
  }

  @override
  Future<T> update(T value) async {
    devLog('$debugDetails update: id=${value.id}');

    // setup
    final T clone = value.clone();
    clone.updatedAt = await currentTime;

    // transaction
    await db.transaction((transaction) async {
      await store.record(clone.id).put(transaction, sembastMapper.toMap(clone));
      await collection.doc(clone.id).set(firestoreMapper.toMap(clone), fs.SetOptions(merge: true));
    });
    return clone;
  }

  @override
  Future<T> upsert(T value) async {
    devLog('$debugDetails upsert: id=${value.id}');
    return update(value);
  }

  @override
  Future<T> delete(T value) async {
    devLog('$debugDetails delete: id=${value.id}');

    final T clone = value.clone();
    clone.updatedAt = await currentTime;

    // transaction
    await db.transaction((transaction) async {
      // move to trash in cache
      await store.record(clone.id).delete(transaction);
      await trashStore.record(clone.id).put(transaction, sembastMapper.toMap(clone));
      final batch = firestore.batch();
      // move to trash on remote
      batch.set(trashCollection.doc(clone.id), firestoreMapper.toMap(clone));
      batch.delete(collection.doc(clone.id));
      await batch.commit();
    });
    return clone;
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
    final records = await store.records(ids).get(db);
    final objects = records.whereNotNull().map((e) => sembastMapper.fromMap(e));
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
    final clones = values.map((e) => e.clone() as T).toList();
    for (var clone in clones) {
      clone.createdAt = clone.updatedAt = now;
    }
    final ids = clones.map((e) => e.id);
    final sembastValues = clones.map((e) => sembastMapper.toMap(e)).toList();
    final batch = firestore.batch();
    for (var clone in clones) {
      batch.set(collection.doc(clone.id), firestoreMapper.toMap(clone));
    }

    // transaction
    await db.transaction((transaction) async {
      await store.records(ids).add(transaction, sembastValues);
      await batch.commit();
    });

    devLog('batchCreate: ${ids.length} documents created successfully!: $ids');
    return clones;
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
    final clones = values.map((e) => e.clone() as T).toList();
    for (var clone in clones) {
      clone.updatedAt = now;
    }

    final ids = clones.map((e) => e.id);
    final sembastValues = clones.map((e) => sembastMapper.toMap(e)).toList();

    // transaction
    await db.transaction((transaction) async {
      await store.records(ids).put(transaction, sembastValues);
      final batch = firestore.batch();
      for (var clone in clones) {
        batch.set(collection.doc(clone.id), firestoreMapper.toMap(clone), fs.SetOptions(merge: true));
      }
      await batch.commit();
    });

    devLog('batchUpdate: ${ids.length} documents updated successfully!: $ids');
    return clones;
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
    final clones = values.map((e) => e.clone() as T).toList();
    for (var clone in clones) {
      clone.updatedAt = now;
    }
    final sembastValues = clones.map((e) => sembastMapper.toMap(e)).toList();
    final ids = clones.map((e) => e.id);

    // transaction
    await db.transaction((transaction) async {
      // move to trash in cache
      await store.records(ids).delete(transaction);
      await trashStore.records(ids).put(transaction, sembastValues);

      final batch = firestore.batch();
      for (var clone in clones) {
        // move to trash on remote
        batch.set(trashCollection.doc(clone.id), firestoreMapper.toMap(clone));
        batch.delete(collection.doc(clone.id));
      }
      await batch.commit();
    });

    devLog('batchDelete: ${ids.length} documents deleted successfully!: $ids');
    return clones;
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
    final records = await store.find(db);
    final objects = records.whereNotNull().map((e) => sembastMapper.fromMap(e.value));
    return objects.toList();
  }

  @override
  Stream<List<T>> watchAll() {
    devLog('$debugDetails watchAll');
    return store.query().onSnapshots(db).map((snapshots) {
      return snapshots.map((record) {
        return sembastMapper.fromMap(record.value);
      }).toList();
    });
  }

  Stream<List<T>> watchTrash() {
    devLog('$debugDetails watchTrash');
    return trashStore.query().onSnapshots(db).map((snapshots) {
      return snapshots.map((record) {
        return sembastMapper.fromMap(record.value);
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
    final remoteDocs = (await collection.get()).docs.map((e) => firestoreMapper.fromMap(e.data())).toList();
    if (remoteDocs.isEmpty) return cachedDocs;
    devLog('$debugDetails deleteAll: Found and deleted ${remoteDocs.length} remote documents not in cache.');
    await batchDelete(remoteDocs);

    return [...cachedDocs, ...remoteDocs];
  }
}
