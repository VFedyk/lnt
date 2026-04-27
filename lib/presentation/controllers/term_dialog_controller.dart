import 'package:flutter/widgets.dart';

import '../../application/use_cases/translation/translate_term.dart';
import '../../data/services/ai_explanation_service.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/term.dart';
import '../../domain/entities/translation_result.dart';
import '../../domain/value_objects/translation_provider.dart';
import '../../service_locator.dart';
import 'base_controller.dart';

class TermDialogResult {
  final Term term;
  final List<Translation> translations;
  final bool deleted;

  TermDialogResult({
    required this.term,
    required this.translations,
    this.deleted = false,
  });
}

class TermDialogController extends BaseController {
  final Term term;
  final String sentence;
  final String languageId;
  final String languageName;
  final String languageCode;

  late final TextEditingController termController;
  late final TextEditingController romanizationController;
  late final TextEditingController sentenceController;
  final _translationOutputController = TextEditingController();

  late int status;
  List<Translation> translations = [];
  final List<Object> translationKeys = [];
  final Map<String, ({Translation translation, Term term})> baseTranslations = {};

  List<Language> languages = [];
  late String selectedLanguageId;
  late String selectedLanguageName;

  bool hasDeepL = false;
  bool hasLibreTranslate = false;
  bool isTranslating = false;
  bool hasAi = false;
  bool isAiTranslating = false;

  bool get hasAnyTranslationProvider => hasDeepL || hasLibreTranslate;
  bool get hasMultipleTranslationProviders => hasDeepL && hasLibreTranslate;

  String get selectedLanguageCode {
    final found = languages.cast<Language?>().firstWhere(
      (l) => l?.id == selectedLanguageId,
      orElse: () => null,
    );
    if (found != null && found.languageCode.isNotEmpty) {
      return found.languageCode.toLowerCase();
    }
    if (selectedLanguageId == languageId && languageCode.isNotEmpty) {
      return languageCode.toLowerCase();
    }
    return '';
  }

  bool get isSelectedLanguageChinese {
    final code = selectedLanguageCode;
    if (code.startsWith('zh')) return true;
    final name = selectedLanguageName.toLowerCase();
    return name.contains('chinese') || name.contains('mandarin');
  }

