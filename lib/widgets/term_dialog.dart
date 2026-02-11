import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/term.dart';
import '../models/dictionary.dart';
import '../models/language.dart';
import '../service_locator.dart';
import '../services/deepl_service.dart';
import '../services/libretranslate_service.dart';
import '../utils/constants.dart';
import 'base_term_search_dialog.dart';
import 'translation_mixin.dart';

/// Result returned from TermDialog containing both term and translations
class TermDialogResult {
  final Term term;
  final List<Translation> translations;

  TermDialogResult({required this.term, required this.translations});
}

abstract class _TermDialogConstants {
  static const double closeIconSize = 18.0;
  static const int sentenceMaxLines = 3;
}

class TermDialog extends StatefulWidget {
  final Term term;
  final String sentence;
  final List<Dictionary> dictionaries;
  final Function(BuildContext, Dictionary) onLookup;
  final int languageId;
  final String languageName;
  final String languageCode;

  const TermDialog({
    super.key,
    required this.term,
    required this.sentence,
    required this.dictionaries,
    required this.onLookup,
    required this.languageId,
    required this.languageName,
    required this.languageCode,
  });

  @override
  State<TermDialog> createState() => _TermDialogState();
}

class _TermDialogState extends State<TermDialog> with TranslationMixin {
  late int _status;
  late TextEditingController _termController;
  late TextEditingController _romanizationController;
  late TextEditingController _sentenceController;

  // Multiple translations support
  List<Translation> _translations = [];
  // baseTranslationId -> (translation, its parent term)
  final Map<int, ({Translation translation, Term term})> _baseTranslations = {};
  late TextEditingController _translationController;

  // Language selection
  List<Language> _languages = [];
  late int _selectedLanguageId;
  late String _selectedLanguageName;

  @override
  String get languageName => _selectedLanguageName;

  @override
  TextEditingController get sourceTextController => _termController;

  @override
  TextEditingController get translationTextController => _translationController;

  @override
  void initState() {
    super.initState();
    _status = widget.term.status;
    _selectedLanguageId = widget.languageId;
    _selectedLanguageName = widget.languageName;
    _termController = TextEditingController(text: widget.term.lowerText);
    _translationController = TextEditingController();
    _romanizationController = TextEditingController(
      text: widget.term.romanization,
    );
    _sentenceController = TextEditingController(
      text: widget.term.sentence.isEmpty
          ? widget.sentence
          : widget.term.sentence,
    );
    _loadTranslations();
    checkTranslationProviders();
    _loadLanguages();
  }

  Future<void> _loadTranslations() async {
    if (widget.term.id != null) {
      final translations = await db.translations
          .getByTermId(widget.term.id!);
      if (mounted) {
        setState(() {
          _translations = translations;
          // If no translations but old translation field has data, create one
          if (_translations.isEmpty && widget.term.translation.isNotEmpty) {
            _translations = [
              Translation(
                termId: widget.term.id!,
                meaning: widget.term.translation,
              ),
            ];
          }
        });
        // Load base translations
        _loadBaseTranslations();
      }
    } else if (widget.term.translation.isNotEmpty) {
      // New term with pre-filled translation
      setState(() {
        _translations = [
          Translation(termId: 0, meaning: widget.term.translation),
        ];
      });
    }
  }

  Future<void> _loadBaseTranslations() async {
    final baseTranslationIds = _translations
        .where((t) => t.baseTranslationId != null)
        .map((t) => t.baseTranslationId!)
        .toSet();

    for (final translationId in baseTranslationIds) {
      if (!_baseTranslations.containsKey(translationId)) {
        final translation = await db.translations.getById(translationId);
        if (translation != null && mounted) {
          final term = await db.terms.getById(translation.termId);
          if (term != null && mounted) {
            setState(() => _baseTranslations[translationId] = (translation: translation, term: term));
          }
        }
      }
    }
  }

