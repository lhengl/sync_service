import 'package:cloud_firestore/cloud_firestore.dart';

typedef SyncQuery<T> = Query<T> Function(CollectionReference<T> collection, String userId);
