part of 'deletion_registry_impl.dart';

/// This implementation is an online first approach. It interfaces directly with firestore remote database.
/// It does not know what is in the cache.
/// This is useful to read data that are not in the cache/synced (such as other user data)
///
/// READ
/// [get], [batchGet], [getAll], [watchAll]
/// - Will read from remote directly
///
/// CREATE/UPDATE
/// [create],[update], [upsert], [batchCreate], [batchUpdate],[batchUpsert]
/// - Will write to remote
/// - Will update the createdAt/updatedAt fields used for discriminating data for syncing
///
/// DELETION
/// [delete], [deleteById], [batchDelete], [batchDeleteByIds], [deleteAll]
/// - Will permanently delete from remote
/// - Will sign the deletion on the deletion registry to ensure deletions are synced
/// - It is important to always sign the deletion to avoid stale/deleted data living forever rent free in cache
/// - Always sign deletion in a batch operation by calling [signDeletions] to ensure atomicity
abstract class FirestoreRemoteRepo<T extends SyncEntity> extends RemoteRepo<T> with FirestoreHelper {
  FirestoreRemoteRepo({
    required super.path,
    super.idField,
    super.updateField,
    super.createField,
    required this.firestoreMapper,
    // remote must be attached to a sync service in order to know the user id to sign deletion
    required this.syncService,
  }) : super(timestampProvider: syncService.timestampProvider);

  // service
  final FirestoreSyncService syncService;
  String get deviceId => syncService.deviceId;
  String get userId => syncService.userId;
  fs.FirebaseFirestore get firestore => syncService.firestore;

  // firestore
  final JsonMapper<T> firestoreMapper;
  late final fs.CollectionReference collection = firestore.collection(path);
  late final fs.CollectionReference<T> typedCollection = collection.withConverter(
    fromFirestore: (value, __) => firestoreMapper.fromMap(value.data()!),
    toFirestore: (value, __) => firestoreMapper.toMap(value),
  );

  // registry
  fs.CollectionReference get registryCollection => syncService.registryCollection;
  fs.CollectionReference<DeletionRegistry> get registryTypedCollection => syncService.registryTypedCollection;

  //////////// CRUD OPTIONS

  @override
  Future<T?> get(String id) async {
    devLog('get: id=$id');
    try {
      final snapshot = await typedCollection.doc(id).get();
      return snapshot.data();
    } catch (error, stacktrace) {
      devLog('Error retrieving document.', error: error, stackTrace: stacktrace);
      rethrow;
    }
  }

  @override
  Future<T> create(T value) async {
    devLog('create: id=${value.id}');

    // setup
    value = value.clone();
    if (value.id.isEmpty) {
      value.id = typedCollection.doc().id;
    }
    value.createdAt = value.updatedAt = await currentTime;

    // write

    await typedCollection.doc(value.id).set(value);
    return value;
  }

  @override
  Future<T> update(T value) async {
    devLog('update: id=${value.id}');

    // setup
    value = value.clone();
    value.updatedAt = await currentTime;

    // write
    await typedCollection.doc(value.id).set(value, fs.SetOptions(merge: true));
    return value;
  }

  @override
  Future<T> upsert(T value) async {
    devLog('upsert: id=${value.id}');
    return update(value);
  }

  @override
  Future<T> delete(T value) async {
    devLog('delete: id=${value.id}');
    final batch = firestore.batch();
    batch.delete(typedCollection.doc(value.id));
    // Deletion signage must be done as part of a batch to ensure integrity of data
    await signDeletions(ids: {value.id}, batch: batch);
    await batch.commit();
    return value;
  }

  @override
  Future<T?> deleteById(String id) async {
    devLog('deleteById: id=$id');
    final value = await get(id);
    if (value == null) {
      return null;
    }
    return delete(value);
  }

  //////////// BATCH OPTIONS

