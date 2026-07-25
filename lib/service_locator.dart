import 'package:get_it/get_it.dart';

import 'data/datasources/database_service.dart';
import 'data/notifiers/data_change_notifier.dart';
import 'data/services/deepl_service.dart';
import 'data/services/libretranslate_service.dart';
import 'data/services/tts_service.dart';
import 'data/services/chinese_segmentation_service.dart';
import 'domain/repositories/collection_repository.dart';
import 'domain/repositories/dictionary_repository.dart';
import 'domain/repositories/language_repository.dart';
import 'domain/repositories/radical_progress_repository.dart';
import 'domain/repositories/review_card_repository.dart';
import 'domain/repositories/review_log_repository.dart';
import 'domain/repositories/term_repository.dart';
import 'domain/repositories/term_sentence_repository.dart';
import 'domain/repositories/term_status_log_repository.dart';
import 'domain/repositories/text_foreign_word_repository.dart';
import 'domain/repositories/text_repository.dart';
import 'domain/repositories/text_word_repository.dart';
import 'domain/repositories/translation_repository.dart';
import 'application/use_cases/review/review_term.dart';
import 'application/use_cases/terms/bulk_import_terms.dart';
import 'application/use_cases/terms/save_term.dart';
import 'application/use_cases/texts/resolve_text_terms.dart';
import 'application/use_cases/translation/translate_term.dart';
import 'services/settings_service.dart';
import 'services/review_service.dart';
import 'services/backup_service.dart';
import 'services/sync_service.dart';
import 'services/text_parser_service.dart';
import 'services/text_word_index_service.dart';
import 'services/import_export_service.dart';
import 'services/epub_import_service.dart';
import 'services/url_import_service.dart';
import 'services/dictionary_service.dart';

final sl = GetIt.instance;

// Convenience getters for singletons
DatabaseService get db => sl<DatabaseService>();
SettingsService get settings => sl<SettingsService>();
BackupService get backupService => sl<BackupService>();
SyncService get syncService => sl<SyncService>();
ReviewService get reviewService => sl<ReviewService>();
DeepLService get deepLService => sl<DeepLService>();
LibreTranslateService get libreTranslateService => sl<LibreTranslateService>();
TtsService get ttsService => sl<TtsService>();
DataChangeNotifier get dataChanges => sl<DataChangeNotifier>();
ChineseSegmentationService get chineseSegService =>
    sl<ChineseSegmentationService>();
TextWordIndexService get textWordIndex => sl<TextWordIndexService>();

// Use case getters
ReviewTerm get reviewTerm => sl<ReviewTerm>();
SaveTerm get saveTerm => sl<SaveTerm>();
BulkImportTerms get bulkImportTerms => sl<BulkImportTerms>();
TranslateTerm get translateTerm => sl<TranslateTerm>();
ResolveTextTerms get resolveTextTerms => sl<ResolveTextTerms>();

void setupServiceLocator() {
  sl.registerLazySingleton<DataChangeNotifier>(() => DataChangeNotifier());
  sl.registerLazySingleton<SettingsService>(() => SettingsService());
  sl.registerLazySingleton<DatabaseService>(
    () => DatabaseService(sl<SettingsService>(), sl<DataChangeNotifier>()),
  );
  // Use cases
  sl.registerLazySingleton<ReviewTerm>(
    () => ReviewTerm(
      reviewCards: sl<ReviewCardRepository>(),
      terms: sl<TermRepository>(),
      reviewLogs: sl<ReviewLogRepository>(),
      termStatusLog: sl<TermStatusLogRepository>(),
    ),
  );
  sl.registerLazySingleton<SaveTerm>(
    () => SaveTerm(
      terms: sl<TermRepository>(),
      translations: sl<TranslationRepository>(),
    ),
  );
  sl.registerLazySingleton<BulkImportTerms>(
    () => BulkImportTerms(terms: sl<TermRepository>()),
  );
  sl.registerLazySingleton<TranslateTerm>(
    () => TranslateTerm(
      deepL: sl<DeepLService>(),
      libreTranslate: sl<LibreTranslateService>(),
      settings: sl<SettingsService>(),
    ),
  );

  sl.registerLazySingleton<ResolveTextTerms>(
    () => ResolveTextTerms(
      index: sl<TextWordIndexService>(),
      terms: sl<TermRepository>(),
    ),
  );

  sl.registerLazySingleton<ReviewService>(() => ReviewService(sl<ReviewTerm>()));
  sl.registerLazySingleton<BackupService>(() => BackupService());
  sl.registerLazySingleton<SyncService>(
    () => SyncService(
      db: sl<DatabaseService>(),
      settings: sl<SettingsService>(),
      changes: sl<DataChangeNotifier>(),
    ),
  );
  sl.registerLazySingleton<DeepLService>(() => DeepLService());
  sl.registerLazySingleton<LibreTranslateService>(
    () => LibreTranslateService(),
  );
  sl.registerLazySingleton<TtsService>(() => TtsService());

  // Chinese segmentation — registered as a singleton so the jieba dictionary
  // is only loaded once. init() is called lazily on first use inside the service.
  sl.registerLazySingleton<ChineseSegmentationService>(
    () => ChineseSegmentationService(),
  );

  // Repository interface → impl bindings (delegate to DatabaseService facade)
  sl.registerLazySingleton<TermRepository>(() => sl<DatabaseService>().terms);
  sl.registerLazySingleton<TextRepository>(() => sl<DatabaseService>().texts);
  sl.registerLazySingleton<LanguageRepository>(() => sl<DatabaseService>().languages);
  sl.registerLazySingleton<CollectionRepository>(() => sl<DatabaseService>().collections);
  sl.registerLazySingleton<DictionaryRepository>(() => sl<DatabaseService>().dictionaries);
  sl.registerLazySingleton<TranslationRepository>(() => sl<DatabaseService>().translations);
  sl.registerLazySingleton<TextForeignWordRepository>(() => sl<DatabaseService>().textForeignWords);
  sl.registerLazySingleton<ReviewCardRepository>(() => sl<DatabaseService>().reviewCards);
  sl.registerLazySingleton<ReviewLogRepository>(() => sl<DatabaseService>().reviewLogs);
  sl.registerLazySingleton<TermStatusLogRepository>(() => sl<DatabaseService>().termStatusLog);
  sl.registerLazySingleton<RadicalProgressRepository>(() => sl<DatabaseService>().radicalProgress);
  sl.registerLazySingleton<TermSentenceRepository>(() => sl<DatabaseService>().termSentences);
  sl.registerLazySingleton<TextWordRepository>(() => sl<DatabaseService>().textWords);

  // TextParserService is a factory — resolve it once here rather than per call.
  sl.registerLazySingleton<TextWordIndexService>(
    () => TextWordIndexService(
      repo: sl<TextWordRepository>(),
      parser: sl<TextParserService>(),
    ),
  );

  // Factories (new instance each time)
  sl.registerFactory<TextParserService>(
    () => TextParserService(chineseSeg: sl<ChineseSegmentationService>()),
  );
  sl.registerFactory<ImportExportService>(() => ImportExportService());
  sl.registerFactory<EpubImportService>(() => EpubImportService());
  sl.registerFactory<UrlImportService>(() => UrlImportService());
  sl.registerFactory<DictionaryService>(() => DictionaryService());
}
