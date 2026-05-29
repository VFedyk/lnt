import 'package:flutter/material.dart';

import '../../../domain/entities/collection.dart';
import '../../../domain/entities/language.dart';
import '../../../domain/entities/text_document.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../service_locator.dart';
import '../../../services/url_import_service.dart';
import '../../../utils/cover_image_helper.dart';

/// Return value from [ShareImportDialog].
/// [openInReader] is true when the user checked the "open in reader" option.
typedef ShareImportResult = ({TextDocument doc, Language language, bool openInReader});

/// Dialog shown when the user shares a URL to LNT from another app.
/// Starts fetching the URL immediately; the user picks a language and
/// navigates the folder tree while the fetch runs in the background.
class ShareImportDialog extends StatefulWidget {
  final String url;
  final Language? initialLanguage;

  const ShareImportDialog({super.key, required this.url, this.initialLanguage});

  @override
  State<ShareImportDialog> createState() => _ShareImportDialogState();
}

class _ShareImportDialogState extends State<ShareImportDialog> {
  final _service = UrlImportService();
  late Future<UrlImportResult> _fetchFuture;

  List<Language> _languages = [];
  Language? _selectedLanguage;
  String? _selectedCollectionId; // current folder; null = root
  bool _openInReader = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchFuture = _service.importFromUrl(widget.url);
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    final langs = await db.languages.getAll();
    if (!mounted) return;
    setState(() {
      _languages = langs;
      // Pre-select: passed-in language > single language > nothing
      if (widget.initialLanguage != null &&
          langs.any((l) => l.id == widget.initialLanguage!.id)) {
        _selectedLanguage =
            langs.firstWhere((l) => l.id == widget.initialLanguage!.id);
      } else if (langs.length == 1) {
        _selectedLanguage = langs.first;
      }
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

      String? coverImage;
      if (result.coverImageUrl != null) {
        final localPath =
            await _service.downloadCoverImage(result.coverImageUrl!);
        if (localPath != null) {
          coverImage = CoverImageHelper.toRelative(localPath);
        }
      }

      final doc = TextDocument(
        languageId: _selectedLanguage!.id!,
        collectionId: _selectedCollectionId,
        title: result.title,
        content: result.content,
        sourceUri: result.url,
        coverImage: coverImage,
      );
      final docId = await db.texts.create(doc);
      if (!mounted) return;
      Navigator.of(context).pop<ShareImportResult>((
        doc: doc.copyWith(id: docId),
        language: _selectedLanguage!,
        openInReader: _openInReader,
      ));
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
                          child: Row(children: [
                            if (lang.flagEmoji.isNotEmpty) ...[
                              Text(lang.flagEmoji),
                              const SizedBox(width: 8),
                            ],
                            Text(lang.name),
                          ]),
                        ))
                    .toList(),
                onChanged: (lang) {
                  if (lang == null) return;
                  setState(() {
                    _selectedLanguage = lang;
                    _selectedCollectionId = null;
                  });
                },
              ),
            ),
            if (_selectedLanguage != null) ...[
              const SizedBox(height: 12),
              Text(l10n.selectCollection,
                  style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              _CollectionBrowser(
                key: ValueKey(_selectedLanguage!.id),
                language: _selectedLanguage!,
                onLevelChanged: (id) =>
                    setState(() => _selectedCollectionId = id),
              ),
            ],
            const SizedBox(height: 8),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _openInReader,
              title: Text(l10n.openInReader,
                  style: theme.textTheme.bodyMedium),
              onChanged: (v) => setState(() => _openInReader = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop<ShareImportResult?>(null),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed:
              _selectedLanguage != null && !_isSaving ? _import : null,
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

/// Folder-browser collection picker. Navigating into a folder makes it the
/// selected destination. Fires [onLevelChanged] on every navigation step.
class _CollectionBrowser extends StatefulWidget {
  final Language language;
  final ValueChanged<String?> onLevelChanged;

  const _CollectionBrowser({
    super.key,
    required this.language,
    required this.onLevelChanged,
  });

  @override
  State<_CollectionBrowser> createState() => _CollectionBrowserState();
}

class _CollectionBrowserState extends State<_CollectionBrowser> {
  List<Collection> _collections = [];
  Collection? _currentParent; // null = root
  final _parentStack = <Collection?>[];

  @override
  void initState() {
    super.initState();
    _loadLevel(null);
  }

  Future<void> _loadLevel(Collection? parent) async {
    final cols = await db.collections.getAll(
      languageId: widget.language.id,
      parentId: parent?.id,
    );
    if (!mounted) return;
    setState(() {
      _currentParent = parent;
      _collections = cols;
    });
    widget.onLevelChanged(parent?.id);
  }

  void _navigateInto(Collection collection) {
    _parentStack.add(_currentParent);
    _loadLevel(collection);
  }

  void _navigateBack() {
    if (_parentStack.isEmpty) return;
    _loadLevel(_parentStack.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRoot = _currentParent == null;
    final isEmpty = _collections.isEmpty;

    if (isRoot && isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isRoot) ...[
                  // Header row: shows the CURRENT folder + back arrow.
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.arrow_back, size: 18),
                    title: Text(
                      _currentParent!.name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    onTap: _navigateBack,
                  ),
                  Divider(height: 1, color: theme.dividerColor),
                ],
                if (isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    child: Text(
                      'No sub-folders',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ..._collections.map((col) => ListTile(
                        dense: true,
                        leading: Icon(Icons.folder_outlined,
                            size: 20,
                            color: theme.colorScheme.primary),
                        title: Text(col.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing:
                            const Icon(Icons.chevron_right, size: 18),
                        onTap: () => _navigateInto(col),
                      )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
