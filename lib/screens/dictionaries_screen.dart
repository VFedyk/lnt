// FILE: lib/screens/dictionaries_screen.dart
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/dictionary.dart';
import '../service_locator.dart';
import '../widgets/dictionary_dialog.dart';

class _DictionariesScreenConstants {
  static const double listPadding = 16.0;
  static const double cardBottomMargin = 8.0;
  static const double iconSpacing = 8.0;
  static const double subtitleFontSize = 12.0;
  static const double emptyIconSize = 64.0;
  static const double emptyTextSpacing = 16.0;
  static const double emptySubtextSpacing = 8.0;
  static const double helpSectionSpacing = 16.0;
  static const double helpStepSpacing = 8.0;
  static const double exampleUrlFontSize = 12.0;
  static const int urlMaxLines = 1;
}

class DictionariesScreen extends StatefulWidget {
  final Language language;

  const DictionariesScreen({super.key, required this.language});

  @override
  State<DictionariesScreen> createState() => _DictionariesScreenState();
}

class _DictionariesScreenState extends State<DictionariesScreen> {
  List<Dictionary> _dictionaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDictionaries();
  }

  Future<void> _loadDictionaries() async {
    setState(() => _isLoading = true);
    final dicts = await db.getDictionaries(
      languageId: widget.language.id!,
    );
    setState(() {
      _dictionaries = dicts;
      _isLoading = false;
    });
  }

  Future<void> _addOrEditDictionary([Dictionary? dictionary]) async {
    final result = await showDialog<Dictionary>(
      context: context,
      builder: (context) => DictionaryDialog(
        languageId: widget.language.id!,
        languageCode: widget.language.languageCode,
        dictionary: dictionary,
      ),
    );

    if (result != null) {
      if (dictionary == null) {
        await db.createDictionary(result);
      } else {
        await db.updateDictionary(result);
      }
      _loadDictionaries();
    }
  }

  Future<void> _deleteDictionary(Dictionary dictionary) async {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteDictionary),
        content: Text(l10n.deleteDictionaryConfirm(dictionary.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await db.deleteDictionary(dictionary.id!);
      _loadDictionaries();
    }
  }

  Future<void> _toggleActive(Dictionary dictionary) async {
    final updated = dictionary.copyWith(isActive: !dictionary.isActive);
    await db.updateDictionary(updated);
    _loadDictionaries();
  }

  Future<void> _reorderDictionaries(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _dictionaries.removeAt(oldIndex);
      _dictionaries.insert(newIndex, item);
    });

    await db.reorderDictionaries(_dictionaries);
    _loadDictionaries();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dictionariesTitle(widget.language.name)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: l10n.help,
            onPressed: () => _showHelp(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dictionaries.isEmpty
          ? _buildEmptyState()
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(
                _DictionariesScreenConstants.listPadding,
              ),
              itemCount: _dictionaries.length,
              onReorder: _reorderDictionaries,
              itemBuilder: (context, index) {
                final dict = _dictionaries[index];
                return Card(
                  key: ValueKey(dict.id),
                  margin: const EdgeInsets.only(
                    bottom: _DictionariesScreenConstants.cardBottomMargin,
                  ),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.drag_handle, color: colorScheme.outline),
                        const SizedBox(
                          width: _DictionariesScreenConstants.iconSpacing,
                        ),
                        CircleAvatar(
                          backgroundColor: dict.isActive
                              ? colorScheme.primary
                              : colorScheme.outline,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(color: colorScheme.onPrimary),
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      dict.name,
                      style: TextStyle(
                        decoration: dict.isActive
                            ? TextDecoration.none
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Text(
                      dict.url,
                      maxLines: _DictionariesScreenConstants.urlMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _DictionariesScreenConstants.subtitleFontSize,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _addOrEditDictionary(dict);
                            break;
                          case 'toggle':
                            _toggleActive(dict);
                            break;
                          case 'delete':
                            _deleteDictionary(dict);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit),
                              const SizedBox(
                                width: _DictionariesScreenConstants.iconSpacing,
                              ),
                              Text(l10n.edit),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(
                                dict.isActive
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              const SizedBox(
                                width: _DictionariesScreenConstants.iconSpacing,
                              ),
                              Text(
                                dict.isActive ? l10n.deactivate : l10n.activate,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: colorScheme.error),
                              const SizedBox(
                                width: _DictionariesScreenConstants.iconSpacing,
                              ),
                              Text(
                                l10n.delete,
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditDictionary(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book,
            size: _DictionariesScreenConstants.emptyIconSize,
            color: colorScheme.outline,
          ),
          const SizedBox(height: _DictionariesScreenConstants.emptyTextSpacing),
          Text(l10n.noDictionariesYet),
          const SizedBox(
            height: _DictionariesScreenConstants.emptySubtextSpacing,
          ),
          Text(
            l10n.addDictionariesFor(widget.language.name),
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: _DictionariesScreenConstants.emptyTextSpacing),
          ElevatedButton.icon(
            onPressed: () => _addOrEditDictionary(),
            icon: const Icon(Icons.add),
            label: Text(l10n.addDictionary),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.dictionaryHelp),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.howToUse,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(
                height: _DictionariesScreenConstants.helpStepSpacing,
              ),
              Text(l10n.dictionaryHelpStep1),
              Text(l10n.dictionaryHelpStep2),
              Text(l10n.dictionaryHelpStep3),
              Text(l10n.dictionaryHelpStep4),
              const SizedBox(
                height: _DictionariesScreenConstants.helpSectionSpacing,
              ),
              Text(
                l10n.exampleUrls,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(
                height: _DictionariesScreenConstants.helpStepSpacing,
              ),
              const Text(
                'WordReference:\nhttps://www.wordreference.com/es/en/translation.asp?spen=###',
                style: TextStyle(
                  fontSize: _DictionariesScreenConstants.exampleUrlFontSize,
                ),
              ),
              const SizedBox(
                height: _DictionariesScreenConstants.helpStepSpacing,
              ),
              const Text(
                'Jisho (Japanese):\nhttps://jisho.org/search/###',
                style: TextStyle(
                  fontSize: _DictionariesScreenConstants.exampleUrlFontSize,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.gotIt),
          ),
        ],
      ),
    );
  }
}
