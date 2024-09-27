import 'package:cloud_firestore/cloud_firestore.dart';

typedef FirestoreSyncQuery<T> = Query<T> Function(CollectionReference<T> collection, String userId);

typedef JsonObject = Map<String, dynamic>;
