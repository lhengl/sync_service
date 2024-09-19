import 'package:cloud_firestore/cloud_firestore.dart';

extension FirestoreQuerySnapshotExtension<T> on QuerySnapshot<T> {
  /// A convenient method to return the document data
  List<T> get data => docs.map((doc) => doc.data()).toList();

  /// A convenient method to return all document ids
  List<String> get ids => docs.map((doc) => doc.reference.id).toList();
}

extension FirestoreQueryStreamExtension<T> on Stream<QuerySnapshot<T>> {
  /// A convenient method to return the document data from a stream
  Stream<List<T>> get data => map((querySnapshot) => querySnapshot.data);
}

extension FirestoreQueryExtension<T extends Object?> on Query<T> {
  /// Attempts to get a snapshot from cache first. If at least one object is found in cache
  Future<QuerySnapshot<T>> getCacheOrRemote() async {
    final snapshot = await get(const GetOptions(source: Source.cache));
    if (snapshot.docs.isEmpty) {
      return get();
    }
    return snapshot;
  }
}

extension FirestoreTimestampExtension on Timestamp {
  String toPrettyString() {
    return '${toDate().toString().split('.')[0]}.$nanoseconds';
  }
}
