part of 'firestore_soft_deletion.dart';

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
/// - Will move the record to a trash collection to ensure deletion have a grace period for syncing
/// - Always delete items using one of these methods to ensure deletions are synced across multiple devices.
abstract class FirestoreSoftRemoteRepo<T extends SyncEntity> extends RemoteRepo<T>
    with FirestoreTrashMixin, FirestoreHelper {
  FirestoreSoftRemoteRepo({
    required this.firestore,
    required super.path,
    super.idField,
    super.updateField,
    super.createField,
    super.timestampProvider,
    required this.firestoreMapper,
    required this.userTrashQuery,
    this.disposalAge = const Duration(days: 14),
    this.trashRegistryPath = 'trashRegistry',
  });

  @override
  final Duration disposalAge;

  @override
  final String trashRegistryPath;

  final FirestoreUserQuery<T> userTrashQuery;

  // firestore
  @override
  final fs.FirebaseFirestore firestore;
  final JsonMapper<T> firestoreMapper;
  late final fs.CollectionReference<JsonObject> collection = firestore.collection(path);
  late final fs.CollectionReference<T> typedCollection = collection.withConverter(
    fromFirestore: (value, __) {
      return firestoreMapper.fromMap(value.data()!);
    },
    toFirestore: (value, __) {
      return firestoreMapper.toMap(value);
    },
  );
  late final fs.CollectionReference<JsonObject> trashCollection = firestore.collection(trashPath);
  late final fs.CollectionReference<T> trashTypedCollection = trashCollection.withConverter(
    fromFirestore: (value, __) {
      return firestoreMapper.fromMap(value.data()!);
    },
    toFirestore: (value, __) {
      return firestoreMapper.toMap(value);
    },
  );

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
    final clone = value.clone();
    if (clone.id.isEmpty) {
      clone.id = typedCollection.doc().id;
    }
    clone.createdAt = clone.updatedAt = await currentTime;

    // write

    await typedCollection.doc(clone.id).set(clone);
    return clone;
  }

  @override
  Future<T> update(T value) async {
    devLog('update: id=${value.id}');

    // setup
    final clone = value.clone();
    clone.updatedAt = await currentTime;

    // write
    await typedCollection.doc(clone.id).set(clone, fs.SetOptions(merge: true));
    return clone;
  }

  @override
  Future<T> upsert(T value) async {
    devLog('upsert: id=${value.id}');
    return update(value);
  }

  @override
  Future<T> delete(T value) async {
    devLog('delete: id=${value.id}');

    // setup
    final T clone = value.clone();
    clone.updatedAt = await currentTime;

    // batch
    final batch = firestore.batch();
    batch.set(trashTypedCollection.doc(clone.id), clone);
    batch.delete(typedCollection.doc(clone.id));
    await batch.commit();
    return clone;
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
    final List<T> clones = values.map((e) => e.clone() as T).toList();
    for (var clone in clones) {
      clone.createdAt = clone.updatedAt = now;
    }
    final ids = clones.map((e) => e.id);

    // batch
    final batch = firestore.batch();
    for (var clone in clones) {
      batch.set(typedCollection.doc(clone.id), clone);
    }
    await batch.commit();

    devLog('batchCreate: ${ids.length} documents created successfully!: $ids');
    return clones;
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
    final List<T> clones = values.map((e) => e.clone() as T).toList();
    for (var clone in clones) {
      clone.updatedAt = now;
    }

    final ids = clones.map((e) => e.id);

    // batch
    final batch = firestore.batch();
    for (var clone in clones) {
      batch.set(typedCollection.doc(clone.id), clone, fs.SetOptions(merge: true));
    }
    await batch.commit();

    devLog('batchUpdate: ${ids.length} documents updated successfully!: $ids');
    return clones;
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
    final List<T> clones = values.map((e) => e.clone() as T).toList();
    for (var clone in clones) {
      clone.updatedAt = now;
    }
    final ids = clones.map((e) => e.id);

    // batch
    final batch = firestore.batch();
    for (var clone in clones) {
      batch.set(trashTypedCollection.doc(clone.id), clone);
      batch.delete(typedCollection.doc(clone.id));
    }
    await batch.commit();
    devLog('batchDelete: ${ids.length} documents deleted successfully!: $ids');
    return clones;
  }

  @override
  Future<List<T>> batchDeleteByIds(Set<String> ids) async {
    devLog('batchDeleteByIds: ids=$ids');
    final values = await batchGet(ids);
    return batchDelete(values);
  }

  //////////// TRASH

  Future<List<T>> getUserTrash({required String userId}) async {
    devLog('getUserTrash');
    final snapshot = (await userTrashQuery(trashTypedCollection, userId).get());
    final docs = snapshot.docs.map((doc) {
      return doc.data();
    }).toList();
    return docs;
  }

  Stream<List<T>> watchUserTrash({required String userId}) {
    devLog('watchUserTrash');
    return userTrashQuery(trashTypedCollection, userId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return doc.data();
      }).toList();
    });
  }

  Future<void> disposeOldUserTrash({required String userId}) async {
    devLog('disposeOldUserTrash');
    final newCutoff = await signRegistry(userId: userId, deviceId: 'remote');

    final remoteSnapshot = await userTrashQuery(trashTypedCollection, userId)
        .where(
          updateField,
          isLessThan: newCutoff.toIso8601String(),
        )
        .get();
    final remoteTrashIds = remoteSnapshot.docs.map((doc) => doc.id);
    final batch = firestore.batch();
    for (var id in remoteTrashIds) {
      batch.delete(trashTypedCollection.doc(id));
    }
    await batch.commit();
    devLog('disposeOldUserTrash: ${remoteTrashIds.length} records disposed from remote: $remoteTrashIds');
  }

  Future<void> clearUserTrash({required String userId}) async {
    devLog('clearUserTrash');
    final snapshot = (await userTrashQuery(trashTypedCollection, userId).get());
    final trashIds = snapshot.docs.map((doc) => doc.id);
    final batch = firestore.batch();
    for (var trashId in trashIds) {
      batch.delete(trashTypedCollection.doc(trashId));
    }
    await batch.commit();
  }

  Stream<TrashRegistry> watchUserRegistry({required String userId}) {
    return registryTypedCollection.doc(userId).snapshots().map(
          (e) => e.data() ?? TrashRegistry(userId: userId),
        );
  }

  //////////// DEBUG OPTIONS

  @override
  Future<List<T>> getAll() async {
    devLog('getAll');
    final snapshot = await typedCollection.get();
    return snapshot.docs.map((doc) {
      return doc.data();
    }).toList();
  }

  @override
  Stream<List<T>> watchAll() {
    devLog('watchAll');
    return typedCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return doc.data();
      }).toList();
    });
  }

  @override
  Future<List<T>> deleteAll() async {
    devLog('deleteAll');
    final allDocs = await getAll();
    await batchDelete(allDocs);
    devLog('deleteAll: Deleted ${allDocs.length} from cache/remote documents');
    return allDocs;
  }

  //////////// DEBUG TRASH

  Future<List<T>> getTrash() async {
    devLog('getTrash');
    final snapshot = (await trashTypedCollection.get());
    final docs = snapshot.docs.map((doc) {
      return doc.data();
    }).toList();
    return docs;
  }

  Stream<List<T>> watchTrash() {
    devLog('watchTrash');
    return trashTypedCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return doc.data();
      }).toList();
    });
  }

  Future<void> clearTrash() async {
    devLog('clearTrash');
    final snapshot = (await trashTypedCollection.get());
    final trashIds = snapshot.docs.map((doc) => doc.id);
    final batch = firestore.batch();
    for (var trashId in trashIds) {
      batch.delete(trashTypedCollection.doc(trashId));
    }
    await batch.commit();
  }
}
