// class SembastCollection<T> with Loggable {
//   final String path;
//
//   /// keep private to force the use of conversion from the function that cleans the timestamps
//   final JsonMapper<T> _mapper;
//
//   SembastCollection({
//     required this.path,
//     required JsonMapper<T> mapper,
//   }) : _mapper = mapper;
//
//   late final StoreRef<String, Map<String, dynamic>> store = StoreRef(path);
//
//   T fromSembast(Map<String, dynamic> map) {
//     return _mapper.fromMap(map.toIsoString());
//   }
//
//   Map<String, dynamic> toSembast(T value) {
//     return _mapper.toMap(value).toSembastTimestamps();
//   }
//
//   T? fromSembastOrNull(Map<String, dynamic>? map) => map == null ? null : fromSembast(map);
//   Map<String, dynamic>? toSembastOrNull(T? value) => value == null ? null : toSembast(value);
// }
