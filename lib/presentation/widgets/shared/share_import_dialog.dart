import 'package:flutter/material.dart';

import '../../../domain/entities/collection.dart';
import '../../../domain/entities/language.dart';
import '../../../domain/entities/text_document.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../service_locator.dart';
import '../../../services/url_import_service.dart';

/// Dialog shown when the user shares a URL to LNT from another app.
/// Starts fetching the URL immediately and lets the user pick a language
/// and collection while the fetch runs in the background.
class ShareImportDialog extends StatefulWidget {
  final String url;

  const ShareImportDialog({super.key, required this.url});

  @override
  State<ShareImportDialog> createState() => _ShareImportDialogState();
}

class _ShareImportDialogState extends State<ShareImportDialog> {
  late Future<UrlImportResult> _fetchFuture;

  List<Language> _languages = [];
  Language? _selectedLanguage;
  List<Collection> _collections = [];
  String? _selectedCollectionId; // null = root
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchFuture = UrlImportService().importFromUrl(widget.url);
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    final langs = await db.languages.getAll();
    if (!mounted) return;
    setState(() {
      _languages = langs;
      if (langs.length == 1) {
        _selectedLanguage = langs.first;
        _loadCollections(langs.first);
      }
    });
  }

  Future<void> _loadCollections(Language language) async {
    final cols = await db.collections.getAll(languageId: language.id);
    if (!mounted) return;
    setState(() {
      _collections = cols;
      _selectedCollectionId = null;
    });
  }

  Future<void> _import() async {
    if (_selectedLanguage == null || _isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final result = await _fetchFuture;
      final doc = TextDocument(
        languageId: _selectedLanguage!.id!,
        collectionId: _selectedCollectionId,
        title: result.title,
        content: result.content,
        sourceUri: result.url,
        coverImage: result.coverImageUrl,
      );
      await db.texts.create(doc);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage =
            AppLocalizations.of(context).fetchFailed(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.importFromLink),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _UrlPreview(url: widget.url),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 8),
            ],
            InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.languages,
                border: const OutlineInputBorder(),
              ),
              child: DropdownButton<Language>(
                value: _selectedLanguage,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                hint: Text(l10n.languages),
                items: _languages
                    .map((lang) => DropdownMenuItem(
                          value: lang,
                          child: Row(
                            children: [
                              if (lang.flagEmoji.isNotEmpty) ...[
                                Text(lang.flagEmoji),
                                const SizedBox(width: 8),
                              ],
                              Text(lang.name),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (lang) {
                  if (lang == null) return;
                  setState(() => _selectedLanguage = lang);
                  _loadCollections(lang);
                },
              ),
            ),
            if (_selectedLanguage != null && _collections.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l10n.selectCollection,
                  style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              _CollectionPicker(
                collections: _collections,
                selectedId: _selectedCollectionId,
                onChanged: (id) => setState(() => _selectedCollectionId = id),
                noFolderLabel: l10n.noFolderRoot,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _selectedLanguage != null && !_isSaving ? _import : null,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.import),
        ),
      ],
    );
  }
}

class _UrlPreview extends StatelessWidget {
  final String url;
  const _UrlPreview({required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = url.length > 60 ? '${url.substring(0, 60)}…' : url;
    return Row(
      children: [
        Icon(Icons.link, size: 16, color: theme.colorScheme.secondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            display,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.secondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CollectionPicker extends StatelessWidget {
  final List<Collection> collections;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final String noFolderLabel;

  const _CollectionPicker({
    required this.collections,
    required this.selectedId,
    required this.onChanged,
    required this.noFolderLabel,
  });

  @override
  Widget build(BuildContext context) {
    final all = <String?>[null, ...collections.map((c) => c.id)];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 160),
      child: SingleChildScrollView(
        child: RadioGroup<String?>(
          groupValue: selectedId,
          onChanged: onChanged,
          child: Column(
            children: all.map((id) {
              final label = id == null
                  ? noFolderLabel
                  : collections.firstWhere((c) => c.id == id).name;
              return RadioListTile<String?>(
                value: id,
                title: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
