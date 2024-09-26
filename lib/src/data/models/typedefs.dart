import 'package:cloud_firestore/cloud_firestore.dart';

typedef FirestoreSyncQuery = Query<JsonObject> Function(CollectionReference<JsonObject> collection, String userId);

typedef JsonObject = Map<String, dynamic>;
