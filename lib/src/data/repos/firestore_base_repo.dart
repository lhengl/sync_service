// import 'package:cloud_firestore/cloud_firestore.dart';
//
// import '../../domain/entities/deletion_registry.dart';
// import '../models/firestore_collection.dart';
//
// mixin SignDeletionMixin {
//   FirestoreCollection<DeletionRegistry> get deletionCollection;
//   String get userId;
//   String get deviceId;
//   String get collectionPath;
//
//   /// A special method that signs a deletion in a registry.
//   /// This registry ensures that deletions are synced across multiple devices.
//   /// If you are deleting a document, use [delete], [deleteById], [batchDelete], [batchDeleteByIds], [deleteAll].
//   /// Doing so will sign the registry for deletion.
//   /// However, if you need to delete a record outside of these default methods, ensure to call [signDeletions]
//   /// as part of a batch operation. Otherwise the devices will go out of sync without notice.
//   /// [FirestoreSyncDelegate.watchRemoteChanges] will also sign the registry during a deletion,
//   /// but is only intended only for other devices not the same device. It does not guarantee atomicity.
//   ///
//   /// ----- SO DON'T FORGET to sign the registry on each deletion. ------
//   Future<void> signDeletions({
//     required Set<String> ids,
//     required WriteBatch batch,
//   }) async {
//     batch.update(deletionCollection.typedCollection.doc(userId), {
//       'deletions.$deviceId.$collectionPath': FieldValue.arrayUnion(ids.toList()),
//     });
//   }
// }
