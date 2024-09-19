import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:collection/collection.dart';
import 'package:duration/duration.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart' as sb;
import 'package:sembast/sembast_io.dart';

import '../../application/services/sync_service.dart';
import '../../domain/entities/deletion_registry.dart';
import '../../helpers/loggable.dart';
import '../mappers/firestore_deletion_registry_mapper.dart';
import 'firestore_sync_delegate.dart';

/// Sync service must be started each time a user logs into a session
/// It manages the lifecycle of each sync delegate during the user session
class FirestoreSyncService extends SyncService with Loggable {
  final fs.FirebaseFirestore firestore;
  late sb.Database _sembastDb;
  sb.Database get sembastDb => _sembastDb;

  @override
  List<FirestoreSyncDelegate> get delegates => super.delegates as List<FirestoreSyncDelegate>;

  // delete registry
  final String deletionRegistryPath;
  final FirestoreDeletionRegistryMapper _deletionRegistryMapper = FirestoreDeletionRegistryMapper();
  late final fs.CollectionReference deletionCollection = firestore.collection(deletionRegistryPath);
  late final fs.CollectionReference<DeletionRegistry> deletionTypedCollection = deletionCollection.withConverter(
    fromFirestore: (value, __) {
      return _deletionRegistryMapper.fromMap(value.data()!);
    },
    toFirestore: (value, __) {
      return _deletionRegistryMapper.toMap(value);
    },
  );

  FirestoreSyncService({
    required List<FirestoreSyncDelegate> delegates,
    super.offlineDeviceTtl,
    super.retriesOnFailure,
    super.retryInterval,
    required this.firestore,
    super.signingDebounce,
    this.deletionRegistryPath = 'deletionRegistry',
  }) : super(delegates: delegates);

  /// To clean the registry, it is important to do so in a transaction where
  /// the read and write operation must be done atomically to ensure that the cleaning is not
  /// tampered by another operation. The cleaning process is as follow:
  /// 1. Read registry from firestore
  /// 2. Read all documents that needs to be deleted from registry
  /// 3. Delete these documents from cache
  /// 4. Sign the registry
  /// 5. Clean the registry, which will remove ids that have been signed by all devices
  /// 6. Commit the transaction, if it fails, then all changes wll be rolled back.
  ///
  /// Returns a clean COPY of the registry
  @override
  Future<DeletionRegistry> cleanRegistry() async {
    final currentTime = await this.currentTime;
    devLog(
        '$debugDetails cleanRegistry: userId=$userId deviceId=$deviceId currentTime=$currentTime timeToLive=${offlineDeviceTtl.pretty()}');

    // cancel the next call to signing, because we are already signing during the cleaning.
    _resetSigningDebounce();

    final registry = await sembastDb.transaction((sembastTransaction) async {
      final registry = await firestore.runTransaction((firestoreTransaction) async {
        final docRef = deletionTypedCollection.doc(userId);
        final registry = (await firestoreTransaction.get(docRef)).data() ?? DeletionRegistry(userId: userId);

        devLog('$debugDetails cleanRegistry: signing deletions on registry');
        final idsByCollection = registry.groupIdsByCollection();
        for (var collection in idsByCollection.entries) {
          final collectionId = collection.key;
          final docIds = collection.value;
          if (docIds.isNotEmpty) {
            final removedIds =
                (await sb.StoreRef(collectionId).records(docIds).delete(sembastTransaction)).whereNotNull();

            if (removedIds.isNotEmpty) {
              devLog(
                  '$debugDetails cleanRegistry: removed ${removedIds.length} documents from "$collectionId" cache: $removedIds');
            }
          }
        }
        registry.signDeletions(deviceId: deviceId, idsByCollection: idsByCollection);

        devLog('$debugDetails cleanRegistry: cleaning registry');
        registry.cleanRegistry(
          deviceId: deviceId,
          currentTime: currentTime,
          timeToLive: offlineDeviceTtl,
        );

        devLog('$debugDetails cleanRegistry: submitting registry');
        firestoreTransaction.set(docRef, registry);
        return registry;
      });
      return registry;
    });
    return registry;
  }

  final Map<String, Set<String>> _singingQueue = {};

  /// This is called by delegates to queue a set of ids for deletion in a collection
  /// This will invoke [signDeletions] not more than once every [signingDebounce] interval
  @override
  void queueSigning(String collection, Set<String> ids) {
    (_singingQueue[collection] ??= {}).addAll(ids);
    signDeletions();
  }

