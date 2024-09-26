import 'package:collection/collection.dart';

import 'typedefs.dart';

class FirestoreCollectionInfo {
  final String path;
  String get trashPath => '${path}_trash';
  final String idField;

  /// The field name that stores updated timestamp. Defaults to "updatedAt".
  /// Override if this is different in the collection.
  final String updateField;
  final String createField;

  late final FirestoreSyncQuery syncQuery;

  FirestoreCollectionInfo({
    required this.path,
    this.idField = 'id',
    this.updateField = 'updatedAt',
    this.createField = 'createdAt',
    required this.syncQuery,
  });
}

/// A provider for collection infos to be used by other classes
/// This ensures that there is a single source of truth for collection infos
/// Otherwise it might be easy to make mistakes when providing collection info to different classes
class CollectionProvider {
  /// A map of all collection by collection path
  final Map<String, FirestoreCollectionInfo> _collectionMap;

  CollectionProvider({
    required List<FirestoreCollectionInfo> collections,
  }) : _collectionMap = collections.lastBy((e) => e.path);

  Map<String, FirestoreCollectionInfo> get collectionMap => {..._collectionMap};

  List<FirestoreCollectionInfo> get collections => _collectionMap.values.toList();

  T? get<T extends FirestoreCollectionInfo>(String path) {
    final info = _collectionMap[path];
    if (info is T) {
      return info;
    }
    return null;
  }

  void register(FirestoreCollectionInfo collectionInfo) {
    _collectionMap[collectionInfo.path] = collectionInfo;
  }

  void remove(String path) {
    _collectionMap.remove(path);
  }
}
