import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_kronos/flutter_kronos.dart';
import 'package:sync_service/srcs/helpers/timestamp_helper.dart';

typedef GetFirestore = FirebaseFirestore Function();

mixin FirestoreHelper {
  Future<DateTime> get currentTime async => await FlutterKronos.getNtpDateTime ?? DateTime.now();

  /// Split values into batch of 10 size for queries that only support a limited number of value such as WhereIn
  List<List<T>> splitBatch<T>(Set<T> values, {int batchSize = 10}) {
    final List<List<T>> idBatches = [];
    for (var i = 0; i < values.length; i += batchSize) {
      idBatches.add(values.skip(i).take(batchSize).toList());
    }
    return idBatches;
  }

  // https://firebase.google.com/docs/firestore/quotas#limits
  // If dots are used in field names, then will break the mapping process during an update
  static String cleanFieldName(String fieldName) {
    fieldName = fieldName.replaceAll(RegExp(r'[^\w-]'), '_'); // Replace invalid characters

    // Ensure it doesn't start or end with double underscores
    if (fieldName.startsWith('__')) {
      fieldName = fieldName.substring(2);
    }
    if (fieldName.endsWith('__')) {
      fieldName = fieldName.substring(0, fieldName.length - 2);
    }

    return fieldName;
  }
}

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

abstract class JsonMapper<T> {
  T fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap(T value);
  T? fromMapNull(Map<String, dynamic>? map) => map == null ? null : fromMap(map);
  Map<String, dynamic>? toMapOrNull(T? value) => value == null ? null : toMap(value);
}

class FirestoreCollection<T> {
  /// A function that returns an instance to be used for this collection
  final FirebaseFirestore firestore;
  final String path;

  /// keep private to force the use of conversion from the function that cleans the timestamps
  final JsonMapper<T> _mapper;

  FirestoreCollection({
    required this.firestore,
    required this.path,
    required JsonMapper<T> mapper,
  }) : _mapper = mapper;

  late final CollectionReference collection = firestore.collection(path);
  late final CollectionReference<T> typedCollection = collection.withConverter(
    fromFirestore: (value, __) {
      return fromFirestore(value.data()!);
    },
    toFirestore: (value, __) {
      return toFirestore(value);
    },
  );

  T fromFirestore(Map<String, dynamic> map) {
    return _mapper.fromMap(map.toIsoString());
  }

  Map<String, dynamic> toFirestore(T value) {
    return _mapper.toMap(value).toFirestoreTimestamps();
  }

  T? fromFirestoreOrNull(Map<String, dynamic>? map) => map == null ? null : fromFirestore(map);
  Map<String, dynamic>? toFirestoreOrNull(T? value) => value == null ? null : toFirestore(value);
}
