import 'package:sqflite/sqflite.dart';

/// Base class for all repositories providing database access
abstract class BaseRepository {
  final Future<Database> Function() getDatabase;

  BaseRepository(this.getDatabase);
}
