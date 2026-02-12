import 'package:get_it/get_it.dart';

import 'services/database_service.dart';
import 'services/settings_service.dart';
import 'services/review_service.dart';
import 'services/backup_service.dart';
import 'services/deepl_service.dart';
import 'services/libretranslate_service.dart';
import 'services/text_parser_service.dart';
import 'services/import_export_service.dart';
import 'services/epub_import_service.dart';
import 'services/url_import_service.dart';
import 'services/dictionary_service.dart';
import 'services/tts_service.dart';
import 'services/data_change_notifier.dart';

final sl = GetIt.instance;

// Convenience getters for singletons
DatabaseService get db => sl<DatabaseService>();
SettingsService get settings => sl<SettingsService>();
BackupService get backupService => sl<BackupService>();
ReviewService get reviewService => sl<ReviewService>();
DeepLService get deepLService => sl<DeepLService>();
LibreTranslateService get libreTranslateService =>
    sl<LibreTranslateService>();
TtsService get ttsService => sl<TtsService>();
DataChangeNotifier get dataChanges => sl<DataChangeNotifier>();

void setupServiceLocator() {
  // Singletons (lazy — constructed on first access)
  sl.registerLazySingleton<DataChangeNotifier>(() => DataChangeNotifier());
  sl.registerLazySingleton<SettingsService>(() => SettingsService());
  sl.registerLazySingleton<DatabaseService>(() => DatabaseService());
  sl.registerLazySingleton<ReviewService>(() => ReviewService());
  sl.registerLazySingleton<BackupService>(() => BackupService());
  sl.registerLazySingleton<DeepLService>(() => DeepLService());
  sl.registerLazySingleton<LibreTranslateService>(
    () => LibreTranslateService(),
  );
  sl.registerLazySingleton<TtsService>(() => TtsService());

  // Factories (new instance each time)
  sl.registerFactory<TextParserService>(() => TextParserService());
  sl.registerFactory<ImportExportService>(() => ImportExportService());
  sl.registerFactory<EpubImportService>(() => EpubImportService());
  sl.registerFactory<UrlImportService>(() => UrlImportService());
  sl.registerFactory<DictionaryService>(() => DictionaryService());
}
