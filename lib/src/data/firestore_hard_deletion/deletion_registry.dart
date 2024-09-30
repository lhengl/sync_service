part of 'firestore_hard_deletion.dart';

class FirestoreDeletionRegistryMapper extends JsonMapper<DeletionRegistry> {
  @override
  DeletionRegistry fromMap(Map<String, dynamic> map) {
    return DeletionRegistry.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(DeletionRegistry value) {
    return value.toMap();
  }
}

/// This registry is stored per collection
/// This is important to reconcile the sync state during an extended offline period.
@MappableClass()
class DeletionRegistry with DeletionRegistryMappable {
  final String userId;

  String? lastDeviceId;

  /// A map of device and their last sync time in the form of
  /// {deviceId:lastSyncedAt}
  final Map<String, DateTime> deviceLastSynced;

  /// A map of deletion registry grouped by device in the form of
  /// { deviceId : { collectionId : List<documentId>}}
  /// The existence of a deviceId.collectionId.documentId indicates that the device has deleted the record
  final Map<String, Map<String, Set<String>>> deletions;

  @MappableConstructor()
  DeletionRegistry({
    required this.userId,
    Map<String, DateTime>? deviceLastSynced,
    Map<String, Map<String, Set<String>>>? deletions,
    this.lastDeviceId,
  })  : deviceLastSynced = deviceLastSynced ?? {},
        deletions = deletions ?? {} {
    _invertDeletions();
  }

  DeletionRegistry.required({
    required this.userId,
    required this.deviceLastSynced,
    required this.lastDeviceId,
    required this.deletions,
  }) {
    _invertDeletions();
  }

  /// A map of deletion registry grouped by collection, in the form of
  /// { collectionId : { documentId : List<deviceId>}}
  /// This is used during clean up to confirm that all devices have deleted the record
  final Map<String, Map<String, Set<String>>> deletionsByCollection = {};

  /// Inverts the collection into {collectionId : { docId : List<deviceIds> }}
  /// and store it in inverted
  void _invertDeletions() {
    deletions.forEach((deviceId, collections) {
      collections.forEach((collectionId, docIds) {
        for (var docId in docIds) {
          ((deletionsByCollection[collectionId] ??= {})[docId] ??= {}).add(deviceId);
        }
      });
    });
  }

  factory DeletionRegistry.fromJson(String json) => DeletionRegistryMapper.fromJson(json);
  factory DeletionRegistry.fromMap(Map<String, dynamic> map) => DeletionRegistryMapper.fromMap(map);

  /// When starting up sync, the sync service will look up the registry to check if deletion has been signed
  /// by all devices. If all signed, then the deletion can be removed.
  ///
  /// EXTENDED OFFLINE DEVICES
  /// An offline device will stall the clean up process. For example, if a device goes offline permanently,
  /// then it will never sign a deletion. So the deletion cannot be removed forever.
  /// To circumvent this, when a device is offline for an extended period, it will be forcibly removed
  /// from the signing process. The next time the device comes back online, it needs to do a complete resync.
  ///
  /// Returns a flag to let the cleaner know whether to invalidate its cache
  void cleanRegistry({
    required String deviceId,
    required DateTime currentTime,
    required Duration timeToLive,
  }) {
    final expirationTime = currentTime.subtract(timeToLive);
    // remove any device that has expired, except if its the last one synced, since if it was the last one synced
    // it doesn't matter how long its been offline, it is guaranteed to be in sync
    deviceLastSynced.removeWhere((_, lastSyncedAt) {
      return deviceId != lastDeviceId && lastSyncedAt.isBefore(expirationTime);
    });

    // For each doc id, remove it if it has been deleted by all devices
    final allDeviceIds = getAllDeviceIds();
    deletionsByCollection.forEach((collectionId, doc) {
      doc.forEach((docId, signedDeviceIds) {
        // devLog(
        //     'docId=$docId signedDeviceIds=$signedDeviceIds allDeviceIds=$allDeviceIds deviceIds.containsAll(allDeviceIds) = ${signedDeviceIds.containsAll(allDeviceIds)}');
        if (signedDeviceIds.containsAll(allDeviceIds)) {
          // remove all occurrences of collectionId/docId
          for (var deletion in deletions.values) {
            deletion[collectionId]?.remove(docId);
          }
        }
      });
    });

    // update the inverted deletions after the clean
    _invertDeletions();

    // set last sync to this device and current time
    deviceLastSynced[deviceId] = currentTime;
    lastDeviceId = deviceId;
  }

