/// A class for managing local database
abstract class DatabaseProvider<T> {
  /// Returns the current db, throws if null
  T get db;

  Future<T> openDatabase({required String userId});

  Future<void> closeDatabase();

  Future<void> deleteDatabase();
}
