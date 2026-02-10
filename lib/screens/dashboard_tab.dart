import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/text_document.dart';
import '../models/term.dart';
import '../service_locator.dart';
import '../services/text_parser_service.dart';
import '../models/day_activity.dart';
import '../utils/constants.dart';
import '../utils/cover_image_helper.dart';
import '../utils/helpers.dart';
import '../widgets/activity_heatmap.dart';
import 'reader_screen.dart';
import 'library_screen.dart';
import 'terms_screen.dart';

abstract class _DashboardConstants {
  static const int recentTextsLimit = 5;
  static const double thumbnailWidth = 40.0;
  static const double thumbnailHeight = 56.0;
  static const double thumbnailBorderRadius = 4.0;
  // 28 (day labels) + 52 weeks * 14 (cell + spacing) + 2 * 16 (card padding)
  static const double desktopHeatmapWidth = 788.0;
}

class DashboardTab extends StatefulWidget {
  final Language language;
  final VoidCallback onRefresh;

  const DashboardTab({super.key, required this.language, required this.onRefresh});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  List<TextDocument> _recentlyReadTexts = [];
  List<TextDocument> _recentlyAddedTexts = [];
  Map<int, int> _termCounts = {};
  Map<int, int> _unknownCounts = {};
  Map<int, String> _collectionNames = {};
  Map<String, DayActivity> _activityData = {};
  bool _isLoading = true;
  final _textParser = TextParserService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(DashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language.id != widget.language.id) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final recentlyRead = await db.getRecentlyReadTexts(
        widget.language.id!,
        limit: _DashboardConstants.recentTextsLimit,
      );
      final recentlyAdded = await db
          .getRecentlyAddedTexts(widget.language.id!, limit: _DashboardConstants.recentTextsLimit);
      final counts = await db.getTermCountsByStatus(
        widget.language.id!,
      );

      final termsMap = await db.getTermsMap(
        widget.language.id!,
      );

      final unknownCounts = <int, int>{};
      final allTexts = {...recentlyRead, ...recentlyAdded};
      for (final text in allTexts) {
        unknownCounts[text.id!] = _calculateUnknownCount(text, termsMap);
      }

      final collectionNames = <int, String>{};
      final collectionIds = allTexts
          .where((t) => t.collectionId != null)
          .map((t) => t.collectionId!)
          .toSet();
      for (final collectionId in collectionIds) {
        final collection = await db.getCollection(
          collectionId,
        );
        if (collection != null) {
          collectionNames[collectionId] = collection.name;
        }
      }

      // Load activity heatmap data (52 weeks on desktop, 26 on mobile)
      final heatmapWeeks = PlatformHelper.isDesktop ? 52 : 26;
      final now = DateTime.now();
      final sinceDate = now.subtract(Duration(days: heatmapWeeks * 7));
      final sinceIso =
          '${sinceDate.year}-${sinceDate.month.toString().padLeft(2, '0')}-${sinceDate.day.toString().padLeft(2, '0')}';

      final wordsAddedByDay = await db.terms
          .getCreatedCountsByDay(widget.language.id!, sinceIso);
      final textsCompletedByDay = await db.texts
          .getCompletedCountsByDay(widget.language.id!, sinceIso);
      final wordsReviewedByDay = await db.reviewLogs
          .getReviewCountsByDay(widget.language.id!, sinceIso);

      final allDates = <String>{
        ...wordsAddedByDay.keys,
        ...textsCompletedByDay.keys,
        ...wordsReviewedByDay.keys,
      };
      final activityData = <String, DayActivity>{};
      for (final date in allDates) {
        activityData[date] = DayActivity(
          textsCompleted: textsCompletedByDay[date] ?? 0,
          wordsAdded: wordsAddedByDay[date] ?? 0,
          wordsReviewed: wordsReviewedByDay[date] ?? 0,
        );
      }

