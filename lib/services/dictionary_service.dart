import 'package:url_launcher/url_launcher.dart';
import '../data/services/system_dictionary_service.dart';
import '../domain/entities/dictionary.dart';
import '../domain/repositories/dictionary_repository.dart';
import '../service_locator.dart';
import 'settings_service.dart';

class DictionaryService {
  // Resolved lazily: VocabularyController builds this in a field initializer,
  // before the service locator is guaranteed to be ready.
  final DictionaryRepository? _dictionaries;
  final SettingsService? _settingsService;

  DictionaryService({
    DictionaryRepository? dictionaries,
    SettingsService? settingsService,
  })  : _dictionaries = dictionaries,
        _settingsService = settingsService;

  DictionaryRepository get _repo => _dictionaries ?? db.dictionaries;
  SettingsService get _settings => _settingsService ?? settings;

  static String buildLookupUrl(String word, String dictUrl) {
    final encodedWord = Uri.encodeComponent(word.trim());
    return dictUrl.replaceAll('###', encodedWord);
  }

  Future<void> lookupWordExternal(String word, String dictUrl) async {
    if (dictUrl.isEmpty) {
      throw Exception('Dictionary URL not configured');
    }

    final url = buildLookupUrl(word, dictUrl);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch dictionary URL');
    }
  }

  /// Stored active dictionaries, preceded by the virtual System Dictionary
  /// entry on Apple platforms when it is enabled for the language.
  Future<List<Dictionary>> getActiveDictionaries(String languageId) async {
    final stored = await _repo.getAll(
      languageId: languageId,
      activeOnly: true,
    );
    if (SystemDictionaryService.isSupported &&
        await _settings.getSystemDictionaryEnabled(languageId)) {
      return [Dictionary.system(languageId), ...stored];
    }
    return stored;
  }

  /// DB only: this feeds the management screen, which must not show the
  /// virtual entry.
  Future<List<Dictionary>> getAllDictionaries(String languageId) async {
    return await _repo.getAll(languageId: languageId);
  }

  Future<bool> hasDictionaries(String languageId) async {
    final dicts = await getActiveDictionaries(languageId);
    return dicts.isNotEmpty;
  }
}
