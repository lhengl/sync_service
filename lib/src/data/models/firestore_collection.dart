// class FirestoreCollection<T> {
//   /// A function that returns an instance to be used for this collection
//   final FirebaseFirestore firestore;
//   final String path;
//
//   /// keep private to force the use of conversion from the function that cleans the timestamps
//   final JsonMapper<T> _mapper;
//
//   FirestoreCollection({
//     required this.firestore,
//     required this.path,
//     required JsonMapper<T> mapper,
//   }) : _mapper = mapper;
//
//   late final CollectionReference collection = firestore.collection(path);
//   late final CollectionReference<T> typedCollection = collection.withConverter(
//     fromFirestore: (value, __) {
//       return fromFirestore(value.data()!);
//     },
//     toFirestore: (value, __) {
//       return toFirestore(value);
//     },
//   );
//
//   T fromFirestore(Map<String, dynamic> map) {
//     return _mapper.fromMap(map.toIsoString());
//   }
//
//   Map<String, dynamic> toFirestore(T value) {
//     return _mapper.toMap(value).toFirestoreTimestamps();
//   }
//
//   T? fromFirestoreOrNull(Map<String, dynamic>? map) => map == null ? null : fromFirestore(map);
//   Map<String, dynamic>? toFirestoreOrNull(T? value) => value == null ? null : toFirestore(value);
// }
