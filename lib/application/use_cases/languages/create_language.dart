import '../../../domain/entities/dictionary.dart';
import '../../../domain/entities/language.dart';
import '../../../domain/repositories/dictionary_repository.dart';
import '../../../domain/repositories/language_repository.dart';
import '../../../services/settings_service.dart';

/// Saves a new language together with its default Google Translate dictionary.
class CreateLanguage {
  CreateLanguage({
    required LanguageRepository languages,
    required DictionaryRepository dictionaries,
    required SettingsService settings,
  })  : _languages = languages,
        _dictionaries = dictionaries,
        _settings = settings;

  final LanguageRepository _languages;
  final DictionaryRepository _dictionaries;
  final SettingsService _settings;

  /// Inserts [draft] (id must be null), then the default Google Translate
  /// dictionary for it. Returns the saved language (with its id).
  Future<Language> call(Language draft) async {
    // Parent first: foreign keys are enforced.
    final id = await _languages.create(draft);
    final targetLang = await _settings.getTargetLang();
    final sl = draft.languageCode.toLowerCase();
    final tl = targetLang.toLowerCase();
    await _dictionaries.create(
      Dictionary(
        languageId: id,
        name: 'Google Translate ${sl.toUpperCase()}-${tl.toUpperCase()}',
        url: 'https://translate.google.com/?sl=$sl&tl=$tl&text=###&op=translate',
      ),
    );
    return draft.copyWith(id: id);
  }
}
