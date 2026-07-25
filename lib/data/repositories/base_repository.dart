import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../notifiers/data_change_notifier.dart';

const _uuid = Uuid();

/// Base class for all repositories providing database access
abstract class BaseRepository {
  final Future<Database> Function() getDatabase;
  final DomainNotifier? onChange;

  BaseRepository(this.getDatabase, {this.onChange});

  /// Notify listeners that data in this domain changed.
  void notifyChange() => onChange?.notify();

  /// Escape LIKE wildcard characters (% and _) in user input.
  /// Use with `ESCAPE '\'` in the SQL query.
  static String escapeLike(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  /// Records a deletion so the next sync pushes it as a tombstone event and
  /// other devices remove the row instead of resurrecting it.
  /// Takes a [DatabaseExecutor] so it also works inside a transaction.
  static Future<void> recordTombstone(
    DatabaseExecutor db,
    String domain,
    String entityId,
  ) async {
    await db.insert(
      'sync_tombstones',
      {
        'domain': domain,
        'entity_id': entityId,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns the cover_images.id for [localPath], creating a row if needed.
  /// Returns null when [localPath] is null or empty.
  static Future<String?> getOrCreateCoverImageId(
    Database db,
    String? localPath,
  ) async {
    if (localPath == null || localPath.isEmpty) return null;
    final rows = await db.query(
      'cover_images',
      columns: ['id'],
      where: 'local_path = ?',
      whereArgs: [localPath],
    );
    if (rows.isNotEmpty) return rows.first['id'] as String;
    final id = _uuid.v4();
    await db.insert('cover_images', {
      'id': id,
      'local_path': localPath,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    return id;
  }
}
