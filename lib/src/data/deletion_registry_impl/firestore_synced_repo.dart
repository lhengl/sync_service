part of 'deletion_registry_impl.dart';

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
/// - Will permanently delete from both cache/remote
/// - Will sign the deletion on the deletion registry to ensure deletions are synced
/// - It is important to always sign the deletion to avoid stale/deleted data living forever rent free in cache
/// - Always sign deletion in a batch operation by calling [signDeletions] to ensure atomicity
abstract class FirestoreSyncedRepo<T extends SyncEntity> extends SyncedRepo<T> with Loggable {
  FirestoreSyncedRepo({
    required super.path,
    required super.syncService,
    required this.firestoreMapper,
    required this.sembastMapper,
  });

  // service
  @override
  FirestoreSyncService get syncService => super.syncService as FirestoreSyncService;
  fs.FirebaseFirestore get firestore => syncService.firestore;
  sb.Database get db => syncService.db;

  // firestore
  final JsonMapper<T> firestoreMapper;
  late final fs.CollectionReference collection = firestore.collection(path);
  late final fs.CollectionReference<T> typedCollection = collection.withConverter(
    fromFirestore: (value, __) {
      return firestoreMapper.fromMap(value.data()!);
    },
    toFirestore: (value, __) {
      return firestoreMapper.toMap(value);
    },
  );

  // sembast
  final JsonMapper<T> sembastMapper;
  late final sb.StoreRef<String, Map<String, dynamic>> sembastStore = sb.StoreRef(path);

  //////////// CRUD OPTIONS

  @override
  Future<T?> get(String id) async {
    devLog('$debugDetails get: id=$id');
    final record = await sembastStore.record(id).get(db);
    return sembastMapper.fromMapOrNull(record);
  }

  @override
  Future<T> create(T value) async {
    devLog('$debugDetails create: id=${value.id}');

    // setup
    value = value.clone();
    if (value.id.isEmpty) {
      value.id = typedCollection.doc().id;
    }
    value.createdAt = value.updatedAt = await currentTime;

    // transaction
    await db.transaction((transaction) async {
      await sembastStore.record(value.id).put(transaction, sembastMapper.toMap(value));
      await typedCollection.doc(value.id).set(value);
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
    await db.transaction((transaction) async {
      await sembastStore.record(value.id).put(transaction, sembastMapper.toMap(value));
      await typedCollection.doc(value.id).set(value, fs.SetOptions(merge: true));
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
    await db.transaction((transaction) async {
      await sembastStore.record(value.id).delete(transaction);
      final batch = firestore.batch();
      batch.delete(typedCollection.doc(value.id));
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
    final records = await sembastStore.records(ids).get(db);
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
      batch.set(typedCollection.doc(clone.id), clone);
    }

    // transaction
    await db.transaction((transaction) async {
      await sembastStore.records(ids).add(transaction, sembastValues);
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
      await sembastStore.records(ids).put(transaction, sembastValues);
      final batch = firestore.batch();
      for (var clone in clones) {
        batch.set(typedCollection.doc(clone.id), clone, fs.SetOptions(merge: true));
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
    final ids = clones.map((e) => e.id);

    // transaction
    await db.transaction((transaction) async {
      await sembastStore.records(ids).delete(transaction);
      // sign deletion registry in a transaction to ensure it is deleted
      final batch = firestore.batch();
      for (var clone in clones) {
        batch.delete(typedCollection.doc(clone.id));
      }
      // Deletion signage must be done as part of a transaction to ensure integrity of data
      await signDeletions(ids: ids.toSet(), batch: batch);

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
    final records = await sembastStore.find(db);
    final objects = records.whereNotNull().map((e) => sembastMapper.fromMap(e.value));
    return objects.toList();
  }

  @override
  Stream<List<T>> watchAll() {
    devLog('$debugDetails watchAll');
    return sembastStore.query().onSnapshots(db).map((snapshots) {
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
    final remoteDocs = (await typedCollection.get()).data;
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
  /// [FirestoreSyncDelegate._watchRemoteChanges] will also sign the registry during a deletion,
  /// but is only intended only for other devices not the same device. It does not guarantee atomicity.
  ///
  /// ----- SO DON'T FORGET to sign the registry on each deletion. ------
  Future<void> signDeletions({
    required Set<String> ids,
    fs.WriteBatch? batch,
  }) async {
    if (batch == null) {
      throw Exception('batch must not be null');
    }
    batch.update(syncService.registryTypedCollection.doc(syncService.userId), {
      'deletions.${syncService.deviceId}.$path': fs.FieldValue.arrayUnion(ids.toList()),
    });
  }
}
