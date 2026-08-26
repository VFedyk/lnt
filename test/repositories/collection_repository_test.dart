import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/data/datasources/database_migrations.dart'
    as migrations;
import 'package:language_nerd_tools/data/repositories/collection_repository_impl.dart';
import 'package:language_nerd_tools/domain/entities/collection.dart';
import 'package:language_nerd_tools/domain/entities/text_document.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> _openTestDb() async {
  return await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: migrations.databaseVersion,
      onCreate: migrations.onCreate,
      onUpgrade: migrations.onUpgrade,
    ),
  );
}

Future<void> _insertLanguage(Database db, String id) async {
  await db.insert('languages', {'id': id, 'name': id});
}

/// Inserts a text directly (bypassing TextRepository) so length/status/last_read
/// can be controlled precisely for progress-weighting assertions.
Future<void> _insertText(
  Database db, {
  required String id,
  required String collectionId,
  required String languageId,
  required int contentLength,
  TextStatus status = TextStatus.pending,
  DateTime? lastRead,
  int sortOrder = 0,
  String title = 't',
}) async {
  final now = (lastRead ?? DateTime.now()).toUtc().toIso8601String();
  await db.insert('texts', {
    'id': id,
    'language_id': languageId,
    'collection_id': collectionId,
    'title': title,
    'content': 'x' * contentLength,
    'created_at': now,
    'last_read': now,
    'status': status.value,
    'sort_order': sortOrder,
  });
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late CollectionRepositoryImpl repo;

  setUp(() async {
    db = await _openTestDb();
    repo = CollectionRepositoryImpl(() async => db);
    await _insertLanguage(db, 'lang-1');
    await _insertLanguage(db, 'lang-2');
  });

  tearDown(() async {
    await db.close();
  });

  group('isContinuous persistence', () {
    test('survives create -> getById round-trip', () async {
      final id = await repo.create(Collection(
        languageId: 'lang-1',
        name: 'Book',
        isContinuous: true,
      ));

      final loaded = await repo.getById(id);
      expect(loaded!.isContinuous, isTrue);
    });

    test('defaults to false when not set', () async {
      final id = await repo.create(Collection(languageId: 'lang-1', name: 'Folder'));

      final loaded = await repo.getById(id);
      expect(loaded!.isContinuous, isFalse);
    });

    test('update can flip it both ways', () async {
      final id = await repo.create(
        Collection(languageId: 'lang-1', name: 'Book', isContinuous: false),
      );

      var loaded = await repo.getById(id);
      await repo.update(loaded!.copyWith(isContinuous: true));
      loaded = await repo.getById(id);
      expect(loaded!.isContinuous, isTrue);

      await repo.update(loaded.copyWith(isContinuous: false));
      loaded = await repo.getById(id);
      expect(loaded!.isContinuous, isFalse);
    });
  });

  group('getBookProgress', () {
    test('weights by text length, not chapter count', () async {
      final id = await repo.create(
        Collection(languageId: 'lang-1', name: 'Book', isContinuous: true),
      );
      // Finished 100-char chapter + unfinished 900-char chapter -> 10%, not 50%.
      await _insertText(db,
          id: 't1', collectionId: id, languageId: 'lang-1',
          contentLength: 100, status: TextStatus.finished);
      await _insertText(db,
          id: 't2', collectionId: id, languageId: 'lang-1',
          contentLength: 900, status: TextStatus.pending);

      final progress = await repo.getBookProgress('lang-1');
      expect(progress, hasLength(1));
      expect(progress.first.percent, 10);
      expect(progress.first.fraction, closeTo(0.1, 0.0001));
    });

    test('excludeCompleted: true drops a fully-finished book, keeps a 0% one', () async {
      final finishedId = await repo.create(
        Collection(languageId: 'lang-1', name: 'Finished', isContinuous: true),
      );
      await _insertText(db,
          id: 't1', collectionId: finishedId, languageId: 'lang-1',
          contentLength: 100, status: TextStatus.finished);

      final freshId = await repo.create(
        Collection(languageId: 'lang-1', name: 'Fresh', isContinuous: true),
      );
      await _insertText(db,
          id: 't2', collectionId: freshId, languageId: 'lang-1',
          contentLength: 100, status: TextStatus.pending);

      final progress = await repo.getBookProgress('lang-1', excludeCompleted: true);
      expect(progress.map((p) => p.collectionId), [freshId]);
    });

    test('excludeCompleted: false returns the finished book', () async {
      final finishedId = await repo.create(
        Collection(languageId: 'lang-1', name: 'Finished', isContinuous: true),
      );
      await _insertText(db,
          id: 't1', collectionId: finishedId, languageId: 'lang-1',
          contentLength: 100, status: TextStatus.finished);

      final progress = await repo.getBookProgress('lang-1', excludeCompleted: false);
      expect(progress.map((p) => p.collectionId), contains(finishedId));
      expect(progress.firstWhere((p) => p.collectionId == finishedId).isComplete, isTrue);
    });

    test('collections with is_continuous = 0 never appear', () async {
      final id = await repo.create(
        Collection(languageId: 'lang-1', name: 'Plain', isContinuous: false),
      );
      await _insertText(db,
          id: 't1', collectionId: id, languageId: 'lang-1', contentLength: 100);

      final progress = await repo.getBookProgress('lang-1');
      expect(progress, isEmpty);
    });

    test('a continuous collection with no texts is absent', () async {
      await repo.create(
        Collection(languageId: 'lang-1', name: 'Empty', isContinuous: true),
      );

      final progress = await repo.getBookProgress('lang-1');
      expect(progress, isEmpty);
    });

    test('ordering is by MAX(last_read) DESC, and limit truncates after ordering', () async {
      final oldId = await repo.create(
        Collection(languageId: 'lang-1', name: 'Old', isContinuous: true),
      );
      await _insertText(db,
          id: 't-old', collectionId: oldId, languageId: 'lang-1',
          contentLength: 100, lastRead: DateTime(2024, 1, 1));

      final newId = await repo.create(
        Collection(languageId: 'lang-1', name: 'New', isContinuous: true),
      );
      await _insertText(db,
          id: 't-new', collectionId: newId, languageId: 'lang-1',
          contentLength: 100, lastRead: DateTime(2025, 1, 1));

      final midId = await repo.create(
        Collection(languageId: 'lang-1', name: 'Mid', isContinuous: true),
      );
      await _insertText(db,
          id: 't-mid', collectionId: midId, languageId: 'lang-1',
          contentLength: 100, lastRead: DateTime(2024, 6, 1));

      final all = await repo.getBookProgress('lang-1');
      expect(all.map((p) => p.collectionId), [newId, midId, oldId]);

      final limited = await repo.getBookProgress('lang-1', limit: 2);
      expect(limited.map((p) => p.collectionId), [newId, midId]);
    });

    test('only the requested languageId is returned', () async {
      final id1 = await repo.create(
        Collection(languageId: 'lang-1', name: 'One', isContinuous: true),
      );
      await _insertText(db,
          id: 't1', collectionId: id1, languageId: 'lang-1', contentLength: 100);

      final id2 = await repo.create(
        Collection(languageId: 'lang-2', name: 'Two', isContinuous: true),
      );
      await _insertText(db,
          id: 't2', collectionId: id2, languageId: 'lang-2', contentLength: 100);

      final progress = await repo.getBookProgress('lang-1');
      expect(progress.map((p) => p.collectionId), [id1]);
    });
  });

  group('getNextUnfinishedText', () {
    test('returns the lowest sort_order unfinished chapter, skipping finished ones',
        () async {
      final id = await repo.create(
        Collection(languageId: 'lang-1', name: 'Book', isContinuous: true),
      );
      await _insertText(db,
          id: 't1', collectionId: id, languageId: 'lang-1',
          contentLength: 10, status: TextStatus.finished, sortOrder: 0);
      await _insertText(db,
          id: 't2', collectionId: id, languageId: 'lang-1',
          contentLength: 10, status: TextStatus.pending, sortOrder: 1);
      await _insertText(db,
          id: 't3', collectionId: id, languageId: 'lang-1',
          contentLength: 10, status: TextStatus.pending, sortOrder: 2);

      final next = await repo.getNextUnfinishedText(id);
      expect(next!.id, 't2');
    });

    test('returns the first chapter when all are finished', () async {
      final id = await repo.create(
        Collection(languageId: 'lang-1', name: 'Book', isContinuous: true),
      );
      await _insertText(db,
          id: 't1', collectionId: id, languageId: 'lang-1',
          contentLength: 10, status: TextStatus.finished, sortOrder: 0);
      await _insertText(db,
          id: 't2', collectionId: id, languageId: 'lang-1',
          contentLength: 10, status: TextStatus.finished, sortOrder: 1);

      final next = await repo.getNextUnfinishedText(id);
      expect(next!.id, 't1');
    });

    test('returns null for an empty collection', () async {
      final id = await repo.create(
        Collection(languageId: 'lang-1', name: 'Empty', isContinuous: true),
      );

      final next = await repo.getNextUnfinishedText(id);
      expect(next, isNull);
    });
  });
}