  TermDialogController({
    required this.term,
    required this.sentence,
    required this.languageId,
    required this.languageName,
    required this.languageCode,
  }) {
    status = term.status;
    selectedLanguageId = languageId;
    selectedLanguageName = languageName;
    termController = TextEditingController(text: term.lowerText);
    romanizationController = TextEditingController(text: term.romanization);
    sentenceController = TextEditingController(
      text: term.sentence.isEmpty ? sentence : term.sentence,
    );
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _loadTranslations(),
      _checkTranslationProviders(),
      _loadLanguages(),
      _checkAiProvider(),
    ]);
  }

  Future<void> _checkTranslationProviders() async {
    final dL = await settings.hasDeepLApiKey();
    final lT = await settings.hasLibreTranslateApiKey();
    if (!isDisposed) {
      hasDeepL = dL;
      hasLibreTranslate = lT;
      safeNotify();
    }
  }

  Future<void> _checkAiProvider() async {
    final configured = await AiExplanationService(settings: settings).isConfigured();
    if (!isDisposed) {
      hasAi = configured;
      safeNotify();
    }
  }

  Future<void> _loadLanguages() async {
    final langs = await db.languages.getAll();
    if (!isDisposed) {
      languages = langs;
      safeNotify();
      maybeAutoFillRomanization();
    }
  }

  Future<void> _loadTranslations() async {
    if (term.id != null) {
      final loaded = await db.translations.getByTermId(term.id!);
      if (isDisposed) return;
      var result = loaded;
      if (result.isEmpty && term.translation.isNotEmpty) {
        result = [Translation(termId: term.id!, meaning: term.translation)];
      }
      translations = result;
      translationKeys
        ..clear()
        ..addAll(List.generate(translations.length, (_) => Object()));
      safeNotify();
      await _loadBaseTranslations();
    } else if (term.translation.isNotEmpty) {
      translations = [Translation(termId: '', meaning: term.translation)];
      translationKeys
        ..clear()
        ..add(Object());
      safeNotify();
    }
  }

  Future<void> _loadBaseTranslations() async {
    final ids = translations
        .where((t) => t.baseTranslationId != null)
        .map((t) => t.baseTranslationId!)
        .toSet();

    for (final id in ids) {
      if (isDisposed) return;
      if (baseTranslations.containsKey(id)) continue;
      final translation = await db.translations.getById(id);
      if (translation != null && !isDisposed) {
        final baseTerm = await db.terms.getById(translation.termId);
        if (baseTerm != null && !isDisposed) {
          baseTranslations[id] = (translation: translation, term: baseTerm);
          safeNotify();
        }
      }
    }
  }

  /// Loads (and migrates if needed) translations for a term selected as base form.
  /// Returns empty list if no translations can be found.
  Future<List<Translation>> loadTranslationsForTerm(Term selectedTerm) async {
    var termTranslations = await db.translations.getByTermId(selectedTerm.id!);
    if (isDisposed) return [];
    if (termTranslations.isEmpty && selectedTerm.translation.isNotEmpty) {
      final legacy = Translation(
        termId: selectedTerm.id!,
        meaning: selectedTerm.translation,
      );
      await db.translations.replaceForTerm(selectedTerm.id!, [legacy]);
      if (isDisposed) return [];
      termTranslations = await db.translations.getByTermId(selectedTerm.id!);
    }
    return termTranslations;
  }

  void setBaseTranslation(int index, Term selectedTerm, Translation translation) {
    translations[index] = translations[index].copyWith(
      baseTranslationId: translation.id,
    );
    baseTranslations[translation.id!] = (
      translation: translation,
      term: selectedTerm,
    );
    safeNotify();
  }

  void clearBaseTranslation(int index) {
    translations[index] = translations[index].copyWith(clearBaseTranslationId: true);
    safeNotify();
  }

  void changeLanguage(Language lang) {
    selectedLanguageId = lang.id!;
    selectedLanguageName = lang.name;
    safeNotify();
    maybeAutoFillRomanization();
  }

  void updateStatus(int newStatus) {
    status = newStatus;
    safeNotify();
  }

  void addTranslation() {
    translations.add(Translation(
      termId: term.id ?? '',
      meaning: '',
      sortOrder: translations.length,
    ));
    translationKeys.add(Object());
    safeNotify();
  }

  void removeTranslation(int index) {
    translations.removeAt(index);
    translationKeys.removeAt(index);
    safeNotify();
  }

  void updateTranslation(int index, Translation updated, {bool rebuild = false}) {
    translations[index] = updated;
    if (rebuild) safeNotify();
  }

  void maybeAutoFillRomanization() {
    if (!isSelectedLanguageChinese) return;
    if (romanizationController.text.trim().isNotEmpty) return;
    final source = termController.text.trim();
    if (source.isEmpty) return;
    final pinyin = chineseSegService.getPinyin(source).trim();
    if (pinyin.isNotEmpty) {
      romanizationController.text = pinyin;
    }
  }

  /// Returns null on success, or a [TranslationResult] with an error on failure.
  Future<TranslationResult?> translateAndAdd(TranslationProvider provider) async {
    isTranslating = true;
    safeNotify();
    final result = await sl<TranslateTerm>().call(
      text: termController.text.trim(),
      sourceLanguageCode: selectedLanguageCode,
      provider: provider,
    );
    if (!isDisposed) {
      if (result.isSuccess && result.text != null && result.text!.isNotEmpty) {
        translations.add(Translation(
          termId: term.id ?? '',
          meaning: result.text!,
          sortOrder: 0,
        ));
        translationKeys.add(Object());
      }
      isTranslating = false;
      safeNotify();
    }
    return result.isSuccess ? null : result;
  }

  /// Throws on AI service failure — caller shows the SnackBar.
  Future<void> aiTranslateWord() async {
    isAiTranslating = true;
    safeNotify();
    try {
      final meanings = await AiExplanationService(settings: settings).translateWord(
        word: termController.text.trim(),
        contextSentence: sentenceController.text.trim(),
        languageName: selectedLanguageName,
      );
      if (!isDisposed && meanings.isNotEmpty) {
        for (final entry in meanings) {
          translations.add(Translation(
            termId: term.id ?? '',
            meaning: entry.meaning,
            partOfSpeech: entry.partOfSpeech,
            sortOrder: translations.length,
          ));
          translationKeys.add(Object());
        }
        safeNotify();
      }
    } finally {
      if (!isDisposed) {
        isAiTranslating = false;
        safeNotify();
      }
    }
  }

  TermDialogResult buildSaveResult() {
    final editedTerm = termController.text.trim().toLowerCase();
    final romanization = romanizationController.text.trim().isNotEmpty
        ? romanizationController.text.trim()
        : (isSelectedLanguageChinese
              ? chineseSegService.getPinyin(editedTerm).trim()
              : '');
    final legacyTranslation =
        translations.isNotEmpty ? translations.first.meaning : '';
    final updatedTerm = term.copyWith(
      languageId: selectedLanguageId,
      text: editedTerm,
      lowerText: editedTerm,
      status: status,
      translation: legacyTranslation,
      romanization: romanization,
      sentence: sentenceController.text,
      lastAccessed: DateTime.now(),
    );
    return TermDialogResult(term: updatedTerm, translations: translations);
  }

  TermDialogResult buildDeleteResult() =>
      TermDialogResult(term: term, translations: const [], deleted: true);

  @override
  void dispose() {
    termController.dispose();
    romanizationController.dispose();
    sentenceController.dispose();
    _translationOutputController.dispose();
    super.dispose();
  }
}
