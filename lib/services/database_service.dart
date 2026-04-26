import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'database_migrations.dart' as migrations;
import '../service_locator.dart';
import '../repositories/language_repository.dart';
import '../repositories/text_repository.dart';
import '../repositories/term_repository.dart';
import '../repositories/collection_repository.dart';
import '../repositories/dictionary_repository.dart';
import '../repositories/translation_repository.dart';
import '../repositories/text_foreign_word_repository.dart';
import '../repositories/review_card_repository.dart';
import '../repositories/radical_progress_repository.dart';
import '../repositories/review_log_repository.dart';
import '../repositories/term_sentence_repository.dart';
import '../repositories/term_status_log_repository.dart';

class DatabaseService {
  Database? _database;
  String? _dbPath;

  // Repositories
  late final LanguageRepository languages;
  late final TextRepository texts;
  late final TermRepository terms;
  late final CollectionRepository collections;
  late final DictionaryRepository dictionaries;
  late final TranslationRepository translations;
  late final TextForeignWordRepository textForeignWords;
  late final ReviewCardRepository reviewCards;
  late final ReviewLogRepository reviewLogs;
  late final TermStatusLogRepository termStatusLog;
  late final RadicalProgressRepository radicalProgress;
  late final TermSentenceRepository termSentences;

  DatabaseService() {
    final changes = dataChanges;
    languages = LanguageRepository(() => database, onChange: changes.languages);
    texts = TextRepository(() => database, onChange: changes.texts);
    terms = TermRepository(() => database, onChange: changes.terms, termEvents: changes.termEvents);
    collections = CollectionRepository(
      () => database,
      onChange: changes.collections,
    );
    dictionaries = DictionaryRepository(() => database, onChange: changes.dictionaries);
    translations = TranslationRepository(() => database, onChange: changes.translations);
    textForeignWords = TextForeignWordRepository(() => database);
    reviewCards = ReviewCardRepository(
      () => database,
      onChange: changes.reviewCards,
    );
    reviewCards.subscribeToTermEvents(changes.termEvents.stream);
    reviewLogs = ReviewLogRepository(() => database);
    termStatusLog = TermStatusLogRepository(() => database);
    radicalProgress = RadicalProgressRepository(() => database, onChange: changes.radicalProgress);
    termSentences = TermSentenceRepository(() => database, onChange: changes.termSentences);
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  String? get currentDbPath => _dbPath;

  Future<Database> _initDB() async {
    final customPath = await settings.getCustomDbPath();
    if (customPath != null && customPath.isNotEmpty) {
      _dbPath = customPath;
    } else {
      final dbDir = await getDatabasesPath();
      _dbPath = join(dbDir, 'lnt.db');
    }

    return await openDatabase(
      _dbPath!,
      version: migrations.databaseVersion,
      onCreate: migrations.onCreate,
      onUpgrade: migrations.onUpgrade,
    );
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _dbPath = null;
    }
  }
}
