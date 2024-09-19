abstract class JsonMapper<T> {
  T fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap(T value);
  T? fromMapOrNull(Map<String, dynamic>? map) => map == null ? null : fromMap(map);
  Map<String, dynamic>? toMapOrNull(T? value) => value == null ? null : toMap(value);

  const JsonMapper();
}

/// An implementation of the JSON mapper to instantiate rather than implement
/// Useful if you only need to instantiate it once.
/// However if you need to reuse the mapper, it's more convenient to implement the interface to pass it around
class JsonMapperImpl<T> extends JsonMapper<T> {
  final T Function(Map<String, dynamic> map) fromMapFunc;
  final Map<String, dynamic> Function(T) toMapFunc;

  const JsonMapperImpl({
    required this.fromMapFunc,
    required this.toMapFunc,
  });

  @override
  T fromMap(Map<String, dynamic> map) {
    return fromMapFunc(map);
  }

  @override
  Map<String, dynamic> toMap(T value) {
    return toMapFunc(value);
  }
}
