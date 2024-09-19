import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter_kronos/flutter_kronos.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/timestamp.dart' as semb;
import 'package:sync_service/srcs/helpers/timestamp_helper.dart';

import 'firestore_helper.dart';
import 'loggable.dart';

mixin SembastHelper {
  String generateId() => fs.FirebaseFirestore.instance.collection('collection').doc().id;
  Future<DateTime> get utc async => await FlutterKronos.getNtpDateTime ?? DateTime.now().toUtc();
}

extension SembastTimestampExtension on semb.Timestamp {
  String toPrettyString() {
    return '${toDateTime().toString().split('.')[0]}.$nanoseconds';
  }
}

extension FirestoreOnSembastTimestamp on semb.Timestamp {
  /// Converts firestore time stamp to sembast directly so as to not lose nanosecond accuracy
  fs.Timestamp toFirestoreTimestamp() {
    return fs.Timestamp(seconds, nanoseconds);
  }
}

extension SembastOnFirestsoreTimestamp on fs.Timestamp {
  /// Converts firestore time stamp to sembast directly so as to not lose nanosecond accuracy
  semb.Timestamp toSembastTimestamp() {
    return semb.Timestamp(seconds, nanoseconds);
  }
}

class SembastCollection<T> with Loggable {
  final String path;

  /// keep private to force the use of conversion from the function that cleans the timestamps
  final JsonMapper<T> _mapper;

  /// A function that returns the database to be used for this collection
  final Database Function() getDb;

  SembastCollection({
    required this.getDb,
    required this.path,
    required JsonMapper<T> mapper,
  }) : _mapper = mapper;

  late final StoreRef<String, Map<String, dynamic>> store = StoreRef(path);

  Database get db {
    try {
      return getDb();
    } catch (e, s) {
      devLog(
        'Error retrieving database, did you remember to call SyncService.startSync?',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  T fromSembast(Map<String, dynamic> map) {
    return _mapper.fromMap(map.toIsoString());
  }

  Map<String, dynamic> toSembast(T value) {
    return _mapper.toMap(value).toSembastTimestamps();
  }

  T? fromSembastOrNull(Map<String, dynamic>? map) => map == null ? null : fromSembast(map);
  Map<String, dynamic>? toSembastOrNull(T? value) => value == null ? null : toSembast(value);
}
