import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:collection/collection.dart';
import 'package:sembast/sembast.dart' as sb;
import 'package:sync_service/src/data/data.dart';

import '../../application/services/sync_delegate.dart';
import '../../domain/entities/sync_entity.dart';
import '../../helpers/helpers.dart';

/// This implementation of SyncDelegate utilises Firestore as remote and Sembast as local storage
/// All synced data repository should implement [FirestoreSymbastSyncableRepo] interface to ensure data are read/write correctly
/// following a standard approach to soft delete amd read only from cache
/// Firestore has a TTL deletion that is perfect for this use case:
/// https://firebase.google.com/docs/firestore/ttl
class FirestoreSyncDelegate<T extends SyncEntity> extends SyncDelegate<T> with Loggable {
  /// A callback to retrieve the sync query for this delegate/collection
  final fs.Query<T> Function(
    fs.CollectionReference<T> collection,
    String userId,
  ) syncQuery;

  FirestoreSyncDelegate({
    super.updatedAtField,
    required super.collectionPath,
    required this.syncQuery,
    required this.firestoreMapper,
    required this.sembastMapper,
  });

  // service
  @override
  FirestoreSyncService get syncService => super.syncService as FirestoreSyncService;
  fs.FirebaseFirestore get firestore => syncService.firestore;
  sb.Database get sembastDb => syncService.sembastDb;

  // firestore
  final JsonMapper<T> firestoreMapper;
  late final fs.CollectionReference collection = firestore.collection(collectionPath);
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
  late final sb.StoreRef<String, Map<String, dynamic>> sembastStore = sb.StoreRef(collectionPath);

  @override
  Future<DateTime?> getLastUpdatedAtFromCache() async {
    final record = await sembastStore.find(sembastDb,
        finder: sb.Finder(
          sortOrders: [sb.SortOrder(updatedAtField, false)],
          limit: 1,
        ));
    final value = sembastMapper.fromMapOrNull(record.firstOrNull?.value);
    return value?.updatedAt;
  }

  @override
  Future<void> clearCache() async {
    await sembastStore.delete(sembastDb);
  }

  @override
  Stream<SyncChangeSet<T>> watchRemoteChanges({
    required DateTime? lastUpdatedAt,
    required String userId,
  }) {
    var query = syncQuery(typedCollection, userId);
    if (lastUpdatedAt != null) {
      devLog('$debugDetails watchChanges: watching documents where "updatedAt" > $lastUpdatedAt');
      query = query.where(updatedAtField, isGreaterThan: lastUpdatedAt.toIso8601String());
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

        // devLog('$debugDetails watchChanges: '
        //     'added=${added.length} modified=${modified.length} removed=${removed.length}');
        final updated = [...added, ...modified];

        // devLog('$debugDetails watchChanges: caching ${updated.length} documents');

        return SyncChangeSet(put: updated, remove: removed);
      }
    });
  }

  @override
  Future<void> putCache(List<T> values) async {
    final ids = values.map((e) => e.id);
    final sembastValues = values.map((e) => sembastMapper.toMap(e)).toList();
    await sembastStore.records(ids).put(sembastDb, sembastValues);
  }
}
