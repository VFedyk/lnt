import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../service_locator.dart';
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

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didUpdateWidget(ReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language.id != widget.language.id) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
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
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final l10n = AppLocalizations.of(context);

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
                ).then((_) => _loadStats());
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
                ).then((_) => _loadStats());
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
                ).then((_) => _loadStats());
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
