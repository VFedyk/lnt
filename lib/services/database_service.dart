import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'settings_service.dart';
import '../models/language.dart';
import '../models/term.dart';
import '../models/text_document.dart';
import '../models/dictionary.dart';
import '../models/collection.dart';
import '../repositories/language_repository.dart';
import '../repositories/text_repository.dart';
import '../repositories/term_repository.dart';
import '../repositories/collection_repository.dart';
import '../repositories/dictionary_repository.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  static String? _dbPath;

  // Repositories
  late final LanguageRepository languages;
  late final TextRepository texts;
  late final TermRepository terms;
  late final CollectionRepository collections;
  late final DictionaryRepository dictionaries;

  DatabaseService._init() {
    languages = LanguageRepository(() => database);
    texts = TextRepository(() => database);
    terms = TermRepository(() => database);
    collections = CollectionRepository(() => database);
    dictionaries = DictionaryRepository(() => database);
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  String? get currentDbPath => _dbPath;

  Future<Database> _initDB() async {
    final customPath = await SettingsService.instance.getCustomDbPath();
    if (customPath != null && customPath.isNotEmpty) {
      _dbPath = customPath;
    } else {
      final dbDir = await getDatabasesPath();
      _dbPath = join(dbDir, 'lnt.db');
    }

    return await openDatabase(
      _dbPath!,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _dbPath = null;
    }
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE texts ADD COLUMN sort_order INTEGER DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE collections ADD COLUMN cover_image TEXT');
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE terms ADD COLUMN base_term_id INTEGER REFERENCES terms(id) ON DELETE SET NULL',
      );
      await db.execute('CREATE INDEX idx_terms_base ON terms(base_term_id)');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE texts ADD COLUMN cover_image TEXT');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE texts ADD COLUMN status INTEGER DEFAULT 0');
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
        cover_image TEXT,
        status INTEGER DEFAULT 0,
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
        base_term_id INTEGER,
        FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE,
        FOREIGN KEY (base_term_id) REFERENCES terms (id) ON DELETE SET NULL,
        UNIQUE(language_id, lower_text)
      )
    ''');

    await db.execute('CREATE INDEX idx_terms_lower ON terms(lower_text)');
    await db.execute('CREATE INDEX idx_terms_language ON terms(language_id)');
    await db.execute('CREATE INDEX idx_terms_base ON terms(base_term_id)');
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
        cover_image TEXT,
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

  // ============================================================
  // Legacy API - delegates to repositories for backward compatibility
  // ============================================================

  // Language
  Future<int> createLanguage(Language language) => languages.create(language);
  Future<List<Language>> getLanguages() => languages.getAll();
  Future<Language?> getLanguage(int id) => languages.getById(id);
  Future<int> updateLanguage(Language language) => languages.update(language);
  Future<int> deleteLanguage(int id) => languages.delete(id);

  // Text
  Future<int> createText(TextDocument text) => texts.create(text);
  Future<List<TextDocument>> getTexts({int? languageId}) =>
      texts.getAll(languageId: languageId);
  Future<TextDocument?> getText(int id) => texts.getById(id);
  Future<int> updateText(TextDocument text) => texts.update(text);
  Future<int> deleteText(int id) => texts.delete(id);
  Future<List<TextDocument>> searchTexts(int languageId, String query) =>
      texts.search(languageId, query);
  Future<int> getTotalTextCount(int languageId) =>
      texts.getCountByLanguage(languageId);
  Future<int> getTextCountInCollection(int collectionId) =>
      texts.getCountInCollection(collectionId);
  Future<void> moveTextToCollection(int textId, int? collectionId) =>
      texts.moveToCollection(textId, collectionId);
  Future<void> batchCreateTexts(List<TextDocument> textList) =>
      texts.batchCreate(textList);
  Future<List<TextDocument>> getTextsInCollection(int collectionId) =>
      texts.getByCollection(collectionId);
  Future<List<TextDocument>> getRecentlyAddedTexts(
    int languageId, {
    int limit = 5,
  }) => texts.getRecentlyAdded(languageId, limit: limit);
  Future<List<TextDocument>> getRecentlyReadTexts(
    int languageId, {
    int limit = 5,
  }) => texts.getRecentlyRead(languageId, limit: limit);

  // Term
  Future<int> createTerm(Term term) => terms.create(term);
  Future<List<Term>> getTerms({int? languageId, int? status}) =>
      terms.getAll(languageId: languageId, status: status);
  Future<Term?> getTermByText(int languageId, String text) =>
      terms.getByText(languageId, text);
  Future<Map<String, Term>> getTermsMap(int languageId) =>
      terms.getMapByLanguage(languageId);
  Future<int> updateTerm(Term term) => terms.update(term);
  Future<int> deleteTerm(int id) => terms.delete(id);
  Future<int> deleteTermsByLanguage(int languageId) =>
      terms.deleteByLanguage(languageId);
  Future<Map<int, int>> getTermCountsByStatus(int languageId) =>
      terms.getCountsByStatus(languageId);
  Future<int> getTotalTermCount(int languageId) =>
      terms.getTotalCount(languageId);
  Future<void> bulkUpdateTermStatus(List<int> termIds, int newStatus) =>
      terms.bulkUpdateStatus(termIds, newStatus);
  Future<List<Term>> searchTerms(int languageId, String query) =>
      terms.search(languageId, query);
  Future<Term?> getTerm(int id) => terms.getById(id);
  Future<List<Term>> getLinkedTerms(int baseTermId) =>
      terms.getLinkedTerms(baseTermId);
  Future<Map<String, ({Term term, String languageName})>> getTermsInOtherLanguages(
    int excludeLanguageId,
    Set<String> words,
  ) =>
      terms.getTermsInOtherLanguages(excludeLanguageId, words);

  // Collection
  Future<int> createCollection(Collection collection) =>
      collections.create(collection);
  Future<List<Collection>> getCollections({int? languageId, int? parentId}) =>
      collections.getAll(languageId: languageId, parentId: parentId);
  Future<Collection?> getCollection(int id) => collections.getById(id);
  Future<int> updateCollection(Collection collection) =>
      collections.update(collection);
  Future<int> deleteCollection(int id) => collections.delete(id);

  // Dictionary
  Future<int> createDictionary(Dictionary dictionary) =>
      dictionaries.create(dictionary);
  Future<List<Dictionary>> getDictionaries({
    int? languageId,
    bool activeOnly = false,
  }) => dictionaries.getAll(languageId: languageId, activeOnly: activeOnly);
  Future<Dictionary?> getDictionary(int id) => dictionaries.getById(id);
  Future<int> updateDictionary(Dictionary dictionary) =>
      dictionaries.update(dictionary);
  Future<int> deleteDictionary(int id) => dictionaries.delete(id);
  Future<int> deleteDictionariesByLanguage(int languageId) =>
      dictionaries.deleteByLanguage(languageId);
  Future<void> reorderDictionaries(List<Dictionary> dictionaryList) =>
      dictionaries.reorder(dictionaryList);
}