      setState(() {
        _recentlyReadTexts = recentlyRead;
        _recentlyAddedTexts = recentlyAdded;
        _termCounts = counts;
        _unknownCounts = unknownCounts;
        _collectionNames = collectionNames;
        _activityData = activityData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int _calculateUnknownCount(TextDocument text, Map<String, Term> termsMap) {
    final words = _textParser.splitIntoWords(text.content, widget.language);
    int unknownCount = 0;

    final seenWords = <String>{};
    for (final word in words) {
      final normalized = word.toLowerCase();
      if (seenWords.contains(normalized)) continue;
      seenWords.add(normalized);

      final term = termsMap[normalized];
      if (term == null || term.status == TermStatus.unknown) {
        unknownCount++;
      }
    }

    return unknownCount;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        children: [
          if (PlatformHelper.isDesktop)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppConstants.spacingL),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (widget.language.flagEmoji.isNotEmpty) ...[
                                  Text(
                                    widget.language.flagEmoji,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(width: AppConstants.spacingS),
                                ] else ...[
                                  Icon(
                                    Icons.language,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: AppConstants.spacingS),
                                ],
                                Text(
                                  widget.language.name,
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.spacingL),
                            _buildStatsRow(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingL),
                  SizedBox(
                    width: _DashboardConstants.desktopHeatmapWidth,
                    child: ActivityHeatmap(
                      activityData: _activityData,
                      weeksToShow: 52,
                      useTooltip: true,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.language,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(
                          widget.language.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spacingL),
                    _buildStatsRow(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            ActivityHeatmap(
              activityData: _activityData,
              weeksToShow: 26,
            ),
          ],
          const SizedBox(height: AppConstants.spacingL),
          _buildQuickActions(),
          const SizedBox(height: AppConstants.spacingL),
          _buildRecentlyReadTexts(),
          const SizedBox(height: AppConstants.spacingL),
          _buildRecentlyAddedTexts(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final l10n = AppLocalizations.of(context);
    final totalTerms = _termCounts.values.fold(0, (sum, count) => sum + count);
    final knownTerms = (_termCounts[TermStatus.known] ?? 0) + (_termCounts[TermStatus.wellKnown] ?? 0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(l10n.totalTerms, totalTerms.toString(), Icons.book),
        _buildStatItem(l10n.known, knownTerms.toString(), Icons.check_circle),
        _buildStatItem(
          l10n.texts,
          _recentlyAddedTexts.length.toString(),
          Icons.article,
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(height: AppConstants.spacingXS),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildTextThumbnail(TextDocument text, IconData fallbackIcon) {
    final resolvedCover = CoverImageHelper.resolve(text.coverImage);
    if (resolvedCover != null && File(resolvedCover).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_DashboardConstants.thumbnailBorderRadius),
        child: Image.file(
          File(resolvedCover),
          width: _DashboardConstants.thumbnailWidth,
          height: _DashboardConstants.thumbnailHeight,
          fit: BoxFit.cover,
        ),
      );
    }
    return Icon(fallbackIcon);
  }

  Widget _buildQuickActions() {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.quickActions,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppConstants.spacingM),
            Wrap(
              spacing: AppConstants.spacingS,
              runSpacing: AppConstants.spacingS,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: Text(l10n.addText),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LibraryScreen(language: widget.language),
                      ),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.import_export),
                  label: Text(l10n.importVocabulary),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TermsScreen(language: widget.language),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyReadTexts() {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.recentlyRead,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppConstants.spacingM),
            if (_recentlyReadTexts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingL),
                child: Text(l10n.noTextsReadYet),
              )
            else
              ..._recentlyReadTexts.map((text) {
                final collectionName = text.collectionId != null
                    ? _collectionNames[text.collectionId]
                    : null;
                return ListTile(
                  leading: _buildTextThumbnail(text, Icons.history),
                  title: Text(text.title),
                  subtitle: Text(
                    '${collectionName != null ? '$collectionName • ' : ''}${widget.language.splitByCharacter ? l10n.charactersCount(text.characterCount) : l10n.wordsCount(text.wordCount)} • ${l10n.unknownCount(_unknownCounts[text.id] ?? 0)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReaderScreen(text: text, language: widget.language),
                      ),
                    );
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyAddedTexts() {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.recentlyAdded,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppConstants.spacingM),
            if (_recentlyAddedTexts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingL),
                child: Text(l10n.noTextsYetAddOne),
              )
            else
              ..._recentlyAddedTexts.map((text) {
                final collectionName = text.collectionId != null
                    ? _collectionNames[text.collectionId]
                    : null;
                return ListTile(
                  leading: _buildTextThumbnail(text, Icons.article),
                  title: Text(text.title),
                  subtitle: Text(
                    '${collectionName != null ? '$collectionName • ' : ''}${widget.language.splitByCharacter ? l10n.charactersCount(text.characterCount) : l10n.wordsCount(text.wordCount)} • ${l10n.unknownCount(_unknownCounts[text.id] ?? 0)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReaderScreen(text: text, language: widget.language),
                      ),
                    );
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}