  @override
  Future<List<T>> batchGet(Set<String> ids) async {
    ids.remove('');
    if (ids.isEmpty) {
      return [];
    }
    List<List<String>> idBatches = splitBatch(ids);
    final futures = idBatches.map((idBatch) {
      return typedCollection.where(fs.FieldPath.documentId, whereIn: idBatch).get();
    });
    final result = await Future.wait(futures);
    final docs = result.map((snapshot) {
      return snapshot.data;
    });
    final expanded = docs.expand((e) => e).toList();
    return expanded;
  }

  @override
  Future<List<T>> batchCreate(List<T> values) async {
    devLog('batchCreate: count=${values.length}');
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

    // batch

    final batch = firestore.batch();
    for (var value in values) {
      batch.set(typedCollection.doc(value.id), value);
    }
    await batch.commit();

    devLog('batchCreate: ${ids.length} documents created successfully!: $ids');
    return values;
  }

  @override
  Future<List<T>> batchUpdate(List<T> values) async {
    devLog('batchUpdate: count=${values.length}');
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

    // batch

    final batch = firestore.batch();
    for (var value in values) {
      batch.set(typedCollection.doc(value.id), value, fs.SetOptions(merge: true));
    }
    await batch.commit();

    devLog('batchUpdate: ${ids.length} documents updated successfully!: $ids');
    return values;
  }

  @override
  Future<List<T>> batchUpsert(List<T> values) async {
    devLog('batchUpsert: count=${values.length}');
    return batchUpdate(values);
  }

  @override
  Future<List<T>> batchDelete(List<T> values) async {
    devLog('batchDelete: count=${values.length}');
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

    // batch
    // sign deletion registry in a transaction to ensure it is deleted
    final batch = firestore.batch();
    for (var value in values) {
      batch.delete(typedCollection.doc(value.id));
    }
    // Deletion signage must be done as part of a transaction to ensure integrity of data
    await signDeletions(ids: ids.toSet(), batch: batch);
    await batch.commit();
    devLog('batchDelete: ${ids.length} documents deleted successfully!: $ids');
    return values;
  }

  @override
  Future<List<T>> batchDeleteByIds(Set<String> ids) async {
    devLog('batchDeleteByIds: ids=$ids');
    final values = await batchGet(ids);
    return batchDelete(values);
  }

  //////////// DEBUG OPTIONS

  @override
  Future<List<T>> getAll() async {
    devLog('getAll');
    final snapshot = await typedCollection.get();
    return snapshot.data;
  }

  @override
  Stream<List<T>> watchAll() {
    devLog('watchAll');
    return typedCollection.snapshots().map((e) => e.data);
  }

  @override
  Future<List<T>> deleteAll() async {
    devLog('deleteAll');
    final allDocs = await getAll();
    await batchDelete(allDocs);
    devLog('deleteAll: Deleted ${allDocs.length} from cache/remote documents');
    return allDocs;
  }

  /// A special method that signs a deletion in a registry.
  /// This registry ensures that deletions are synced across multiple devices.
  /// If you are deleting a document, use [delete], [deleteById], [batchDelete], [batchDeleteByIds], [deleteAll].
  /// Doing so will sign the registry for deletion.
  /// However, if you need to delete a record outside of these default methods, ensure to call [signDeletions]
  /// as part of a batch operation. Otherwise the devices will go out of sync without notice.
  /// [FirestoreSyncRepo._watchRemoteChanges] will also sign the registry during a deletion,
  /// but is only intended only for other devices not the same device. It does not guarantee atomicity.
  ///
  /// ----- SO DON'T FORGET to sign the registry on each deletion. ------
  Future<void> signDeletions({
    required Set<String> ids,
    required fs.WriteBatch batch,
  }) async {
    // When a remote repository is deleting, there is no deviceId attached.
    // But it still needs to be signed in order to let synced devices know to delete from cache.
    // For this reason, a remote repository will need to store this in a spoof device id called 'remote'
    batch.update(registryTypedCollection.doc(userId), {
      'deletions.remote.$path': fs.FieldValue.arrayUnion(ids.toList()),
    });
  }
}
