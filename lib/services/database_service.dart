import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/language.dart';
import '../models/term.dart';
import '../models/text_document.dart';
import '../models/dictionary.dart';
import '../models/collection.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fltr.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add sort_order column to texts table for chapter ordering
      await db.execute(
        'ALTER TABLE texts ADD COLUMN sort_order INTEGER DEFAULT 0',
      );
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE languages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        right_to_left INTEGER DEFAULT 0,
        show_romanization INTEGER DEFAULT 0,
        split_by_character INTEGER DEFAULT 0,
        character_substitutions TEXT,
        regexp_word_characters TEXT,
        regexp_split_sentences TEXT,
        exceptions_split_sentences TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE texts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        language_id INTEGER NOT NULL,
        collection_id INTEGER,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        source_uri TEXT,
        created_at TEXT NOT NULL,
        last_read TEXT NOT NULL,
        position INTEGER DEFAULT 0,
        sort_order INTEGER DEFAULT 0,
        FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE,
        FOREIGN KEY (collection_id) REFERENCES collections (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE terms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        language_id INTEGER NOT NULL,
        text TEXT NOT NULL,
        lower_text TEXT NOT NULL,
        status INTEGER DEFAULT 1,
        translation TEXT,
        romanization TEXT,
        sentence TEXT,
        created_at TEXT NOT NULL,
        last_accessed TEXT NOT NULL,
        FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE,
        UNIQUE(language_id, lower_text)
      )
    ''');

    await db.execute('CREATE INDEX idx_terms_lower ON terms(lower_text)');
    await db.execute('CREATE INDEX idx_terms_language ON terms(language_id)');
    await db.execute('CREATE INDEX idx_texts_language ON texts(language_id)');

    await db.execute('''
      CREATE TABLE collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        language_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        parent_id INTEGER,
        created_at TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE,
        FOREIGN KEY (parent_id) REFERENCES collections (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_collections_language ON collections(language_id)',
    );
    await db.execute(
      'CREATE INDEX idx_collections_parent ON collections(parent_id)',
    );

    await db.execute('''
      CREATE TABLE dictionaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        language_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_dictionaries_language ON dictionaries(language_id)',
    );
  }

  // Language CRUD
  Future<int> createLanguage(Language language) async {
    final db = await database;
    return await db.insert('languages', language.toMap());
  }

  Future<List<Language>> getLanguages() async {
    final db = await database;
    final maps = await db.query('languages', orderBy: 'name ASC');
    return maps.map((map) => Language.fromMap(map)).toList();
  }

  Future<Language?> getLanguage(int id) async {
    final db = await database;
    final maps = await db.query('languages', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Language.fromMap(maps.first);
  }

  Future<int> updateLanguage(Language language) async {
    final db = await database;
    return await db.update(
      'languages',
      language.toMap(),
      where: 'id = ?',
      whereArgs: [language.id],
    );
  }

  Future<int> deleteLanguage(int id) async {
    final db = await database;
    return await db.delete('languages', where: 'id = ?', whereArgs: [id]);
  }

  // Text CRUD
  Future<int> createText(TextDocument text) async {
    final db = await database;
    return await db.insert('texts', text.toMap());
  }

  Future<List<TextDocument>> getTexts({int? languageId}) async {
    final db = await database;
    final maps = languageId != null
        ? await db.query(
            'texts',
            where: 'language_id = ?',
            whereArgs: [languageId],
            orderBy: 'last_read DESC',
          )
        : await db.query('texts', orderBy: 'last_read DESC');
    return maps.map((map) => TextDocument.fromMap(map)).toList();
  }

  Future<TextDocument?> getText(int id) async {
    final db = await database;
    final maps = await db.query('texts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return TextDocument.fromMap(maps.first);
  }

  Future<int> updateText(TextDocument text) async {
    final db = await database;
    return await db.update(
      'texts',
      text.toMap(),
      where: 'id = ?',
      whereArgs: [text.id],
    );
  }

  Future<int> deleteText(int id) async {
    final db = await database;
    return await db.delete('texts', where: 'id = ?', whereArgs: [id]);
  }

  // Term CRUD
  Future<int> createTerm(Term term) async {
    final db = await database;
    return await db.insert(
      'terms',
      term.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Term>> getTerms({int? languageId, int? status}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (languageId != null && status != null) {
      where = 'language_id = ? AND status = ?';
      whereArgs = [languageId, status];
    } else if (languageId != null) {
      where = 'language_id = ?';
      whereArgs = [languageId];
    } else if (status != null) {
      where = 'status = ?';
      whereArgs = [status];
    }

    final maps = await db.query(
      'terms',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'last_accessed DESC',
    );
    return maps.map((map) => Term.fromMap(map)).toList();
  }

  Future<Term?> getTermByText(int languageId, String text) async {
    final db = await database;
    final maps = await db.query(
      'terms',
      where: 'language_id = ? AND lower_text = ?',
      whereArgs: [languageId, text.toLowerCase()],
    );
    if (maps.isEmpty) return null;
    return Term.fromMap(maps.first);
  }

  Future<Map<String, Term>> getTermsMap(int languageId) async {
    final db = await database;
    final maps = await db.query(
      'terms',
      where: 'language_id = ?',
      whereArgs: [languageId],
    );
    return {
      for (var map in maps) (map['lower_text'] as String): Term.fromMap(map),
    };
  }

  Future<int> updateTerm(Term term) async {
    final db = await database;
    return await db.update(
      'terms',
      term.toMap(),
      where: 'id = ?',
      whereArgs: [term.id],
    );
  }

  Future<int> deleteTerm(int id) async {
    final db = await database;
    return await db.delete('terms', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTermsByLanguage(int languageId) async {
    final db = await database;
    return await db.delete(
      'terms',
      where: 'language_id = ?',
      whereArgs: [languageId],
    );
  }

  // Statistics
  Future<Map<int, int>> getTermCountsByStatus(int languageId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT status, COUNT(*) as count
      FROM terms
      WHERE language_id = ?
      GROUP BY status
    ''',
      [languageId],
    );

    return {for (var row in result) row['status'] as int: row['count'] as int};
  }

  Future<int> getTotalTermCount(int languageId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM terms
      WHERE language_id = ?
    ''',
      [languageId],
    );
    return result.first['count'] as int;
  }

  Future<int> getTotalTextCount(int languageId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM texts
      WHERE language_id = ?
    ''',
      [languageId],
    );
    return result.first['count'] as int;
  }

  // Bulk operations
  Future<void> bulkUpdateTermStatus(List<int> termIds, int newStatus) async {
    final db = await database;
    final batch = db.batch();
    for (final id in termIds) {
      batch.update(
        'terms',
        {
          'status': newStatus,
          'last_accessed': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  // Search
  Future<List<Term>> searchTerms(int languageId, String query) async {
    final db = await database;
    final maps = await db.query(
      'terms',
      where: 'language_id = ? AND (text LIKE ? OR translation LIKE ?)',
      whereArgs: [languageId, '%$query%', '%$query%'],
      orderBy: 'last_accessed DESC',
      limit: 100,
    );
    return maps.map((map) => Term.fromMap(map)).toList();
  }

  Future<List<TextDocument>> searchTexts(int languageId, String query) async {
    final db = await database;
    final maps = await db.query(
      'texts',
      where: 'language_id = ? AND (title LIKE ? OR content LIKE ?)',
      whereArgs: [languageId, '%$query%', '%$query%'],
      orderBy: 'last_read DESC',
      limit: 50,
    );
    return maps.map((map) => TextDocument.fromMap(map)).toList();
  }

  // Dictionary CRUD
  Future<int> createDictionary(Dictionary dictionary) async {
    final db = await database;
    return await db.insert('dictionaries', dictionary.toMap());
  }

  Future<List<Dictionary>> getDictionaries({
    int? languageId,
    bool activeOnly = false,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (languageId != null && activeOnly) {
      where = 'language_id = ? AND is_active = 1';
      whereArgs = [languageId];
    } else if (languageId != null) {
      where = 'language_id = ?';
      whereArgs = [languageId];
    } else if (activeOnly) {
      where = 'is_active = 1';
    }

    final maps = await db.query(
      'dictionaries',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'sort_order ASC, name ASC',
    );

    return maps.map((map) => Dictionary.fromMap(map)).toList();
  }

  Future<Dictionary?> getDictionary(int id) async {
    final db = await database;
    final maps = await db.query(
      'dictionaries',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Dictionary.fromMap(maps.first);
  }

  Future<int> updateDictionary(Dictionary dictionary) async {
    final db = await database;
    return await db.update(
      'dictionaries',
      dictionary.toMap(),
      where: 'id = ?',
      whereArgs: [dictionary.id],
    );
  }

  Future<int> deleteDictionary(int id) async {
    final db = await database;
    return await db.delete('dictionaries', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteDictionariesByLanguage(int languageId) async {
    final db = await database;
    return await db.delete(
      'dictionaries',
      where: 'language_id = ?',
      whereArgs: [languageId],
    );
  }

  // Reorder dictionaries
  Future<void> reorderDictionaries(List<Dictionary> dictionaries) async {
    final db = await database;
    final batch = db.batch();

    for (int i = 0; i < dictionaries.length; i++) {
      batch.update(
        'dictionaries',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [dictionaries[i].id],
      );
    }

    await batch.commit(noResult: true);
  }

  // Collection CRUD
  Future<int> createCollection(Collection collection) async {
    final db = await database;
    return await db.insert('collections', collection.toMap());
  }

  Future<List<Collection>> getCollections({
    int? languageId,
    int? parentId,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (languageId != null && parentId != null) {
      where = 'language_id = ? AND parent_id = ?';
      whereArgs = [languageId, parentId];
    } else if (languageId != null) {
      where = 'language_id = ? AND parent_id IS NULL';
      whereArgs = [languageId];
    } else if (parentId != null) {
      where = 'parent_id = ?';
      whereArgs = [parentId];
    }

    final maps = await db.query(
      'collections',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'sort_order ASC, name ASC',
    );

    return maps.map((map) => Collection.fromMap(map)).toList();
  }

  Future<Collection?> getCollection(int id) async {
    final db = await database;
    final maps = await db.query(
      'collections',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Collection.fromMap(maps.first);
  }

  Future<int> updateCollection(Collection collection) async {
    final db = await database;
    return await db.update(
      'collections',
      collection.toMap(),
      where: 'id = ?',
      whereArgs: [collection.id],
    );
  }

  Future<int> deleteCollection(int id) async {
    final db = await database;
    return await db.delete('collections', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getTextCountInCollection(int collectionId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM texts
      WHERE collection_id = ?
    ''',
      [collectionId],
    );
    return result.first['count'] as int;
  }

  Future<void> moveTextToCollection(int textId, int? collectionId) async {
    final db = await database;
    await db.update(
      'texts',
      {'collection_id': collectionId},
      where: 'id = ?',
      whereArgs: [textId],
    );
  }

  // Batch operations for EPUB import
  Future<void> batchCreateTexts(List<TextDocument> texts) async {
    final db = await database;
    final batch = db.batch();

    for (final text in texts) {
      batch.insert('texts', text.toMap());
    }

    await batch.commit(noResult: true);
  }

  Future<List<TextDocument>> getTextsInCollection(int collectionId) async {
    final db = await database;
    final maps = await db.query(
      'texts',
      where: 'collection_id = ?',
      whereArgs: [collectionId],
      orderBy: 'sort_order ASC, title ASC',
    );
    return maps.map((map) => TextDocument.fromMap(map)).toList();
  }
}
