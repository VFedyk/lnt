import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/text_document.dart';
import '../models/term.dart';
import '../service_locator.dart';
import '../services/text_parser_service.dart';
import '../models/day_activity.dart';
import '../services/logger_service.dart';
import '../utils/constants.dart';
import '../utils/cover_image_helper.dart';
import '../utils/helpers.dart';
import '../widgets/activity_heatmap.dart';
import '../widgets/animated_counter.dart';
import '../widgets/dashboard_charts.dart';
import '../widgets/review_progress_ring.dart';
import '../models/chart_data.dart';
import '../utils/chart_helpers.dart';
import 'reader_screen.dart';
import 'library_screen.dart';
import 'terms_screen.dart';

abstract class _DashboardConstants {
  static const int recentTextsLimit = 5;
  static const double thumbnailWidth = 40.0;
  static const double thumbnailHeight = 56.0;
  static const double thumbnailBorderRadius = 4.0;
  // 30 (day labels) + 52 weeks * 14 (cell + spacing) + 2 * 16 (card padding)
  static const double desktopHeatmapWidth = 795.0;
}

class DashboardTab extends StatefulWidget {
  final Language language;

  const DashboardTab({super.key, required this.language});

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
  int _totalTextsCount = 0;
  int _finishedTextsCount = 0;
  int _dueCount = 0;
  int _reviewedToday = 0;
  int _streakDays = 0;
  List<DailyActivityChartData> _dailyActivityData = [];
  List<VocabularyGrowthChartData> _vocabularyGrowthData = [];
  List<StatusDistributionData> _statusDistributionData = [];
  bool _isLoading = true;
  bool _loadInProgress = false;
  bool _pendingReload = false;
  String? _error;
  final _textParser = TextParserService();

  @override
  void initState() {
    super.initState();
    dataChanges.terms.addListener(_loadData);
    dataChanges.texts.addListener(_loadData);
    dataChanges.reviewCards.addListener(_loadData);
    _loadData();
  }

