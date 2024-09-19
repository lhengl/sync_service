import 'dart:async';
import 'dart:developer' as developer;

mixin Loggable {
  void devLog(
    String message, {
    DateTime? time,
    int? sequenceNumber,
    int level = 0,
    String name = '',
    Zone? zone,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      devLOG(
        message,
        time: time,
        sequenceNumber: sequenceNumber,
        level: level,
        zone: zone,
        error: error,
        stackTrace: stackTrace,
        type: runtimeType,
      );

  static void devLOG(
    String message, {
    DateTime? time,
    int? sequenceNumber,
    int level = 0,
    String name = '',
    Zone? zone,
    Object? error,
    StackTrace? stackTrace,
    Type? type,
  }) {
    developer.log(
      message,
      time: time,
      sequenceNumber: sequenceNumber,
      level: level,
      name: type?.toString() ?? name,
      zone: zone,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
