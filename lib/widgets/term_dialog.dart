import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/term.dart';
import '../models/dictionary.dart';
import '../models/language.dart';
import '../services/database_service.dart';
import '../services/deepl_service.dart';
import '../utils/constants.dart';
import 'base_term_search_dialog.dart';
import 'deepl_translation_mixin.dart';

/// Result returned from TermDialog containing both term and translations
class TermDialogResult {
  final Term term;
  final List<Translation> translations;

  TermDialogResult({required this.term, required this.translations});
}

abstract class _TermDialogConstants {
  static const double closeIconSize = 18.0;
  static const double addLinkIconSize = 18.0;
  static const int primaryAlpha = 100;
  static const double chipBackgroundAlpha = 0.2;
  static const int sentenceMaxLines = 3;
  static final Color wellKnownTextColor = Colors.blue.shade700;
  static final Color wellKnownBorderColor = Colors.blue.shade300;
}

class TermDialog extends StatefulWidget {
  final Term term;
  final String sentence;
  final List<Dictionary> dictionaries;
  final Function(BuildContext, Dictionary) onLookup;
  final int languageId;
  final String languageName;

  const TermDialog({
    super.key,
    required this.term,
    required this.sentence,
    required this.dictionaries,
    required this.onLookup,
    required this.languageId,
    required this.languageName,
  });

  @override
  State<TermDialog> createState() => _TermDialogState();
}

class _TermDialogState extends State<TermDialog> with DeepLTranslationMixin {
  late int _status;
  late TextEditingController _termController;
  late TextEditingController _romanizationController;
  late TextEditingController _sentenceController;

  // Multiple translations support
  List<Translation> _translations = [];
  // baseTranslationId -> (translation, its parent term)
  final Map<int, ({Translation translation, Term term})> _baseTranslations = {};
  late TextEditingController _translationController;