  Future<void> _selectBaseTranslationForTranslation(int index) async {
    // First, select a term
    final selectedTerm = await showDialog<Term?>(
      context: context,
      builder: (ctx) => BaseTermSearchDialog(
        languageId: _selectedLanguageId,
        languageName: _selectedLanguageName,
        excludeTermId: widget.term.id,
        initialWord: _termController.text,
      ),
    );

    if (selectedTerm == null || !mounted) return;

    // Load translations for the selected term
    var termTranslations = await db.translations.getByTermId(selectedTerm.id!);

    if (!mounted) return;

    // If no translations in DB but term has legacy translation, create one and save it
    if (termTranslations.isEmpty && selectedTerm.translation.isNotEmpty) {
      final legacyTranslation = Translation(
        termId: selectedTerm.id!,
        meaning: selectedTerm.translation,
      );
      // Save the legacy translation to the translations table
      await db.translations.replaceForTerm(
        selectedTerm.id!,
        [legacyTranslation],
      );
      // Reload to get the saved translation with its new ID
      termTranslations = await db.translations.getByTermId(selectedTerm.id!);
      if (!mounted) return;
    }

    // If still no translations, can't link
    if (termTranslations.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No translations available for this term')),
        );
      }
      return;
    }

    // If term has only one translation, use it directly
    if (termTranslations.length == 1) {
      final baseTranslation = termTranslations.first;
      setState(() {
        // Read current translation at setState time to preserve any changes made during dialog
        _translations[index] = _translations[index].copyWith(
          baseTranslationId: baseTranslation.id,
        );
        _baseTranslations[baseTranslation.id!] = (translation: baseTranslation, term: selectedTerm);
      });
      return;
    }

    // Show picker for multiple translations
    final selectedTranslation = await showDialog<Translation?>(
      context: context,
      builder: (ctx) => _TranslationPickerDialog(
        term: selectedTerm,
        translations: termTranslations,
      ),
    );

    if (selectedTranslation != null && mounted) {
      setState(() {
        // Read current translation at setState time to preserve any changes made during dialog
        _translations[index] = _translations[index].copyWith(
          baseTranslationId: selectedTranslation.id,
        );
        _baseTranslations[selectedTranslation.id!] = (translation: selectedTranslation, term: selectedTerm);
      });
    }
  }

  void _removeBaseTranslationFromTranslation(int index) {
    final translation = _translations[index];
    setState(() {
      _translations[index] = translation.copyWith(
        clearBaseTranslationId: true,
      );
    });
  }

  Widget _buildBaseTermSelector(AppLocalizations l10n, int index, Translation translation) {
    final baseInfo = translation.baseTranslationId != null
        ? _baseTranslations[translation.baseTranslationId!]
        : null;

    if (baseInfo != null) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.baseForm,
                  style: TextStyle(
                    fontSize: AppConstants.fontSizeCaption,
                    color: AppConstants.subtitleColor,
                  ),
                ),
                Text(
                  baseInfo.term.lowerText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  baseInfo.translation.meaning,
                  style: TextStyle(
                    fontSize: AppConstants.fontSizeCaption,
                    color: AppConstants.subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: _TermDialogConstants.closeIconSize,
              color: AppConstants.subtitleColor,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _removeBaseTranslationFromTranslation(index),
          ),
        ],
      );
    }

    return InkWell(
      onTap: () => _selectBaseTranslationForTranslation(index),
      child: Row(
        children: [
          Icon(
            Icons.add_link,
            size: AppConstants.iconSizeS,
            color: AppConstants.subtitleColor,
          ),
          const SizedBox(width: AppConstants.spacingXS),
          Text(
            l10n.baseForm,
            style: TextStyle(color: AppConstants.subtitleColor),
          ),
        ],
      ),
    );
  }

  void _addTranslation() {
    setState(() {
      _translations.add(Translation(
        termId: widget.term.id ?? 0,
        meaning: '',
        sortOrder: _translations.length,
      ));
    });
  }

  void _removeTranslation(int index) {
    setState(() {
      _translations.removeAt(index);
    });
  }

  void _updateTranslation(int index, Translation updated, {bool rebuild = false}) {
    if (rebuild) {
      setState(() {
        _translations[index] = updated;
      });
    } else {
      // Don't call setState for text changes - it would reset the TextFormField
      _translations[index] = updated;
    }
  }

  Future<void> _loadLanguages() async {
    final languages = await db.languages.getAll();
    if (mounted) {
      setState(() => _languages = languages);
    }
  }

  Widget _buildLanguageLabel(AppLocalizations l10n) {
    final currentLang = _languages.cast<Language?>().firstWhere(
      (l) => l!.id == _selectedLanguageId,
      orElse: () => null,
    );
    final flag = currentLang?.flagEmoji ?? '';
    final name = currentLang?.name ?? _selectedLanguageName;

    final label = Padding(
      padding: const EdgeInsets.only(top: AppConstants.spacingXS),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (flag.isNotEmpty) ...[
            Text(flag),
            const SizedBox(width: AppConstants.spacingXS),
          ],
          Text(
            name,
            style: TextStyle(
              fontSize: AppConstants.fontSizeCaption,
              color: AppConstants.subtitleColor,
            ),
          ),
          if (_languages.length > 1)
            Icon(
              Icons.arrow_drop_down,
              size: AppConstants.iconSizeS,
              color: AppConstants.subtitleColor,
            ),
        ],
      ),
    );

    if (_languages.length <= 1) return label;

    return PopupMenuButton<Language>(
      onSelected: (lang) {
        setState(() {
          _selectedLanguageId = lang.id!;
          _selectedLanguageName = lang.name;
        });
      },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      position: PopupMenuPosition.under,
      child: label,
      itemBuilder: (context) => _languages.map((lang) {
        final isDeepLSupported =
            DeepLService.getDeepLLanguageCode(lang.name) != null;
        final isLTSupported =
            LibreTranslateService.getLanguageCode(lang.name) != null;
        final isSupported =
            (hasDeepL && isDeepLSupported) ||
            (hasLibreTranslate && isLTSupported);
        return PopupMenuItem(
          value: lang,
          child: Row(
            children: [
              if (lang.flagEmoji.isNotEmpty) ...[
                Text(lang.flagEmoji),
                const SizedBox(width: AppConstants.spacingS),
              ],
              Text(
                lang.name +
                    (hasAnyTranslationProvider && !isSupported
                        ? l10n.noDeepL
                        : ''),
                style: TextStyle(
                  color: hasAnyTranslationProvider && !isSupported
                      ? Colors.grey
                      : null,
                ),
              ),
              if (lang.id == _selectedLanguageId) ...[
                const Spacer(),
                const Icon(Icons.check, size: 18),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTranslationsSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.translations,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasAnyTranslationProvider)
                  if (isTranslating)
                    const SizedBox(
                      width: AppConstants.progressIndicatorSizeS,
                      height: AppConstants.progressIndicatorSizeS,
                      child: CircularProgressIndicator(
                        strokeWidth: AppConstants.progressStrokeWidth,
                      ),
                    )
                  else if (hasMultipleTranslationProviders)
                    PopupMenuButton<TranslationProvider>(
                      icon: const Icon(Icons.translate, size: AppConstants.iconSizeS),
                      tooltip: l10n.translate,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: _translateAndAddFirstWithProvider,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: TranslationProvider.deepL,
                          child: Text(l10n.translateWithDeepL),
                        ),
                        PopupMenuItem(
                          value: TranslationProvider.libreTranslate,
                          child: Text(l10n.translateWithLibreTranslate),
                        ),
                      ],
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.translate, size: AppConstants.iconSizeS),
                      tooltip: hasDeepL ? l10n.translateWithDeepL : l10n.translateWithLibreTranslate,
                      onPressed: () => _translateAndAddFirstWithProvider(
                        hasDeepL ? TranslationProvider.deepL : TranslationProvider.libreTranslate,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                const SizedBox(width: AppConstants.spacingS),
                IconButton(
                  icon: const Icon(Icons.add, size: AppConstants.iconSizeS),
                  tooltip: l10n.addTranslation,
                  onPressed: _addTranslation,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingS),
        if (_translations.isEmpty)
          Text(
            l10n.addTranslation,
            style: TextStyle(
              color: AppConstants.subtitleColor,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          ..._translations.asMap().entries.map((entry) {
            final index = entry.key;
            final translation = entry.value;
            return _buildTranslationItem(l10n, index, translation);
          }),
      ],
    );
  }

  Widget _buildTranslationItem(
    AppLocalizations l10n,
    int index,
    Translation translation,
  ) {
    // Use a stable key based on the translation's id or index
    final itemKey = ValueKey(translation.id ?? 'new_$index');
    return Container(
      key: itemKey,
      margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
      padding: const EdgeInsets.all(AppConstants.spacingS),
      decoration: BoxDecoration(
        border: Border.all(color: AppConstants.borderColor),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: translation.meaning,
                  decoration: InputDecoration(
                    labelText: l10n.meaning,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    // Use current list value to preserve baseTranslationId and other fields
                    _updateTranslation(
                      index,
                      _translations[index].copyWith(meaning: value),
                    );
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: _TermDialogConstants.closeIconSize,
                  color: AppConstants.subtitleColor,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _removeTranslation(index),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingXS),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String?>(
                  value: translation.partOfSpeech,
                  isExpanded: true,
                  underline: const SizedBox(),
                  hint: Text(l10n.partOfSpeech, style: TextStyle(color: AppConstants.subtitleColor)),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('—', style: TextStyle(color: AppConstants.subtitleColor)),
                    ),
                    ...PartOfSpeech.all.map((pos) => DropdownMenuItem(
                          value: pos,
                          child: Text(PartOfSpeech.localizedNameFor(pos, l10n)),
                        )),
                  ],
                  onChanged: (value) {
                    // Use current list value to preserve baseTranslationId and other fields
                    _updateTranslation(
                      index,
                      _translations[index].copyWith(
                        partOfSpeech: value,
                        clearPartOfSpeech: value == null,
                      ),
                      rebuild: true,
                    );
                  },
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: _buildBaseTermSelector(l10n, index, translation),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _translateAndAddFirstWithProvider(TranslationProvider provider) async {
    _translationController.text = '';
    await translateWithProvider(provider);
    if (_translationController.text.isNotEmpty) {
      setState(() {
        _translations.add(Translation(
          termId: widget.term.id ?? 0,
          meaning: _translationController.text,
          sortOrder: 0,
        ));
      });
    }
  }

  @override
  void dispose() {
    _termController.dispose();
    _translationController.dispose();
    _romanizationController.dispose();
    _sentenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.term.lowerText,
                  style: const TextStyle(fontSize: AppConstants.fontSizeTitle),
                ),
                if (widget.term.text != widget.term.lowerText)
                  Text(
                    l10n.original(widget.term.text),
                    style: TextStyle(
                      fontSize: AppConstants.fontSizeCaption,
                      color: AppConstants.subtitleColor,
                    ),
                  ),
                _buildLanguageLabel(l10n),
              ],
            ),
          ),
          if (widget.languageCode.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.volume_up),
              tooltip: l10n.pronounce,
              onPressed: () => ttsService.speak(
                widget.term.lowerText,
                widget.languageCode,
              ),
            ),
          if (widget.dictionaries.isNotEmpty)
            PopupMenuButton<Dictionary>(
              icon: const Icon(Icons.search),
              tooltip: l10n.lookupInDictionary,
              onSelected: (dict) {
                widget.onLookup(context, dict);
              },
              itemBuilder: (context) => widget.dictionaries
                  .map(
                    (dict) =>
                        PopupMenuItem(value: dict, child: Text(dict.name)),
                  )
                  .toList(),
            ),
        ],
      ),
      content: SizedBox(
        width: AppConstants.dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Term field (editable)
              TextField(
                controller: _termController,
                decoration: InputDecoration(
                  labelText: l10n.term,
                  border: const OutlineInputBorder(),
                  suffixIcon: widget.term.text != widget.term.lowerText
                      ? IconButton(
                          icon: const Icon(Icons.history),
                          tooltip: l10n.useOriginal(widget.term.text),
                          onPressed: () {
                            _termController.text = widget.term.text;
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: AppConstants.spacingM),

              // Status display (read-only) with ignore/well-known actions
              Row(
                children: [
                  Text(
                    l10n.status,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: AppConstants.spacingS),
                  Chip(
                    avatar: CircleAvatar(
                      backgroundColor: TermStatus.colorFor(_status),
                      radius: AppConstants.spacingS,
                    ),
                    label: Text(
                      TermStatus.localizedNameFor(_status, l10n),
                      style: const TextStyle(fontSize: AppConstants.fontSizeCaption),
                    ),
                  ),
                  const Spacer(),
                  if (_status == TermStatus.ignored)
                    TextButton(
                      onPressed: () => setState(() => _status = TermStatus.unknown),
                      child: Text(l10n.unignore),
                    )
                  else ...[
                    if (_status != TermStatus.wellKnown)
                      TextButton(
                        onPressed: () => setState(() => _status = TermStatus.wellKnown),
                        child: Text(l10n.markWellKnown),
                      ),
                    TextButton(
                      onPressed: () => setState(() => _status = TermStatus.ignored),
                      child: Text(l10n.ignore),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppConstants.spacingL),

              // Translations section
              _buildTranslationsSection(l10n),
              const SizedBox(height: AppConstants.spacingM),

              // Romanization field
              TextField(
                controller: _romanizationController,
                decoration: InputDecoration(
                  labelText: l10n.romanizationPronunciation,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppConstants.spacingM),

              // Sentence field
              TextField(
                controller: _sentenceController,
                decoration: InputDecoration(
                  labelText: l10n.exampleSentence,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: _TermDialogConstants.sentenceMaxLines,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.term.id != null)
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: Text(l10n.delete),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            final editedTerm = _termController.text.trim().toLowerCase();
            // Use first translation meaning for legacy translation field
            final legacyTranslation = _translations.isNotEmpty
                ? _translations.first.meaning
                : '';
            final updatedTerm = widget.term.copyWith(
              languageId: _selectedLanguageId,
              text: editedTerm,
              lowerText: editedTerm,
              status: _status,
              translation: legacyTranslation,
              romanization: _romanizationController.text,
              sentence: _sentenceController.text,
              lastAccessed: DateTime.now(),
            );
            Navigator.pop(
              context,
              TermDialogResult(
                term: updatedTerm,
                translations: _translations,
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }

}

/// Dialog for picking a translation from a term
class _TranslationPickerDialog extends StatelessWidget {
  final Term term;
  final List<Translation> translations;

  const _TranslationPickerDialog({
    required this.term,
    required this.translations,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(term.lowerText),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: translations.map((t) {
            return ListTile(
              title: Text(t.meaning),
              subtitle: t.partOfSpeech != null
                  ? Text(PartOfSpeech.localizedNameFor(t.partOfSpeech!, l10n))
                  : null,
              onTap: () => Navigator.pop(context, t),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
