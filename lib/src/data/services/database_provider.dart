import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';

/// A class for managing local database
class DatabaseProvider {
  Database? _sembastDb;

  /// Returns the current db, throws if null
  Database get sembastDb {
    return _sembastDb!;
  }

  Future<Database> getOrOpenLocalDatabase({
    required String userId,
    required String deviceId,
  }) async {
    var sembastDb = _sembastDb;
    if (sembastDb != null) {
      return sembastDb;
    }

    if (userId.isEmpty || deviceId.isEmpty) {
      throw Exception('To open a local database, userId and deviceId must not be empty');
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      await dir.create(recursive: true);
      final dbPath = join(dir.path, '${deviceId}_$userId.db');
      sembastDb = _sembastDb = await databaseFactoryIo.openDatabase(dbPath);
      return sembastDb;
    } catch (e) {
      throw Exception('Error opening database: $e');
    }
  }

  Future<void> closeLocalDatabase() async {
    await _sembastDb?.close();
  }

  Future<void> deleteLocalDatabase() async {
    await _sembastDb?.close();
    if (_sembastDb != null) {
      await databaseFactoryIo.deleteDatabase(_sembastDb!.path);
    }
  }
}

class FakeDatabaseProvider extends DatabaseProvider {
  late Database _mockDb;

  @override
  Database get sembastDb => _mockDb;
  @override
  Future<Database> getOrOpenLocalDatabase({
    String? userId,
    String? deviceId,
  }) async {
    _mockDb = await newDatabaseFactoryMemory().openDatabase('${deviceId}_$userId.db');
    return _mockDb;
  }
}
