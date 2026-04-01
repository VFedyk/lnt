import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../service_locator.dart';
import '../services/logger_service.dart';
import '../utils/constants.dart';
import '../widgets/shared/app_empty_state.dart';
import '../widgets/review/exercise_card.dart';
import '../widgets/review/review_stats_section.dart';
import 'cloze_review_screen.dart';
import 'flashcard_review_screen.dart';
import 'multiple_choice_review_screen.dart';
import 'statistics_screen.dart';
import 'radical_practice_screen.dart';
import 'stroke_review_screen.dart';
import 'typing_review_screen.dart';

class ReviewScreen extends StatefulWidget {
  final Language language;

  const ReviewScreen({super.key, required this.language});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _dueCount = 0;
  int _clozeDueCount = 0;
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
      _error = null;
    });
    try {
      final dueCount = await db.reviewCards.getDueCount(widget.language.id!);
      final clozeDueCount = await db.reviewCards.getClozeDueCount(
        widget.language.id!,
      );
      final reviewedToday = await db.reviewLogs.getReviewCountToday(
        widget.language.id!,
      );

      if (mounted) {
        setState(() {
          _dueCount = dueCount;
          _clozeDueCount = clozeDueCount;
          _reviewedToday = reviewedToday;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Review stats load failed',
        error: e,
        stackTrace: stackTrace,
      );
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
      return AppErrorState(
        title: l10n.failedToLoadData,
        onRetry: _loadStats,
        retryLabel: l10n.retry,
      );
    }

    final exerciseCards = <Widget>[
      ExerciseCard(
        icon: Icons.style,
        title: l10n.flashcardReview,
        subtitle: l10n.flashcardReviewDescription,
        dueCount: _dueCount,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FlashcardReviewScreen(language: widget.language),
          ),
        ),
      ),
      ExerciseCard(
        icon: Icons.keyboard,
        title: l10n.typingSourceToTarget,
        subtitle: l10n.typingSourceToTargetDescription,
        dueCount: _dueCount,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TypingReviewScreen(
              language: widget.language,
              direction: TypingDirection.sourceToTarget,
            ),
          ),
        ),
      ),
      ExerciseCard(
        icon: Icons.keyboard,
        title: l10n.typingTargetToSource,
        subtitle: l10n.typingTargetToSourceDescription,
        dueCount: _dueCount,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TypingReviewScreen(
              language: widget.language,
              direction: TypingDirection.targetToSource,
            ),
          ),
        ),
      ),
      ExerciseCard(
        icon: Icons.quiz,
        title: l10n.multipleChoiceSourceToTarget,
        subtitle: l10n.multipleChoiceSourceToTargetDescription,
        dueCount: _dueCount,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultipleChoiceReviewScreen(
              language: widget.language,
              direction: MultipleChoiceDirection.sourceToTarget,
            ),
          ),
        ),
      ),
      ExerciseCard(
        icon: Icons.quiz,
        title: l10n.multipleChoiceTargetToSource,
        subtitle: l10n.multipleChoiceTargetToSourceDescription,
        dueCount: _dueCount,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultipleChoiceReviewScreen(
              language: widget.language,
              direction: MultipleChoiceDirection.targetToSource,
            ),
          ),
        ),
      ),
      if (widget.language.showRomanization)
        ExerciseCard(
          icon: Icons.record_voice_over,
          title: l10n.multipleChoiceRomanization,
          subtitle: l10n.multipleChoiceRomanizationDescription,
          dueCount: _dueCount,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MultipleChoiceReviewScreen(
                language: widget.language,
                direction: MultipleChoiceDirection.romanization,
              ),
            ),
          ),
        ),
      ExerciseCard(
        icon: Icons.text_fields,
        title: '${l10n.clozeReview} — ${l10n.clozeEasyMode}',
        subtitle: l10n.clozeEasyDescription,
        dueCount: _clozeDueCount,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClozeReviewScreen(
              language: widget.language,
              mode: ClozeMode.easy,
            ),
          ),
        ),
      ),
      ExerciseCard(
        icon: Icons.text_fields,
        title: '${l10n.clozeReview} — ${l10n.clozeAdvancedMode}',
        subtitle: l10n.clozeAdvancedDescription,
        dueCount: _clozeDueCount,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClozeReviewScreen(
              language: widget.language,
              mode: ClozeMode.advanced,
            ),
          ),
        ),
      ),
      if (widget.language.splitByCharacter) ...[
        ExerciseCard(
          icon: Icons.draw_outlined,
          title: l10n.writingPractice,
          subtitle: l10n.writingPracticeDescription,
          dueCount: _dueCount,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StrokeReviewScreen(language: widget.language),
            ),
          ),
        ),
        ExerciseCard(
          icon: Icons.brush_outlined,
          title: l10n.radicalPractice,
          subtitle: l10n.radicalPracticeDescription,
          dueCount: 0,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RadicalPracticeScreen()),
          ),
        ),
      ],
    ];

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        children: [
          ReviewStatsSection(
            dueCount: _dueCount,
            reviewedToday: _reviewedToday,
            onStatsTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StatisticsScreen(language: widget.language),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingL),

          // Exercise grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount =
                  (constraints.maxWidth / 200).clamp(2, 4).round();
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: AppConstants.spacingS,
                  mainAxisSpacing: AppConstants.spacingS,
                  mainAxisExtent: 120,
                ),
                itemCount: exerciseCards.length,
                itemBuilder: (_, i) => exerciseCards[i],
              );
            },
          ),
        ],
      ),
    );
  }
}
