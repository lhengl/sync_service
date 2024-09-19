import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../application/repos/sync_repo.dart';
import '../../domain/entities/sync_entity.dart';
import '../../helpers/firestore_helper.dart';
import '../../helpers/loggable.dart';

abstract class FirestoreRemoteRepo<T extends SyncEntity> with FirestoreHelper, Loggable implements RemoteRepo<T> {
  FirestoreCollection<T> get fsCollection;

  /// The time a soft deleted document will expire, which will in turn be permanently deleted by the firestore policy
  fs.CollectionReference get collection => fsCollection.collection;
  fs.CollectionReference<T> get typedCollection => fsCollection.typedCollection;

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
}
