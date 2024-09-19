import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:collection/collection.dart';
import 'package:sembast/sembast.dart' as semb;
import 'package:sembast/timestamp.dart' as semb;

import '../../application/services/sync_delegate.dart';
import '../../domain/entities/deletion_registry.dart';
import '../../domain/entities/sync_entity.dart';
import '../../helpers/firestore_helper.dart';
import '../../helpers/loggable.dart';
import '../../helpers/sembast_helper.dart';
import '../repos/firestore_remote_repo.dart';
import '../repos/firestore_synced_repo.dart';

/// This implementation of SyncDelegate utilises Firestore as remote and Sembast as local storage
/// All synced data repository should implement [FirestoreSymbastSyncableRepo] interface to ensure data are read/write correctly
/// following a standard approach to soft delete amd read only from cache
/// Firestore has a TTL deletion that is perfect for this use case:
/// https://firebase.google.com/docs/firestore/ttl
class FirestoreSyncDelegate<T extends SyncEntity> extends SyncDelegate<T, fs.Timestamp> with Loggable {
  /// A callback to retrieve the sync query for this delegate/collection
  final fs.Query<T> Function(
    fs.CollectionReference<T> collection,
    String userId,
  ) syncQuery;

  @override
  final FirestoreSyncedRepo<T> syncedRepo;
  @override
  final FirestoreRemoteRepo<T> remoteRepo;

  FirestoreSyncDelegate({
    super.updatedAtField,
    required this.syncedRepo,
    required this.remoteRepo,
    required this.syncQuery,
  });

  fs.FirebaseFirestore get firestore => syncedRepo.firestore;
  semb.Database get sembastDb => syncedRepo.sbCollection.db;
  SembastCollection<T> get sembastCollection => syncedRepo.sbCollection;
  FirestoreCollection<DeletionRegistry> get deletionCollection => syncedRepo.deletionCollection;
  semb.StoreRef<String, Map<String, dynamic>> get sembastStore => syncedRepo.sbCollection.store;

  @override
  Future<fs.Timestamp?> getLastUpdatedAtFromCache() async {
    final record = await sembastStore.find(sembastDb,
        finder: semb.Finder(
          sortOrders: [semb.SortOrder(updatedAtField, false)],
          limit: 1,
        ));
    final datetime = record.firstOrNull?.value[updatedAtField] as semb.Timestamp?;
    return datetime?.toFirestoreTimestamp();
  }

  @override
  Future<void> clearCache() async {
    await sembastStore.delete(sembastDb);
  }

  @override
  Stream<SyncChangeSet<T>> watchRemoteChanges({
    required fs.Timestamp? lastUpdatedAt,
    required String userId,
  }) {
    var query = syncQuery(syncedRepo.fsCollection.typedCollection, userId);
    if (lastUpdatedAt != null) {
      devLog('$debugDetails watchChanges: watching documents where "updatedAt" > ${lastUpdatedAt.toPrettyString()}');
      query = query.where(updatedAtField, isGreaterThan: lastUpdatedAt);
    } else {
      devLog('$debugDetails watchChanges: watching all user documents in collection');
    }
    return query.snapshots().map((snapshot) {
      if (snapshot.docChanges.isEmpty) {
        return SyncChangeSet();
      } else {
        final changes = snapshot.docChanges.groupListsBy((e) => e.type);
        final added = changes[fs.DocumentChangeType.added]?.map((e) => e.doc.data()).whereNotNull().toList() ?? [];
        final modified =
            changes[fs.DocumentChangeType.modified]?.map((e) => e.doc.data()).whereNotNull().toList() ?? [];
        final removed = changes[fs.DocumentChangeType.removed]?.map((e) => e.doc.data()).whereNotNull().toList() ?? [];

        devLog('$debugDetails watchChanges: '
            'added=${added.length} modified=${modified.length} removed=${removed.length}');
        final updated = [...added, ...modified];

        devLog('$debugDetails watchChanges: caching ${updated.length} documents');

        return SyncChangeSet(put: updated, remove: removed);
      }
    });
  }

  @override
  Future<void> putCache(List<T> values) async {
    final ids = values.map((e) => e.id);
    final sembastValues = values.map((e) => sembastCollection.toSembast(e)).toList();
    await sembastStore.records(ids).put(sembastDb, sembastValues);
  }
}