  /// Keeps track of the number of calls to signDeletions
  int _signingCalls = 0;
  DateTime _signingDebounceExpiration = DateTime.now();
  String get _signingDebounceTag => 'signing_deletions_$deviceId';

  void _resetSigningDebounce() {
    EasyDebounce.cancel(_signingDebounceTag);
    _signingCalls = 0;
    _singingQueue.clear();
  }

  /// Sign the registry.
  /// It's OK to not sign in a transaction here because if the cache is deleted here
  /// and the we fail to write the registry we will simply try to clear the cache again.
  /// So for example, if we deleted 10 items, and we fail to sign, the 10 items are still
  /// pending deletion, so the next time we try to delete, we will try to delete the same 10 items
  /// from cache (even if it doesn't exist in cache).
  ///
  /// NOTE:
  /// Signing is not part of a transaction and can be delayed. So if a cleaning is done during this time,
  /// then signing may fire again - signing 'ids' that have already been removed. This will rectify itself when all
  /// devices complete their next clean up. However, this constant resigning can enter into an infinite cycle.
  /// To avoid this, the debounce must be cancelled if a cleaning is started.
  @override
  Future<void> signDeletions() async {
    _signingCalls++;
    devLog('$debugDetails signDeletions: _signingCalls=$_signingCalls');

    if (_signingCalls == 1) {
      _signingDebounceExpiration = DateTime.now().add(signingDebounce);
      EasyDebounce.debounce(_signingDebounceTag, signingDebounce, () async {
        if (_singingQueue.isEmpty) {
          devLog('$debugDetails signDeletions: nothing to sign, exiting...');
          return;
        }

        devLog('$debugDetails signDeletions: $_singingQueue');

        await sembastDb.transaction((sembastTransaction) async {
          final Map<String, dynamic> registryUpdate = {};

          for (var collection in _singingQueue.entries) {
            final collectionId = collection.key;
            final docIds = collection.value;
            if (docIds.isNotEmpty) {
              final removedIds =
                  (await sb.StoreRef(collectionId).records(docIds).delete(sembastTransaction)).whereNotNull();

              registryUpdate.addAll({
                'deletions.$deviceId.$collectionId': fs.FieldValue.arrayUnion(docIds.toList()),
              });

              if (removedIds.isNotEmpty) {
                devLog(
                    '$debugDetails signDeletions: removed ${removedIds.length} documents from "$collectionId" cache: $removedIds');
              }
            }
          }

          await deletionTypedCollection.doc(userId).update(registryUpdate);

          // clear queue after signing
          _singingQueue.clear();
          // reset call count
          _signingCalls = 0;
        });
      });
    } else if (_signingCalls == 2) {
      devLog('$debugDetails signDeletions: debounced, latest operation will run in '
          '${_signingDebounceExpiration.difference(DateTime.now()).pretty()}');
    }
  }

  @override
  Future<DeletionRegistry> getOrSetRegistry() async {
    devLog('$debugDetails getOrSetRegistry: userId=$userId');
    final doc = deletionTypedCollection.doc(userId);
    DeletionRegistry? registry = (await doc.get()).data();
    if (registry == null) {
      registry = DeletionRegistry(userId: userId);
      await doc.set(registry);
    }
    devLog('$debugDetails getRegistry: registry=$registry');
    return registry;
  }

  @override
  Stream<DeletionRegistry> watchRegistry() {
    return deletionTypedCollection.doc(userId).snapshots().map((e) => e.data() ?? DeletionRegistry(userId: userId));
  }

  @override
  Future<sb.Database> getOrOpenLocalDatabase() async {
    try {
      return _sembastDb;
    } catch (e) {
      if (userId.isEmpty) {
        throw Exception('To open a user database, userId must not be empty');
      }

      try {
        final dir = await getApplicationDocumentsDirectory();
        await dir.create(recursive: true);
        final dbPath = join(dir.path, '${deviceId}_$userId.db');
        _sembastDb = await databaseFactoryIo.openDatabase(dbPath);
        return _sembastDb;
      } catch (e) {
        throw Exception('Error opening database: $e');
      }
    }
  }

  @override
  Future<void> closeLocalDatabase() async {
    await _sembastDb.close();
  }

  @override
  Future<void> deleteLocalDatabase() async {
    await _sembastDb.close();
    await databaseFactoryIo.deleteDatabase(_sembastDb.path);
  }
}
