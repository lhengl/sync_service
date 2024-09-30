part of 'firestore_soft_deletion.dart';

mixin FirestoreTrashMixin on Loggable {
  Future<DateTime> get currentTime;
  Duration get disposalAge;
  fs.FirebaseFirestore get firestore;
  String get trashRegistryPath;
  final FirestoreDisposalRegistryMapper _registryMapper = FirestoreDisposalRegistryMapper();
  late final fs.CollectionReference<JsonObject> registryCollection = firestore.collection(trashRegistryPath);
  late final fs.CollectionReference<TrashRegistry> registryTypedCollection = registryCollection.withConverter(
    fromFirestore: (value, __) {
      return _registryMapper.fromMap(value.data()!);
    },
    toFirestore: (value, __) {
      return _registryMapper.toMap(value);
    },
  );

  Future<DateTime> signRegistry({required String userId, required String deviceId}) async {
    final registry = await getOrSetRegistry(userId: userId);
    final currentCutoff = registry.disposalCutoff;
    final now = await currentTime;
    var newCutoff = calculateDisposalCutoff(now);
    // new cut off cannot be before current cutoff
    if (newCutoff.isBefore(currentCutoff)) {
      newCutoff = currentCutoff;
      // throw StateError('New cutoff ($newCutoff) cannot be before current cutoff ($currentCutoff)');
    }

    // before we do anything, sign the disposal to move the cutoff forward
    final update = {
      TrashRegistry.lastDisposedByDeviceIdField: deviceId,
      TrashRegistry.disposalCutoffField: newCutoff.toIso8601String(),
      '${TrashRegistry.deviceLastDisposalField}.$deviceId': now.toIso8601String(),
    };
    // devLog('disposeOldTrash: registering disposal attempt: $update');
    // ensure to use the same collection for updates to trigger collection listeners
    // There was a bug where if we update using a normal collection, that the watchRegistry stream does
    // not get triggered because it was expecting to listen to a typedCollection
    await registryTypedCollection.doc(userId).update(update);
    return newCutoff;
  }

  /// Returns the disposal registry for the user, if empty set it first before returning it.
  Future<TrashRegistry> getOrSetRegistry({required String userId}) async {
    devLog('getOrSetRegistry: userId=$userId');
    final doc = registryTypedCollection.doc(userId);
    TrashRegistry? registry = (await doc.get()).data();
    if (registry == null) {
      registry = TrashRegistry(
        userId: userId,
        disposalCutoff: calculateDisposalCutoff(await currentTime),
      );
      await doc.set(registry);
      devLog('getOrSetRegistry: created new registry: $registry');
    }
    return registry;
  }

  DateTime calculateDisposalCutoff(DateTime currentTime) {
    return currentTime.subtract(disposalAge);
  }
}
