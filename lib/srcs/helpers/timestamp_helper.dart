import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:dart_mappable/dart_mappable.dart';
import 'package:sembast/timestamp.dart' as semb;

/// A class that helps to convert json data to variable timestamps
class TimestampHelper {
  /// Convert all timestamps to Sembast timestamps
  Map<String, dynamic> toSymbastTimestamps(Map<String, dynamic> data) {
    Map<String, dynamic> clonedData = {};
    data.forEach((key, value) {
      if (value is String) {
        final date = DateTime.tryParse(value);
        if (date != null) {
          clonedData[key] = semb.Timestamp.fromDateTime(date);
        } else {
          clonedData[key] = value;
        }
      } else if (value is DateTime) {
        clonedData[key] = semb.Timestamp.fromDateTime(value);
      } else if (value is fs.Timestamp) {
        clonedData[key] = semb.Timestamp(value.seconds, value.nanoseconds);
      } else if (value is Map<String, dynamic>) {
        clonedData[key] = toSymbastTimestamps(value);
      } else if (value is List) {
        clonedData[key] = [];
        for (int i = 0; i < value.length; i++) {
          if (value[i] is Map<String, dynamic>) {
            clonedData[key].add(toSymbastTimestamps(value[i]));
          } else {
            clonedData[key].add(value[i]);
          }
        }
      } else {
        clonedData[key] = value;
      }
    });
    return clonedData;
  }

  /// Convert all timestamps to Firestore timestamps
  Map<String, dynamic> toFirestoreTimestamps(Map<String, dynamic> data) {
    Map<String, dynamic> clonedData = {};
    data.forEach((key, value) {
      if (value is String) {
        final date = DateTime.tryParse(value);
        if (date != null) {
          clonedData[key] = fs.Timestamp.fromDate(date);
        } else {
          clonedData[key] = value;
        }
      } else if (value is DateTime) {
        clonedData[key] = fs.Timestamp.fromDate(value);
      } else if (value is semb.Timestamp) {
        clonedData[key] = fs.Timestamp(value.seconds, value.nanoseconds);
      } else if (value is Map<String, dynamic>) {
        clonedData[key] = toFirestoreTimestamps(value);
      } else if (value is List) {
        clonedData[key] = [];
        for (int i = 0; i < value.length; i++) {
          if (value[i] is Map<String, dynamic>) {
            clonedData[key].add(toFirestoreTimestamps(value[i]));
          } else {
            clonedData[key].add(value[i]);
          }
        }
      } else {
        clonedData[key] = value;
      }
    });
    return clonedData;
  }

  /// Convert all timestamps toIso8601String
  Map<String, dynamic> toIsoString(Map<String, dynamic> data) {
    Map<String, dynamic> clonedData = {};
    data.forEach((key, value) {
      if (value is semb.Timestamp) {
        clonedData[key] = value.toDateTime().toIso8601String();
      } else if (value is fs.Timestamp) {
        clonedData[key] = value.toDate().toIso8601String();
      } else if (value is Map<String, dynamic>) {
        clonedData[key] = toIsoString(value);
      } else if (value is List) {
        clonedData[key] = [];
        for (int i = 0; i < value.length; i++) {
          if (value[i] is Map<String, dynamic>) {
            clonedData[key].add(toIsoString(value[i]));
          } else {
            clonedData[key].add(value[i]);
          }
        }
      } else {
        clonedData[key] = value;
      }
    });
    return clonedData;
  }
}

extension SembastOnJsonMap on Map<String, dynamic> {
  Map<String, dynamic> toFirestoreTimestamps() {
    return TimestampHelper().toFirestoreTimestamps(this);
  }

  Map<String, dynamic> toSembastTimestamps() {
    return TimestampHelper().toSymbastTimestamps(this);
  }

  Map<String, dynamic> toIsoString() {
    return TimestampHelper().toIsoString(this);
  }
}

extension FirestoreOnJsonMap on Map<String, dynamic> {}

class FirestoreTimestampMapper extends SimpleMapper<DateTime> {
  const FirestoreTimestampMapper();

  @override
  DateTime decode(Object value) {
    return (value as fs.Timestamp).toDate();
  }

  @override
  fs.Timestamp encode(DateTime self) {
    return fs.Timestamp.fromDate(self);
  }
}

class SembastTimestampMapper extends SimpleMapper<DateTime> {
  const SembastTimestampMapper();

  @override
  DateTime decode(Object value) {
    return (value as semb.Timestamp).toDateTime();
  }

  @override
  semb.Timestamp encode(DateTime self) {
    return semb.Timestamp.fromDateTime(self);
  }
}
