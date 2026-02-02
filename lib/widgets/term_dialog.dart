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

abstract class _TermDialogConstants {
  static const double closeIconSize = 18.0;
  static const double addLinkIconSize = 18.0;
  static const int primaryAlpha = 100;
  static const double chipBackgroundAlpha = 0.2;
  static const int translationMaxLines = 2;
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
  late TextEditingController _translationController;
  late TextEditingController _romanizationController;
  late TextEditingController _sentenceController;

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
    _translationController = TextEditingController(
      text: widget.term.translation,
    );
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
    checkDeepLKey();
    _loadLanguages();
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
              TextField(
                controller: _translationController,
                decoration: InputDecoration(
                  labelText: l10n.translation,
                  border: const OutlineInputBorder(),
                  suffixIcon: hasDeepLKey
                      ? IconButton(
                          icon: isTranslating
                              ? const SizedBox(
                                  width: AppConstants.progressIndicatorSize,
                                  height: AppConstants.progressIndicatorSize,
                                  child: CircularProgressIndicator(
                                    strokeWidth:
                                        AppConstants.progressStrokeWidth,
                                  ),
                                )
                              : const Icon(Icons.translate),
                          tooltip: l10n.translateWithDeepL,
                          onPressed: isTranslating ? null : translateTerm,
                        )
                      : null,
                ),
                maxLines: _TermDialogConstants.translationMaxLines,
              ),
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
            final updatedTerm = widget.term.copyWith(
              languageId: _selectedLanguageId,
              text: editedTerm,
              lowerText: editedTerm,
              status: _status,
              translation: _translationController.text,
              romanization: _romanizationController.text,
              sentence: _sentenceController.text,
              lastAccessed: DateTime.now(),
              baseTermId: _baseTermId,
              clearBaseTermId:
                  _baseTermId == null && widget.term.baseTermId != null,
            );
            Navigator.pop(context, updatedTerm);
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
