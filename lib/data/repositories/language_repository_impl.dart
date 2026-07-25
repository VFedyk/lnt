import 'package:uuid/uuid.dart';
import '../../domain/entities/language.dart';
import '../../domain/repositories/language_repository.dart';
import 'base_repository.dart';

const _uuid = Uuid();

class LanguageRepositoryImpl extends BaseRepository
    implements LanguageRepository {
  LanguageRepositoryImpl(super.getDatabase, {super.onChange});

  /// Last-write timestamp stamped on every mutation, so sync can order edits.
  static String _nowIso() => DateTime.now().toUtc().toIso8601String();

  @override
  Future<String> create(Language language) async {
    final db = await getDatabase();
    final id = language.id ?? _uuid.v4();
    await db.insert(
        'languages', language.copyWith(id: id).toMap()..['updated_at'] = _nowIso());
    notifyChange();
    return id;
  }

  @override
  Future<List<Language>> getAll() async {
    final db = await getDatabase();
    final maps = await db.query('languages', orderBy: 'name ASC');
    return maps.map((map) => Language.fromMap(map)).toList();
  }

  @override
  Future<Language?> getById(String id) async {
    final db = await getDatabase();
    final maps = await db.query('languages', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Language.fromMap(maps.first);
  }

  @override
  Future<int> update(Language language) async {
    final db = await getDatabase();
    final result = await db.update(
      'languages',
      language.toMap()..['updated_at'] = _nowIso(),
      where: 'id = ?',
      whereArgs: [language.id],
    );
    notifyChange();
    return result;
  }

  @override
  Future<int> delete(String id) async {
    final db = await getDatabase();
    final result = await db.delete('languages', where: 'id = ?', whereArgs: [id]);
    if (result > 0) await BaseRepository.recordTombstone(db, 'language', id);
    notifyChange();
    return result;
  }
}
