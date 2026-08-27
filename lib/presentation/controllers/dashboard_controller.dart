import '../../domain/entities/book_progress.dart';
import '../../domain/entities/day_activity.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/term.dart';
import '../../domain/entities/text_document.dart';
import '../../domain/value_objects/term_status.dart';
import '../../presentation/models/chart_data.dart';
import '../../service_locator.dart';
import '../../services/logger_service.dart';
import '../../services/text_parser_service.dart';
import '../../utils/chart_helpers.dart';
import 'base_controller.dart';

class DashboardController extends BaseController {
  final Language language;

  final _textParser = sl.isRegistered<TextParserService>()
      ? sl<TextParserService>()
      : TextParserService();

  // Data state
  List<TextDocument> recentlyReadTexts = [];
  List<TextDocument> recentlyAddedTexts = [];
  Map<int, int> termCounts = {};
  Map<String, int> unknownCounts = {};
  Map<String, String> collectionNames = {};
  Map<String, DayActivity> activityData = {};
  int totalTextsCount = 0;
  int finishedTextsCount = 0;
  int dueCount = 0;
  int reviewedToday = 0;
  int streakDays = 0;
  int activeDays = 0;
  int breakDays = 0;
  List<DailyActivityChartData> dailyActivityData = [];
  List<VocabularyGrowthChartData> vocabularyGrowthData = [];
  List<StatusDistributionData> statusDistributionData = [];
  List<BookProgress> bookProgress = [];

  bool isLoading = true;
  String? error;

  bool _loadInProgress = false;
  bool _pendingReload = false;

  static const int _recentTextsLimit = 5;
  static const int _maxHeatmapWeeks = 52;
  static const int _chartDays = 30;

  DashboardController({required this.language}) {
    dataChanges.terms.addListener(_onDataChanged);
    dataChanges.texts.addListener(_onDataChanged);
    dataChanges.reviewCards.addListener(_onDataChanged);
    dataChanges.collections.addListener(_onDataChanged);
    dataChanges.settings.addListener(_onDataChanged);
    loadData();
  }

  void _onDataChanged() {
    if (!isDisposed) loadData();
  }

