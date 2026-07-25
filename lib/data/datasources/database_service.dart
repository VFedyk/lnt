import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'database_migrations.dart' as migrations;
import '../../services/settings_service.dart';
import '../notifiers/data_change_notifier.dart';
import '../repositories/collection_repository_impl.dart';
import '../repositories/dictionary_repository_impl.dart';
import '../repositories/language_repository_impl.dart';
import '../repositories/radical_progress_repository_impl.dart';
import '../repositories/review_card_repository_impl.dart';
import '../repositories/review_log_repository_impl.dart';
import '../repositories/term_repository_impl.dart';
import '../repositories/term_sentence_repository_impl.dart';
import '../repositories/term_status_log_repository_impl.dart';
import '../repositories/text_foreign_word_repository_impl.dart';
import '../repositories/text_repository_impl.dart';
import '../repositories/translation_repository_impl.dart';
import '../../domain/repositories/collection_repository.dart';
import '../../domain/repositories/dictionary_repository.dart';
import '../../domain/repositories/language_repository.dart';
import '../../domain/repositories/radical_progress_repository.dart';
import '../../domain/repositories/review_card_repository.dart';
import '../../domain/repositories/review_log_repository.dart';
import '../../domain/repositories/term_repository.dart';
import '../../domain/repositories/term_sentence_repository.dart';
import '../../domain/repositories/term_status_log_repository.dart';
import '../../domain/repositories/text_foreign_word_repository.dart';
import '../../domain/repositories/text_repository.dart';
import '../../domain/repositories/translation_repository.dart';

class DatabaseService {
  final SettingsService _settings;
  final DataChangeNotifier _changes;

  Database? _database;
  String? _dbPath;

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

  DatabaseService(this._settings, this._changes) {
    languages = LanguageRepositoryImpl(() => database, onChange: _changes.languages);
    texts = TextRepositoryImpl(() => database, onChange: _changes.texts);
    terms = TermRepositoryImpl(() => database, onChange: _changes.terms, termEvents: _changes.termEvents);
    collections = CollectionRepositoryImpl(() => database, onChange: _changes.collections);
    dictionaries = DictionaryRepositoryImpl(() => database, onChange: _changes.dictionaries);
    translations = TranslationRepositoryImpl(() => database, onChange: _changes.translations);
    textForeignWords = TextForeignWordRepositoryImpl(() => database);
    final rcImpl = ReviewCardRepositoryImpl(() => database,
        onChange: _changes.reviewCards, settings: _settings);
    rcImpl.subscribeToTermEvents(_changes.termEvents.stream);
    reviewCards = rcImpl;
    reviewLogs = ReviewLogRepositoryImpl(() => database);
    termStatusLog = TermStatusLogRepositoryImpl(() => database);
    radicalProgress = RadicalProgressRepositoryImpl(() => database, onChange: _changes.radicalProgress);
    termSentences = TermSentenceRepositoryImpl(() => database, onChange: _changes.termSentences);
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  String? get currentDbPath => _dbPath;

  Future<Database> _initDB() async {
    final customPath = await _settings.getCustomDbPath();
    if (customPath != null && customPath.isNotEmpty) {
      _dbPath = customPath;
    } else {
      final dbDir = await getDatabasesPath();
      _dbPath = join(dbDir, 'lnt.db');
    }

    return await openDatabase(
      _dbPath!,
      version: migrations.databaseVersion,
      // Deliberately onOpen, not onConfigure: sqflite wraps onCreate/onUpgrade
      // in a transaction where `PRAGMA foreign_keys` is a silent no-op, and the
      // drop/recreate migrations (v18 UUID migration, v20 cover images) must run
      // without FK enforcement anyway. onOpen runs after migrations, on every
      // connection — which is exactly when we want cascades to fire.
      onOpen: (db) => db.execute('PRAGMA foreign_keys = ON'),
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