  @override
  void didUpdateWidget(DashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language.id != widget.language.id) {
      _loadData();
    }
  }

  @override
  void dispose() {
    dataChanges.terms.removeListener(_loadData);
    dataChanges.texts.removeListener(_loadData);
    dataChanges.reviewCards.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_loadInProgress) {
      _pendingReload = true;
      return;
    }
    _loadInProgress = true;
    _pendingReload = false;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final recentlyRead = await db.texts.getRecentlyRead(
        widget.language.id!,
        limit: _DashboardConstants.recentTextsLimit,
      );
      final recentlyAdded = await db.texts.getRecentlyAdded(
        widget.language.id!,
        limit: _DashboardConstants.recentTextsLimit,
      );
      final counts = await db.terms.getCountsByStatus(widget.language.id!);
      final totalTextsCount = await db.texts.getCountByLanguage(
        widget.language.id!,
      );
      final finishedTextsCount = await db.texts.getFinishedCount(
        widget.language.id!,
      );

      final termsMap = await db.terms.getMapByLanguage(widget.language.id!);

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
        final collection = await db.collections.getById(collectionId);
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

      final wordsAddedByDay = await db.terms.getCreatedCountsByDay(
        widget.language.id!,
        sinceIso,
      );
      final textsCompletedByDay = await db.texts.getCompletedCountsByDay(
        widget.language.id!,
        sinceIso,
      );
      final wordsReviewedByDay = await db.reviewLogs.getReviewCountsByDay(
        widget.language.id!,
        sinceIso,
      );

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

      final dueCount = await db.reviewCards.getDueCount(widget.language.id!);
      final reviewedToday = await db.reviewLogs.getReviewCountToday(
        widget.language.id!,
      );
      final streakDays = _calculateStreak(activityData);

      // Load chart data (30 days)
      const chartDays = 30;
      final chartSinceDate = now.subtract(const Duration(days: chartDays));
      final chartSinceIso =
          '${chartSinceDate.year}-${chartSinceDate.month.toString().padLeft(2, '0')}-${chartSinceDate.day.toString().padLeft(2, '0')}';

      final chartWordsAdded = await db.terms.getCreatedCountsByDay(
        widget.language.id!,
        chartSinceIso,
      );
      final chartTextsCompleted = await db.texts.getCompletedCountsByDay(
        widget.language.id!,
        chartSinceIso,
      );
      final chartReviews = await db.reviewLogs.getReviewCountsByDay(
        widget.language.id!,
        chartSinceIso,
      );

      // Build chart data
      final dailyActivityData = ChartHelpers.buildDailyActivityChartData(
        reviewsByDay: chartReviews,
        wordsAddedByDay: chartWordsAdded,
        textsFinishedByDay: chartTextsCompleted,
        days: chartDays,
      );

      final knownCount =
          (counts[TermStatus.known] ?? 0) + (counts[TermStatus.wellKnown] ?? 0);
      final vocabularyGrowthData = ChartHelpers.buildVocabularyGrowthChartData(
        wordsAddedByDay: chartWordsAdded,
        currentKnownCount: knownCount,
        days: chartDays,
      );

      final statusDistributionData =
          ChartHelpers.buildStatusDistributionData(countsByStatus: counts);

      if (!mounted) return;
      setState(() {
        _recentlyReadTexts = recentlyRead;
        _recentlyAddedTexts = recentlyAdded;
        _termCounts = counts;
        _totalTextsCount = totalTextsCount;
        _finishedTextsCount = finishedTextsCount;
        _unknownCounts = unknownCounts;
        _collectionNames = collectionNames;
        _activityData = activityData;
        _dueCount = dueCount;
        _reviewedToday = reviewedToday;
        _streakDays = streakDays;
        _dailyActivityData = dailyActivityData;
        _vocabularyGrowthData = vocabularyGrowthData;
        _statusDistributionData = statusDistributionData;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error(
        'Dashboard load failed',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    } finally {
      _loadInProgress = false;
      if (_pendingReload && mounted) {
        _loadData();
      }
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

  int _calculateStreak(Map<String, DayActivity> activityData) {
    final now = DateTime.now();
    int streak = 0;

    for (int i = 0; ; i++) {
      final date = now.subtract(Duration(days: i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final activity = activityData[key];

      if (activity != null && activity.total > 0) {
        streak++;
      } else {
        // If today has no activity yet, skip it and start from yesterday
        if (i == 0) continue;
        break;
      }
    }

    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: AppConstants.errorIconSize,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              l10n.failedToLoadData,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppConstants.spacingM),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: AppConstants.spacingS),
                                ],
                                Text(
                                  widget.language.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
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
                      streakDays: _streakDays,
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
              streakDays: _streakDays,
            ),
          ],
          const SizedBox(height: AppConstants.spacingL),
          _buildChartsSection(),
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
    final knownTerms =
        (_termCounts[TermStatus.known] ?? 0) +
        (_termCounts[TermStatus.wellKnown] ?? 0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildAnimatedStatItem(l10n.totalTerms, totalTerms, Icons.book),
        _buildAnimatedStatItem(l10n.known, knownTerms, Icons.check_circle),
        _buildAnimatedStatItem(l10n.texts, _totalTextsCount, Icons.article),
        _buildAnimatedStatItem(
          l10n.textsFinished,
          _finishedTextsCount,
          Icons.done_all,
        ),
        _buildReviewStatItem(l10n.reviewedToday),
      ],
    );
  }

  Widget _buildReviewStatItem(String label) {
    return Column(
      children: [
        ReviewProgressRing(reviewedToday: _reviewedToday, dueCount: _dueCount),
        const SizedBox(height: AppConstants.spacingXS),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildAnimatedStatItem(String label, int value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(height: AppConstants.spacingXS),
        AnimatedCounter(
          value: value,
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
        borderRadius: BorderRadius.circular(
          _DashboardConstants.thumbnailBorderRadius,
        ),
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

  Widget _buildChartsSection() {
    if (PlatformHelper.isDesktop) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: DailyActivityBarChart(
                data: _dailyActivityData,
                height: 280,
              ),
            ),
            const SizedBox(width: AppConstants.spacingL),
            Expanded(
              flex: 2,
              child: VocabularyGrowthLineChart(
                data: _vocabularyGrowthData,
                height: 280,
              ),
            ),
            const SizedBox(width: AppConstants.spacingL),
            SizedBox(
              width: 220,
              child: StatusDistributionDonutChart(
                data: _statusDistributionData,
              ),
            ),
          ],
        ),
      );
    } else {
      return Column(
        children: [
          DailyActivityBarChart(
            data: _dailyActivityData,
            height: 250,
          ),
          const SizedBox(height: AppConstants.spacingL),
          VocabularyGrowthLineChart(
            data: _vocabularyGrowthData,
            height: 250,
          ),
          const SizedBox(height: AppConstants.spacingL),
          Center(
            child: SizedBox(
              width: 220,
              child: StatusDistributionDonutChart(
                data: _statusDistributionData,
              ),
            ),
          ),
        ],
      );
    }
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
                        builder: (_) =>
                            LibraryScreen(language: widget.language),
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
