import 'package:cloud_firestore/cloud_firestore.dart';

typedef FirestoreUserQuery<T> = Query<T> Function(CollectionReference<T> collection, String userId);

typedef JsonObject = Map<String, dynamic>;
