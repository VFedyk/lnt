import 'package:flutter/widgets.dart';

import '../../application/use_cases/translation/translate_term.dart';
import '../../data/services/ai_explanation_service.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/review_card.dart';
import '../../domain/entities/term.dart';
import '../../domain/entities/term_sentence.dart';
import '../../domain/entities/translation_result.dart';
import '../../domain/value_objects/translation_provider.dart';
import '../../service_locator.dart';
import 'base_controller.dart';

class TermEditResult {
  final Term term;
  final List<Translation> translations;
  final TermSentenceEdits sentenceEdits;
  final bool deleted;

  TermEditResult({
    required this.term,
    required this.translations,
    this.sentenceEdits = TermSentenceEdits.empty,
    this.deleted = false,
  });
}

class TermEditController extends BaseController {
  final Term term;

  /// Context sentence at the tapped position in the reader (empty from other
  /// entry points). Seeded as a pending sentence for a brand-new term; offered
  /// as a one-tap suggestion on the Sentences tab for an existing term.
  final String sentence;
  final String languageId;
  final String languageName;
  final String languageCode;

  late final TextEditingController termController;
  late final TextEditingController romanizationController;
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

  // ── Sentences tab ──
  List<TermSentence> sentences = [];
  final List<String> pendingAdded = [];
  final Map<String, String> pendingEdited = {};
  final Set<String> pendingDeleted = {};
  Map<String, String> sentenceSourceTitles = {};
  bool sentencesLoading = false;

  // Per-word history (loaded when term.id != null).
  bool historyLoading = false;
  List<({DateTime reviewedAt, int rating, int? durationMs})> reviewHistory = [];
  List<({DateTime changedAt, int status})> statusTransitions = [];
  ReviewCardRecord? reviewCard;

  // ── Dirty tracking (captured after _initialize) ──
  late String _initialTerm;
  late String _initialRomanization;
  late int _initialStatus;
  late String _initialLanguageId;
  List<String> _initialTranslationSig = const [];

  int get totalReviews => reviewHistory.length;
  int get recalledCount => reviewHistory.where((r) => r.rating != 1).length;
  DateTime? get lastReviewedAt =>
      reviewHistory.isEmpty ? null : reviewHistory.last.reviewedAt;
  DateTime? get nextDue => reviewCard?.nextDue;
  double? get stability => (reviewCard?.cardData['stability'] as num?)?.toDouble();

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

