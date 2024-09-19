import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:collection/collection.dart';
import 'package:duration/duration.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart' as semb;
import 'package:sembast/sembast_io.dart';

import '../../application/services/sync_service.dart';
import '../../domain/entities/deletion_registry.dart';
import '../../helpers/firestore_helper.dart';
import '../../helpers/loggable.dart';
import 'firestore_sync_delegate.dart';

/// Sync service must be started each time a user logs into a session
/// It manages the lifecycle of each sync delegate during the user session
class FirestoreSyncService extends SyncService with Loggable {
  static FirestoreSyncService get instance => SyncService.instance as FirestoreSyncService;

  final fs.FirebaseFirestore firestore;
  late semb.Database _sembastDb;
  semb.Database get sembastDb => _sembastDb;

  @override
  final List<FirestoreSyncDelegate> delegates;

  FirestoreSyncService({
    required super.syncId,
    required String deviceId,
    required this.delegates,
    super.offlineDeviceTtl,
    super.retriesOnFailure,
    super.retryInterval,
    required this.firestore,
    super.signingDebounce,
    String? deletionRegistryPath,
  }) : super(deviceId: FirestoreHelper.cleanFieldName(deviceId)) {
    deletionCollection = FirestoreCollection(
      path: deletionRegistryPath ?? 'deletionRegistry',
      mapper: FirestoreDeletionRegistryMapper(),
      firestore: firestore,
    );
  }

  late final FirestoreCollection<DeletionRegistry> deletionCollection;

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
  Future<bool> cleanRegistry() async {
    bool shouldInvalidateCache = false;
    final currentTime = await this.currentTime;
    devLog(
        'cleanRegistry: userId=$userId deviceId=$deviceId currentTime=$currentTime timeToLive=${offlineDeviceTtl.pretty()}');

    await sembastDb.transaction((sembastTransaction) async {
      await deletionCollection.firestore.runTransaction((firestoreTransaction) async {
        final docRef = deletionCollection.typedCollection.doc(userId);
        final registry = (await firestoreTransaction.get(docRef)).data() ?? DeletionRegistry(userId: userId);

        devLog('cleanRegistry: signing deletions on registry');
        final idsByCollection = registry.groupIdsByCollection();
        for (var collection in idsByCollection.entries) {
          final collectionId = collection.key;
          final docIds = collection.value;
          if (docIds.isNotEmpty) {
            final removedIds =
                (await semb.StoreRef(collectionId).records(docIds).delete(sembastTransaction)).whereNotNull();

            if (removedIds.isNotEmpty) {
              devLog(
                  '$debugDetails cleanRegistry: removed ${removedIds.length} documents from "$collectionId" cache: $removedIds');
            }
          }
        }
        registry.signDeletions(deviceId: deviceId, idsByCollection: idsByCollection);

        devLog('cleanRegistry: cleaning registry');
        shouldInvalidateCache = registry.cleanRegistry(
          deviceId: deviceId,
          currentTime: currentTime,
          timeToLive: offlineDeviceTtl,
        );

        devLog('cleanRegistry: submitting registry');
        firestoreTransaction.set(docRef, registry);
        return registry;
      });
    });

    return shouldInvalidateCache;
  }

  /// Sign the registry.
  /// It's OK to not sign in a transaction here because if the cache is deleted here
  /// and the we fail to write the registry we will simply try to clear the cache again.
  /// So for example, if we deleted 10 items, and we fail to sign, the 10 items are still
  /// pending deletion, so the next time we try to delete, we will try to delete the same 10 items
  /// from cache (even if it doesn't exist in cache).
  @override
  Future<void> signDeletions(Map<String, Set<String>> idsQueuedForDeletion) async {
    if (idsQueuedForDeletion.isEmpty) {
      devLog('$debugDetails signDeletions: nothing to sign, exiting...');
      return;
    }

    await sembastDb.transaction((sembastTransaction) async {
      final Map<String, dynamic> registryUpdate = {};
      for (var collection in idsQueuedForDeletion.entries) {
        final collectionId = collection.key;
        final docIds = collection.value;
        if (docIds.isNotEmpty) {
          final removedIds =
              (await semb.StoreRef(collectionId).records(docIds).delete(sembastTransaction)).whereNotNull();

          registryUpdate.addAll({
            'deletions.$deviceId.$collectionId': fs.FieldValue.arrayUnion(docIds.toList()),
          });

          if (removedIds.isNotEmpty) {
            devLog(
                '$debugDetails signDeletions: removed ${removedIds.length} documents from "$collectionId" cache: $removedIds');
          }
        }
      }

      await deletionCollection.typedCollection.doc(userId).update(registryUpdate);
    });
  }

  @override
  Future<DeletionRegistry> getOrSetRegistry() async {
    final doc = deletionCollection.typedCollection.doc(userId);
    DeletionRegistry? registry = (await doc.get()).data();
    if (registry == null) {
      registry = DeletionRegistry(userId: userId);
      await doc.set(registry);
    }
    devLog('$debugDetails getRegistry: registry=$registry');
    return registry;
  }

  Completer<bool> _localDbCompleter = Completer();
  Future<bool> get localDbIsReady => _localDbCompleter.future;

  @override
  Future<semb.Database?> openLocalDb(String userId) async {
    if (userId.isEmpty) {
      return throw Exception('To open a user database, userId must not be empty');
    }
    _localDbCompleter = Completer();

    // get the application documents directory
    final dir = await getApplicationDocumentsDirectory();
    await dir.create(recursive: true);
    final dbPath = join(dir.path, '$userId.db');
    _sembastDb = await databaseFactoryIo.openDatabase(dbPath);
    _localDbCompleter.complete(true);
    return _sembastDb;
  }

  @override
  Future<void> closeLocalDb() async {
    await _sembastDb.close();
  }

  @override
  Future<void> deleteLocalDb() async {
    await _sembastDb.close();
    await databaseFactoryIo.deleteDatabase(_sembastDb.path);
  }
}
