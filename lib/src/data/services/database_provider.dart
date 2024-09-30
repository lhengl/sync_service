import 'dart:async';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';

import '../../application/services/database_provider.dart';

class SembastDatabaseProvider extends DatabaseProvider<Database> {
  Database? _db;

  /// Returns the current db, throws if null
  @override
  Database get db {
    return _db!;
  }

  @override
  Future<Database> openDatabase({
    required String userId,
  }) async {
    if (userId.isEmpty) {
      throw Exception('To open a local database, userId and deviceId must not be empty');
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      await dir.create(recursive: true);
      final dbPath = join(dir.path, '$userId.db');
      final oldDb = _db;
      // if old database is the same path, return it
      if (oldDb != null && oldDb.path == dbPath) {
        return oldDb;
      }
      // otherwise, close and open a new one
      await oldDb?.close();
      return _db = await databaseFactoryIo.openDatabase(dbPath);
    } catch (e) {
      throw Exception('Error opening database: $e');
    }
  }

  @override
  Future<void> closeDatabase() async {
    await _db?.close();
  }

  @override
  Future<void> deleteDatabase() async {
    await _db?.close();
    if (_db != null) {
      await databaseFactoryIo.deleteDatabase(_db!.path);
    }
  }
}

class FakeDatabaseProvider extends DatabaseProvider {
  Database? _mockDb;

  @override
  Database get db => _mockDb!;
  @override
  Future<Database> openDatabase({
    String? userId,
  }) async {
    _mockDb = await newDatabaseFactoryMemory().openDatabase('$userId.db');
    return _mockDb!;
  }

  @override
  Future<void> closeDatabase() async {
    await _mockDb?.close();
  }

  @override
  Future<void> deleteDatabase() async {
    await _mockDb?.close();
    _mockDb = null;
  }
}