  TermEditController({
    required this.term,
    required this.sentence,
    required this.languageId,
    required this.languageName,
    required this.languageCode,
  }) {
    status = term.status;
    historyLoading = term.id != null;
    sentencesLoading = term.id != null;
    selectedLanguageId = languageId;
    selectedLanguageName = languageName;
    termController = TextEditingController(text: term.lowerText);
    romanizationController = TextEditingController(text: term.romanization);

    _initialTerm = termController.text;
    _initialRomanization = romanizationController.text;
    _initialStatus = status;
    _initialLanguageId = selectedLanguageId;

    // A brand-new term seeds the reader's context sentence as a pending add.
    if (term.id == null && sentence.trim().isNotEmpty) {
      pendingAdded.add(sentence.trim());
    }

    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _loadTranslations(),
      _checkTranslationProviders(),
      _loadLanguages(),
      _checkAiProvider(),
      _loadHistory(),
      loadSentences(),
    ]);
    _initialTranslationSig = _translationSignature();
  }

  // ── Sentences ──

  Future<void> loadSentences() async {
    if (term.id == null) {
      sentencesLoading = false;
      safeNotify();
      return;
    }
    final loaded = await db.termSentences.getByTermId(term.id!);
    if (isDisposed) return;
    sentences = loaded;

    final textIds = loaded
        .map((s) => s.sourceTextId)
        .whereType<String>()
        .toSet()
        .toList();
    final titles = <String, String>{};
    for (final id in textIds) {
      final doc = await db.texts.getById(id);
      if (doc != null) titles[id] = doc.title;
    }
    if (isDisposed) return;
    sentenceSourceTitles = titles;
    sentencesLoading = false;
    safeNotify();
  }

  /// Persisted (minus deletions, with edits applied) merged with pending adds —
  /// so the list renders identically for a new and an existing term.
  List<({String? id, String text, String? sourceTitle, DateTime? createdAt})>
      get visibleSentences {
    final out = <({String? id, String text, String? sourceTitle, DateTime? createdAt})>[];
    for (final s in sentences) {
      if (pendingDeleted.contains(s.id)) continue;
      out.add((
        id: s.id,
        text: pendingEdited[s.id] ?? s.sentence,
        sourceTitle: s.sourceTextId != null
            ? sentenceSourceTitles[s.sourceTextId]
            : null,
        createdAt: s.createdAt,
      ));
    }
    for (final text in pendingAdded) {
      out.add((id: null, text: text, sourceTitle: null, createdAt: null));
    }
    return out;
  }

  bool hasSentence(String text) {
    final needle = text.trim().toLowerCase();
    return visibleSentences.any((s) => s.text.trim().toLowerCase() == needle);
  }

  void addSentence(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || hasSentence(trimmed)) return;
    pendingAdded.add(trimmed);
    safeNotify();
  }

  void editSentence(String id, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final original = sentences.firstWhere((s) => s.id == id).sentence;
    if (trimmed == original) {
      pendingEdited.remove(id);
    } else {
      pendingEdited[id] = trimmed;
    }
    safeNotify();
  }

  void editPending(int index, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    pendingAdded[index] = trimmed;
    safeNotify();
  }

  void removeSentence(String id) {
    pendingEdited.remove(id);
    pendingDeleted.add(id);
    safeNotify();
  }

  void removePending(int index) {
    pendingAdded.removeAt(index);
    safeNotify();
  }

  TermSentenceEdits buildSentenceEdits() => TermSentenceEdits(
        added: List.of(pendingAdded),
        edited: Map.of(pendingEdited),
        deleted: List.of(pendingDeleted),
      );

  bool get _sentencesDirty =>
      pendingAdded.isNotEmpty ||
      pendingEdited.isNotEmpty ||
      pendingDeleted.isNotEmpty;

  // ── Dirty ──

  List<String> _translationSignature() => [
        for (final t in translations)
          '${t.meaning}|${t.partOfSpeech ?? ''}|${t.baseTranslationId ?? ''}',
      ];

  bool get isDirty {
    if (termController.text != _initialTerm) return true;
    if (romanizationController.text != _initialRomanization) return true;
    if (status != _initialStatus) return true;
    if (selectedLanguageId != _initialLanguageId) return true;
    if (_sentencesDirty) return true;
    final sig = _translationSignature();
    if (sig.length != _initialTranslationSig.length) return true;
    for (var i = 0; i < sig.length; i++) {
      if (sig[i] != _initialTranslationSig[i]) return true;
    }
    return false;
  }

  Future<void> _loadHistory() async {
    if (term.id == null) return;
    final reviews = await db.reviewLogs.getByTermId(term.id!);
    final statuses = await db.termStatusLog.getByTermId(term.id!);
    final card = await db.reviewCards.getByTermId(term.id!);
    if (isDisposed) return;
    reviewHistory = reviews;
    statusTransitions = _collapseStatuses(statuses);
    reviewCard = card;
    historyLoading = false;
    safeNotify();
  }

  /// Drops consecutive identical statuses so only transitions remain (a status
  /// row is logged on every review, not just on change).
  static List<({DateTime changedAt, int status})> _collapseStatuses(
    List<({DateTime changedAt, int status})> rows,
  ) {
    final out = <({DateTime changedAt, int status})>[];
    for (final r in rows) {
      if (out.isEmpty || out.last.status != r.status) out.add(r);
    }
    return out;
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
        contextSentence: sentence.trim(),
        languageName: selectedLanguageName,
        languageCode: selectedLanguageCode,
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

  TermEditResult buildSaveResult() {
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
      lastAccessed: DateTime.now(),
    );
    return TermEditResult(
      term: updatedTerm,
      translations: translations,
      sentenceEdits: buildSentenceEdits(),
    );
  }

  TermEditResult buildDeleteResult() =>
      TermEditResult(term: term, translations: const [], deleted: true);

  @override
  void dispose() {
    termController.dispose();
    romanizationController.dispose();
    _translationOutputController.dispose();
    super.dispose();
  }
}
