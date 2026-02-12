import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../service_locator.dart';
import '../services/logger_service.dart';
import '../utils/constants.dart';
import 'flashcard_review_screen.dart';
import 'statistics_screen.dart';
import 'typing_review_screen.dart';

class ReviewScreen extends StatefulWidget {
  final Language language;

  const ReviewScreen({super.key, required this.language});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _dueCount = 0;
  int _reviewedToday = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    dataChanges.reviewCards.addListener(_loadStats);
    _loadStats();
  }

  @override
  void didUpdateWidget(ReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language.id != widget.language.id) {
      _loadStats();
    }
  }

  @override
  void dispose() {
    dataChanges.reviewCards.removeListener(_loadStats);
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dueCount = await db.reviewCards
          .getDueCount(widget.language.id!);
      final reviewedToday = await db.reviewLogs
          .getReviewCountToday(widget.language.id!);

      if (mounted) {
        setState(() {
          _dueCount = dueCount;
          _reviewedToday = reviewedToday;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Review stats load failed', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
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
            Icon(Icons.error_outline, size: AppConstants.errorIconSize, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: AppConstants.spacingM),
            Text(l10n.failedToLoadData, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppConstants.spacingM),
            ElevatedButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        children: [
          // Stats summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    l10n.cardsDue,
                    _dueCount.toString(),
                    Icons.schedule,
                  ),
                  _buildStatItem(
                    l10n.reviewedToday,
                    _reviewedToday.toString(),
                    Icons.check_circle,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingL),

          // Flashcard Review tile
          Card(
            child: ListTile(
              leading: const Icon(Icons.style),
              title: Text(l10n.flashcardReview),
              subtitle: Text(l10n.flashcardReviewDescription),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_dueCount > 0)
                    Badge(
                      label: Text(_dueCount.toString()),
                      child: const SizedBox.shrink(),
                    ),
                  const SizedBox(width: AppConstants.spacingS),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FlashcardReviewScreen(language: widget.language),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),

          // Typing Review: Source → Target
          Card(
            child: ListTile(
              leading: const Icon(Icons.keyboard),
              title: Text(l10n.typingSourceToTarget),
              subtitle: Text(l10n.typingSourceToTargetDescription),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_dueCount > 0)
                    Badge(
                      label: Text(_dueCount.toString()),
                      child: const SizedBox.shrink(),
                    ),
                  const SizedBox(width: AppConstants.spacingS),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TypingReviewScreen(
                      language: widget.language,
                      direction: TypingDirection.sourceToTarget,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),

          // Typing Review: Target → Source
          Card(
            child: ListTile(
              leading: const Icon(Icons.keyboard),
              title: Text(l10n.typingTargetToSource),
              subtitle: Text(l10n.typingTargetToSourceDescription),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_dueCount > 0)
                    Badge(
                      label: Text(_dueCount.toString()),
                      child: const SizedBox.shrink(),
                    ),
                  const SizedBox(width: AppConstants.spacingS),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TypingReviewScreen(
                      language: widget.language,
                      direction: TypingDirection.targetToSource,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),

          // Statistics tile
          Card(
            child: ListTile(
              leading: const Icon(Icons.bar_chart),
              title: Text(l10n.stats),
              subtitle: Text(l10n.statisticsDescription),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StatisticsScreen(language: widget.language),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(height: AppConstants.spacingXS),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
