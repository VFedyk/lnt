import '../../domain/entities/radical_progress.dart';
import '../../domain/repositories/radical_progress_repository.dart';
import 'base_repository.dart';

class RadicalProgressRepositoryImpl extends BaseRepository
    implements RadicalProgressRepository {
  RadicalProgressRepositoryImpl(super.getDatabase, {super.onChange});

  @override
  Future<Map<String, RadicalProgress>> getAll() async {
    final db = await getDatabase();
    final rows = await db.query('radical_progress');
    return {
      for (final r in rows)
        r['radical_char'] as String: RadicalProgress(
          radicalChar: r['radical_char'] as String,
          practicedCount: r['practiced_count'] as int,
          lastPracticed: r['last_practiced'] != null
              ? DateTime.parse(r['last_practiced'] as String).toLocal()
              : null,
        ),
    };
  }

  @override
  Future<void> recordCompletion(String radicalChar) async {
    final db = await getDatabase();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.rawInsert('''
      INSERT INTO radical_progress (radical_char, practiced_count, last_practiced)
      VALUES (?, 1, ?)
      ON CONFLICT(radical_char) DO UPDATE SET
        practiced_count = practiced_count + 1,
        last_practiced = excluded.last_practiced
    ''', [radicalChar, now]);
    notifyChange();
  }
}
