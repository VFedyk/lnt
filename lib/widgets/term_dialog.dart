import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/term.dart';
import '../models/dictionary.dart';
import '../models/language.dart';
import '../services/database_service.dart';
import '../services/deepl_service.dart';
import 'base_term_search_dialog.dart';
import 'deepl_translation_mixin.dart';

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
    // Load base term if this term is linked to one
    if (_baseTermId != null) {
      final baseTerm = await DatabaseService.instance.getTerm(_baseTermId!);
      if (mounted) {
        setState(() => _baseTerm = baseTerm);
      }
    }
    // Load linked terms if this term IS a base term (has an id)
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
        // Show base term if linked
        if (_baseTerm != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.primary.withAlpha(100)),
            ),
            child: Row(
              children: [
                Icon(Icons.link, size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
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
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _removeBaseTerm,
                  tooltip: l10n.removeLink,
                ),
              ],
            ),
          )
        else
          // Show button to link to base term
          OutlinedButton.icon(
            onPressed: _selectBaseTerm,
            icon: const Icon(Icons.add_link, size: 18),
            label: Text(l10n.linkToBaseForm),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.outline),
            ),
          ),

        // Show linked terms if this is a base term
        if (_linkedTerms.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            l10n.forms(_linkedTerms.map((t) => t.lowerText).join(", ")),
            style: TextStyle(
              fontSize: 12,
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
                  style: const TextStyle(fontSize: 24),
                ),
                if (widget.term.text != widget.term.lowerText)
                  Text(
                    l10n.original(widget.term.text),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
        width: 736,
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
              const SizedBox(height: 12),

              // Base term linking
              _buildBaseTermSection(),
              const SizedBox(height: 12),

              // Status selector
              Text(
                l10n.status,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusChip(0, l10n.statusIgnored, Colors.grey.shade400),
                  _buildStatusChip(1, l10n.statusUnknown, Colors.red.shade400),
                  _buildStatusChip(
                    2,
                    l10n.statusLearning2,
                    Colors.orange.shade400,
                  ),
                  _buildStatusChip(
                    3,
                    l10n.statusLearning3,
                    Colors.yellow.shade700,
                  ),
                  _buildStatusChip(
                    4,
                    l10n.statusLearning4,
                    Colors.lightGreen.shade500,
                  ),
                  _buildStatusChip(5, l10n.statusKnown, Colors.green.shade600),
                  _buildStatusChip(
                    99,
                    l10n.statusWellKnown,
                    Colors.blue.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Language selector (for saving to different language dictionary)
              if (_languages.length > 1) ...[
                Row(
                  children: [
                    Text(l10n.language, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
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
                                  fontSize: 14,
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
                const SizedBox(height: 12),
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
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.translate),
                          tooltip: l10n.translateWithDeepL,
                          onPressed: isTranslating ? null : translateTerm,
                        )
                      : null,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // Romanization field
              TextField(
                controller: _romanizationController,
                decoration: InputDecoration(
                  labelText: l10n.romanizationPronunciation,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Sentence field
              TextField(
                controller: _sentenceController,
                decoration: InputDecoration(
                  labelText: l10n.exampleSentence,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
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

    // For ignored and well-known when not selected, show as plain text
    if ((isIgnored || isWellKnown) && !isSelected) {
      return ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: isIgnored ? Colors.grey.shade600 : Colors.blue.shade700,
            fontSize: 12,
          ),
        ),
        selected: false,
        backgroundColor: Colors.transparent,
        side: BorderSide(
          color: isIgnored ? Colors.grey.shade400 : Colors.blue.shade300,
          width: 1,
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
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.2),
      onSelected: (selected) {
        if (selected) {
          setState(() => _status = status);
        }
      },
      avatar: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }
}
