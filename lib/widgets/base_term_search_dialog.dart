import 'package:flutter/material.dart';
import 'package:stemmer/stemmer.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/term.dart';
import '../service_locator.dart';
import '../utils/constants.dart';
import 'translation_mixin.dart';

abstract class _BaseTermSearchConstants {
  static const double statusAvatarRadius = 12.0;
  static const double progressSizeSmall = 18.0;
}

class BaseTermSearchDialog extends StatefulWidget {
  final int languageId;
  final int? excludeTermId;
  final String languageName;
  final String? initialWord;

  const BaseTermSearchDialog({
    super.key,
    required this.languageId,
    required this.languageName,
    this.excludeTermId,
    this.initialWord,
  });

  @override
  State<BaseTermSearchDialog> createState() => _BaseTermSearchDialogState();
}

class _BaseTermSearchDialogState extends State<BaseTermSearchDialog>
    with TranslationMixin {
  final _searchController = TextEditingController();
  final _translationController = TextEditingController();
  List<Term> _searchResults = [];
  Map<int, List<Translation>> _translationsMap = {};
  bool _isSearching = false;

  static final _snowballStemmer = SnowballStemmer();

  @override
  String get languageName => widget.languageName;

  @override
  TextEditingController get sourceTextController => _searchController;

  @override
  TextEditingController get translationTextController => _translationController;

  @override
  void initState() {
    super.initState();
    checkTranslationProviders();
    _prefillSearch();
  }

  void _prefillSearch() {
    if (widget.initialWord == null || widget.initialWord!.isEmpty) return;

    final isEnglish = widget.languageName.toLowerCase() == 'english';
    final searchWord = isEnglish
        ? _snowballStemmer.stem(widget.initialWord!)
        : widget.initialWord!;

    _searchController.text = searchWord;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _search(searchWord);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    final results = await db.searchTerms(
      widget.languageId,
      query.trim(),
    );

    if (mounted) {
      final lowerQuery = query.trim().toLowerCase();
      final filtered = results
          .where((t) => t.id != widget.excludeTermId)
          .toList();
      filtered.sort((a, b) {
        final aStarts = a.lowerText.startsWith(lowerQuery);
        final bStarts = b.lowerText.startsWith(lowerQuery);
        if (aStarts != bStarts) return aStarts ? -1 : 1;
        return 0;
      });

      final termIds = filtered
          .where((t) => t.id != null)
          .map((t) => t.id!)
          .toList();
      final translations = termIds.isNotEmpty
          ? await db.translations.getByTermIds(termIds)
          : <int, List<Translation>>{};

      if (!mounted) return;
      setState(() {
        _searchResults = filtered;
        _translationsMap = translations;
        _isSearching = false;
      });
    }
  }

  Future<void> _createNewBaseTerm() async {
    final termText = _searchController.text.trim().toLowerCase();
    if (termText.isEmpty) return;

    final newTerm = Term(
      languageId: widget.languageId,
      text: termText,
      lowerText: termText,
      status: TermStatus.unknown,
      translation: _translationController.text.trim(),
    );

    final id = await db.createTerm(newTerm);
    final createdTerm = newTerm.copyWith(id: id);

    if (mounted) {
      Navigator.pop(context, createdTerm);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.selectBaseForm),
      content: SizedBox(
        width: AppConstants.dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchTerms,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: _search,
              autofocus: true,
            ),
            const SizedBox(height: AppConstants.spacingM),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(AppConstants.spacingL),
                child: CircularProgressIndicator(),
              )
            else ...[
              if (_searchResults.isNotEmpty)
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final term = _searchResults[index];
                      final translations = term.id != null
                          ? _translationsMap[term.id!]
                          : null;
                      final subtitle = translations != null && translations.isNotEmpty
                          ? translations.map((t) => t.meaning).join(', ')
                          : term.translation;
                      return ListTile(
                        title: Text(term.lowerText),
                        subtitle: subtitle.isNotEmpty
                            ? Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        leading: CircleAvatar(
                          backgroundColor: term.statusColor,
                          radius: _BaseTermSearchConstants.statusAvatarRadius,
                        ),
                        onTap: () => Navigator.pop(context, term),
                      );
                    },
                  ),
                )
              else if (_searchController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.spacingS,
                  ),
                  child: Text(
                    l10n.noExistingTermsFound,
                    style: TextStyle(
                      color: AppConstants.subtitleColor,
                    ),
                  ),
                ),
              if (_searchController.text.isNotEmpty) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.spacingS,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.createNewBaseTerm,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppConstants.sectionHeaderColor,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingS),
                      TextField(
                        controller: _translationController,
                        decoration: InputDecoration(
                          labelText: l10n.translationOptional,
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: hasAnyTranslationProvider
                              ? isTranslating
                                  ? const SizedBox(
                                      width: _BaseTermSearchConstants
                                          .progressSizeSmall,
                                      height: _BaseTermSearchConstants
                                          .progressSizeSmall,
                                      child: CircularProgressIndicator(
                                        strokeWidth:
                                            AppConstants.progressStrokeWidth,
                                      ),
                                    )
                                  : IconButton(
                                      icon: const Icon(
                                        Icons.translate,
                                        size: AppConstants.progressIndicatorSize,
                                      ),
                                      tooltip: hasDeepL
                                          ? l10n.translateWithDeepL
                                          : l10n.translateWithLibreTranslate,
                                      onPressed: () => translateWithProvider(
                                        hasDeepL
                                            ? TranslationProvider.deepL
                                            : TranslationProvider.libreTranslate,
                                      ),
                                    )
                              : null,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingS),
                      ElevatedButton.icon(
                        onPressed: _createNewBaseTerm,
                        icon: const Icon(Icons.add),
                        label: Text(
                          l10n.createTerm(
                            _searchController.text.trim().toLowerCase(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
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