  @override
  void dispose() {
    dataChanges.terms.removeListener(_onDataChanged);
    dataChanges.texts.removeListener(_onDataChanged);
    dataChanges.reviewCards.removeListener(_onDataChanged);
    dataChanges.collections.removeListener(_onDataChanged);
    dataChanges.settings.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> loadData() async {
    if (_loadInProgress) {
      _pendingReload = true;
      return;
    }
    _loadInProgress = true;
    _pendingReload = false;

    error = null;

    try {
      final recentlyRead = await db.texts.getRecentlyRead(
        language.id!,
        limit: _recentTextsLimit,
      );
      final recentlyAdded = await db.texts.getRecentlyAdded(
        language.id!,
        limit: _recentTextsLimit,
      );
      final counts = await db.terms.getCountsByStatus(language.id!);
      final totalTexts = await db.texts.getCountByLanguage(language.id!);
      final finishedTexts = await db.texts.getFinishedCount(language.id!);

      final termsMap = await db.terms.getMapByLanguage(language.id!);

      final newUnknownCounts = <String, int>{};
      final allTexts = {...recentlyRead, ...recentlyAdded};
      for (final text in allTexts) {
        newUnknownCounts[text.id!] = _calculateUnknownCount(text, termsMap);
      }

      final newCollectionNames = <String, String>{};
      final collectionIds = allTexts
          .where((t) => t.collectionId != null)
          .map((t) => t.collectionId!)
          .toSet();
      for (final collectionId in collectionIds) {
        final collection = await db.collections.getById(collectionId);
        if (collection != null) newCollectionNames[collectionId] = collection.name;
      }

      final now = DateTime.now();
      final sinceDate = now.subtract(Duration(days: _maxHeatmapWeeks * 7));
      final sinceIso = _isoDate(sinceDate);

      final wordsAddedByDay = await db.terms.getCreatedCountsByDay(language.id!, sinceIso);
      final textsCompletedByDay = await db.texts.getCompletedCountsByDay(language.id!, sinceIso);
      final wordsReviewedByDay = await db.reviewLogs.getReviewCountsByDay(language.id!, sinceIso);

      final allDates = <String>{
        ...wordsAddedByDay.keys,
        ...textsCompletedByDay.keys,
        ...wordsReviewedByDay.keys,
      };
      final newActivityData = <String, DayActivity>{};
      for (final date in allDates) {
        newActivityData[date] = DayActivity(
          textsCompleted: textsCompletedByDay[date] ?? 0,
          wordsAdded: wordsAddedByDay[date] ?? 0,
          wordsReviewed: wordsReviewedByDay[date] ?? 0,
        );
      }

      final due = await db.reviewCards.getDueCount(language.id!);
      final reviewed = await db.reviewLogs.getReviewCountToday(language.id!);
      final streak = _calculateStreak(newActivityData);
      final summary = _calculateActivitySummary(newActivityData);

      final chartSinceDate = now.subtract(const Duration(days: _chartDays));
      final chartSinceIso = _isoDate(chartSinceDate);

      final chartWordsAdded = await db.terms.getCreatedCountsByDay(language.id!, chartSinceIso);
      final chartTextsCompleted = await db.texts.getCompletedCountsByDay(language.id!, chartSinceIso);
      final chartReviews = await db.reviewLogs.getReviewCountsByDay(language.id!, chartSinceIso);

      final newDailyActivity = ChartHelpers.buildDailyActivityChartData(
        reviewsByDay: chartReviews,
        wordsAddedByDay: chartWordsAdded,
        textsFinishedByDay: chartTextsCompleted,
        days: _chartDays,
      );
      final totalWordCount = counts.values.fold<int>(0, (s, c) => s + c);
      final newVocabGrowth = ChartHelpers.buildVocabularyGrowthChartData(
        wordsAddedByDay: chartWordsAdded,
        currentKnownCount: totalWordCount,
        days: _chartDays,
      );
      final newStatusDist = ChartHelpers.buildStatusDistributionData(countsByStatus: counts);
      final bookLimit = await settings.getBookProgressLimit();
      final books = await db.collections.getBookProgress(
        language.id!,
        limit: bookLimit,
        excludeCompleted: true,
      );

      if (isDisposed) return;
      recentlyReadTexts = recentlyRead;
      recentlyAddedTexts = recentlyAdded;
      termCounts = counts;
      totalTextsCount = totalTexts;
      finishedTextsCount = finishedTexts;
      unknownCounts = newUnknownCounts;
      collectionNames = newCollectionNames;
      activityData = newActivityData;
      dueCount = due;
      reviewedToday = reviewed;
      streakDays = streak;
      activeDays = summary.activeDays;
      breakDays = summary.breakDays;
      dailyActivityData = newDailyActivity;
      vocabularyGrowthData = newVocabGrowth;
      statusDistributionData = newStatusDist;
      bookProgress = books;
      isLoading = false;
      safeNotify();
    } catch (e, stackTrace) {
      AppLogger.error('Dashboard load failed', error: e, stackTrace: stackTrace);
      if (!isDisposed) {
        isLoading = false;
        error = e.toString();
        safeNotify();
      }
    } finally {
      _loadInProgress = false;
      if (_pendingReload && !isDisposed) loadData();
    }
  }

  int _calculateUnknownCount(TextDocument text, Map<String, Term> termsMap) {
    final words = _textParser.splitIntoWords(text.content, language);
    final seenWords = <String>{};
    int unknownCount = 0;
    for (final word in words) {
      final normalized = word.toLowerCase();
      if (seenWords.contains(normalized)) continue;
      seenWords.add(normalized);
      final term = termsMap[normalized];
      if (term == null || term.status == TermStatus.unknown) unknownCount++;
    }
    return unknownCount;
  }

  int _calculateStreak(Map<String, DayActivity> activity) {
    final now = DateTime.now();
    int streak = 0;
    for (int i = 0; ; i++) {
      final date = now.subtract(Duration(days: i));
      final key = _isoDate(date);
      final a = activity[key];
      if (a != null && a.total > 0) {
        streak++;
      } else {
        if (i == 0) continue;
        break;
      }
    }
    return streak;
  }

  ({int activeDays, int breakDays}) _calculateActivitySummary(
      Map<String, DayActivity> activity) {
    final activeDateKeys = activity.keys
        .where((k) => activity[k]!.total > 0)
        .toList()
      ..sort();
    if (activeDateKeys.isEmpty) return (activeDays: 0, breakDays: 0);

    final first = DateTime.parse(activeDateKeys.first);
    final now = DateTime.now();
    final firstDay = DateTime(first.year, first.month, first.day);
    final todayDay = DateTime(now.year, now.month, now.day);

    int active = 0, breaks = 0;
    DateTime cur = firstDay;
    while (!cur.isAfter(todayDay)) {
      final key = _isoDate(cur);
      if ((activity[key]?.total ?? 0) > 0) {
        active++;
      } else {
        breaks++;
      }
      cur = DateTime(cur.year, cur.month, cur.day + 1);
    }
    return (activeDays: active, breakDays: breaks);
  }

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