  // Base term linking
  int? _baseTermId;
  Term? _baseTerm;
  List<Term> _linkedTerms = [];

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
    _baseTermId = widget.term.baseTermId;
    _loadBaseTermAndLinkedTerms();
    _loadTranslations();
    checkDeepLKey();
    _loadLanguages();
  }

  Future<void> _loadTranslations() async {
    if (widget.term.id != null) {
      final translations = await DatabaseService.instance.translations
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
        final translation = await DatabaseService.instance.translations.getById(translationId);
        if (translation != null && mounted) {
          final term = await DatabaseService.instance.getTerm(translation.termId);
          if (term != null && mounted) {
            setState(() => _baseTranslations[translationId] = (translation: translation, term: term));
          }
        }
      }
    }
  }

  Future<void> _selectBaseTranslationForTranslation(int index) async {
    final currentTranslation = _translations[index];

    // First, select a term
    final selectedTerm = await showDialog<Term?>(
      context: context,
      builder: (ctx) => BaseTermSearchDialog(
        languageId: _selectedLanguageId,
        languageName: _selectedLanguageName,
        excludeTermId: widget.term.id,
      ),
    );

    if (selectedTerm == null || !mounted) return;

    // Load translations for the selected term
    final termTranslations = await DatabaseService.instance.translations.getByTermId(selectedTerm.id!);

    if (!mounted) return;

    // If term has only one translation, use it directly
    if (termTranslations.length == 1) {
      final baseTranslation = termTranslations.first;
      setState(() {
        _translations[index] = currentTranslation.copyWith(
          baseTranslationId: baseTranslation.id,
        );
        _baseTranslations[baseTranslation.id!] = (translation: baseTranslation, term: selectedTerm);
      });
      return;
    }

    // If no translations saved, can't link
    if (termTranslations.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No translations available for this term')),
        );
      }
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
        _translations[index] = currentTranslation.copyWith(
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
    final languages = await DatabaseService.instance.getLanguages();
    if (mounted) {
      setState(() => _languages = languages);
    }
  }

  Future<void> _loadBaseTermAndLinkedTerms() async {
    if (_baseTermId != null) {
      final baseTerm = await DatabaseService.instance.getTerm(_baseTermId!);
      if (mounted) {
        setState(() => _baseTerm = baseTerm);
      }
    }
    if (widget.term.id != null) {
      final linked = await DatabaseService.instance.getLinkedTerms(
        widget.term.id!,
      );
      if (mounted) {
        setState(() => _linkedTerms = linked);
      }
    }
  }

  Future<void> _selectBaseTerm() async {
    final selectedTerm = await showDialog<Term>(
      context: context,
      builder: (context) => BaseTermSearchDialog(
        languageId: widget.languageId,
        languageName: widget.languageName,
        excludeTermId: widget.term.id,
        initialWord: widget.term.lowerText,
      ),
    );
    if (selectedTerm != null && mounted) {
      setState(() {
        _baseTermId = selectedTerm.id;
        _baseTerm = selectedTerm;
      });
    }
  }

  void _removeBaseTerm() {
    setState(() {
      _baseTermId = null;
      _baseTerm = null;
    });
  }

  Widget _buildBaseTermSection() {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_baseTerm != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingM,
              vertical: AppConstants.spacingS,
            ),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
              border: Border.all(
                color: colorScheme.primary.withAlpha(
                  _TermDialogConstants.primaryAlpha,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.link,
                  size: AppConstants.iconSizeS,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  l10n.base,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Text(
                    _baseTerm!.lowerText,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: _TermDialogConstants.closeIconSize,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _removeBaseTerm,
                  tooltip: l10n.removeLink,
                ),
              ],
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: _selectBaseTerm,
            icon: const Icon(
              Icons.add_link,
              size: _TermDialogConstants.addLinkIconSize,
            ),
            label: Text(l10n.linkToBaseForm),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.outline),
            ),
          ),

        if (_linkedTerms.isNotEmpty) ...[
          const SizedBox(height: AppConstants.spacingS),
          Text(
            l10n.forms(_linkedTerms.map((t) => t.lowerText).join(", ")),
            style: TextStyle(
              fontSize: AppConstants.fontSizeCaption,
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
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
                if (hasDeepLKey)
                  IconButton(
                    icon: isTranslating
                        ? const SizedBox(
                            width: AppConstants.progressIndicatorSizeS,
                            height: AppConstants.progressIndicatorSizeS,
                            child: CircularProgressIndicator(
                              strokeWidth: AppConstants.progressStrokeWidth,
                            ),
                          )
                        : const Icon(Icons.translate, size: AppConstants.iconSizeS),
                    tooltip: l10n.translateWithDeepL,
                    onPressed: isTranslating ? null : _translateAndAddFirst,
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
                    _updateTranslation(
                      index,
                      translation.copyWith(meaning: value),
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
                    _updateTranslation(
                      index,
                      translation.copyWith(
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

  Future<void> _translateAndAddFirst() async {
    _translationController.text = '';
    await translateTerm();
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
              ],
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

              // Base term linking
              _buildBaseTermSection(),
              const SizedBox(height: AppConstants.spacingM),

              // Status selector
              Text(
                l10n.status,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Wrap(
                spacing: AppConstants.spacingS,
                runSpacing: AppConstants.spacingS,
                children: [
                  _buildStatusChip(
                    TermStatus.ignored,
                    l10n.statusIgnored,
                    TermStatus.colorFor(TermStatus.ignored),
                  ),
                  _buildStatusChip(
                    TermStatus.unknown,
                    l10n.statusUnknown,
                    TermStatus.colorFor(TermStatus.unknown),
                  ),
                  _buildStatusChip(
                    TermStatus.learning2,
                    l10n.statusLearning2,
                    TermStatus.colorFor(TermStatus.learning2),
                  ),
                  _buildStatusChip(
                    TermStatus.learning3,
                    l10n.statusLearning3,
                    TermStatus.colorFor(TermStatus.learning3),
                  ),
                  _buildStatusChip(
                    TermStatus.learning4,
                    l10n.statusLearning4,
                    TermStatus.colorFor(TermStatus.learning4),
                  ),
                  _buildStatusChip(
                    TermStatus.known,
                    l10n.statusKnown,
                    TermStatus.colorFor(TermStatus.known),
                  ),
                  _buildStatusChip(
                    TermStatus.wellKnown,
                    l10n.statusWellKnown,
                    TermStatus.colorFor(TermStatus.wellKnown),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingL),

              // Language selector
              if (_languages.length > 1) ...[
                Row(
                  children: [
                    Text(
                      l10n.language,
                      style: const TextStyle(
                        fontSize: AppConstants.fontSizeCaption,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingM,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppConstants.borderColor,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppConstants.borderRadiusS,
                          ),
                        ),
                        child: DropdownButton<int>(
                          value: _selectedLanguageId,
                          isExpanded: true,
                          isDense: true,
                          underline: const SizedBox(),
                          items: _languages.map((lang) {
                            final isSupported =
                                DeepLService.getDeepLLanguageCode(lang.name) !=
                                null;
                            return DropdownMenuItem(
                              value: lang.id,
                              child: Text(
                                lang.name +
                                    (hasDeepLKey && !isSupported
                                        ? l10n.noDeepL
                                        : ''),
                                style: TextStyle(
                                  fontSize: AppConstants.fontSizeBody,
                                  color: hasDeepLKey && !isSupported
                                      ? Colors.grey
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              final lang = _languages.firstWhere(
                                (l) => l.id == value,
                              );
                              setState(() {
                                _selectedLanguageId = value;
                                _selectedLanguageName = lang.name;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingM),
              ],
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
              baseTermId: _baseTermId,
              clearBaseTermId:
                  _baseTermId == null && widget.term.baseTermId != null,
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

  Widget _buildStatusChip(int status, String label, Color color) {
    final isSelected = _status == status;
    final isIgnored = status == TermStatus.ignored;
    final isWellKnown = status == TermStatus.wellKnown;

    if ((isIgnored || isWellKnown) && !isSelected) {
      return ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: isIgnored
                ? AppConstants.subtitleColor
                : _TermDialogConstants.wellKnownTextColor,
            fontSize: AppConstants.fontSizeCaption,
          ),
        ),
        selected: false,
        backgroundColor: Colors.transparent,
        side: BorderSide(
          color: isIgnored
              ? AppConstants.borderColor
              : _TermDialogConstants.wellKnownBorderColor,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() => _status = status);
          }
        },
      );
    }

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontSize: AppConstants.fontSizeCaption,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: color.withValues(
        alpha: _TermDialogConstants.chipBackgroundAlpha,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _status = status);
        }
      },
      avatar: isSelected
          ? const Icon(
              Icons.check,
              color: Colors.white,
              size: AppConstants.iconSizeS,
            )
          : null,
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