  /// The inverse of cacheIsInvalid
  bool cacheIsValid(String deviceId) {
    // if lastSynced was removed then the cleaner should invalidate cache
    return deviceLastSynced[deviceId] != null;
  }

  /// Returns true if device cache is invalid - requiring a resync
  /// Returns false if device cache is valid
  bool cacheIsInvalid(String deviceId) {
    return deviceLastSynced[deviceId] == null;
  }

  DateTime? getLastSyncedAt({required String deviceId}) {
    return deviceLastSynced[deviceId];
  }

  Set<String> getAllDeviceIds() {
    return deviceLastSynced.keys.toSet();
  }

  /// Check whether a deletion has been signed
  bool isSigned({
    required String deviceId,
    required String collectionId,
    required String docId,
  }) {
    return deletions[deviceId]?[collectionId]?.contains(docId) ?? false;
  }

  /// Check whether a set of docIds have been signed. If one test fails, all fails.
  bool areSigned({
    required String deviceId,
    required String collectionId,
    required Set<String> docIds,
  }) {
    for (var docId in docIds) {
      if (!isSigned(deviceId: deviceId, collectionId: collectionId, docId: docId)) {
        return false;
      }
    }
    return true;
  }

  /// Check that all devices have signed a deletion
  bool isSignedByAllDevices({
    required String collectionId,
    required String docId,
  }) {
    final allDeviceIds = getAllDeviceIds();
    final signedDeviceIds = deletionsByCollection[collectionId]?[docId] ?? {};
    return signedDeviceIds.containsAll(allDeviceIds);
  }

  /// Check that all devices have signed a set of deletions. If one test fails, all fails.
  bool areSignedByAllDevices({
    required String collectionId,
    required Set<String> docIds,
  }) {
    for (var docId in docIds) {
      if (!isSignedByAllDevices(collectionId: collectionId, docId: docId)) {
        return false;
      }
    }
    return true;
  }

  /// Return true if a docId exist on any device
  bool idExists({
    required String collectionId,
    required String docId,
  }) {
    return deletionsByCollection[collectionId]?[docId]?.isNotEmpty ?? false;
  }

  /// Return true if a all docIds exist on any device. If one test fails, all fails.
  bool idsExist({
    required String collectionId,
    required Set<String> docIds,
  }) {
    for (var docId in docIds) {
      if (!idExists(collectionId: collectionId, docId: docId)) {
        return false;
      }
    }
    return true;
  }

  Map<String, Set<String>> groupIdsByCollection() {
    final Map<String, Set<String>> idsByCollection = {};
    deletions.forEach((deviceId, collections) {
      collections.forEach((collectionId, docIds) {
        (idsByCollection[collectionId] ??= {}).addAll(docIds);
      });
    });
    return idsByCollection;
  }

  /// sign all ids for the a device
  void signDeletions({
    required String deviceId,
    required Map<String, Set<String>> idsByCollection,
  }) {
    for (var entries in idsByCollection.entries) {
      final collectionId = entries.key;
      final docIds = entries.value;
      ((deletions[deviceId] ??= {})[collectionId] ??= {}).addAll(docIds);
    }

    // ensure to invert the deletions as well
    _invertDeletions();
  }

  /// Returns true if no ids are registered
  bool isClean() {
    for (var docIds in deletionsByCollection.values) {
      if (docIds.isNotEmpty) {
        return false;
      }
    }
    return true;
  }
}
