import 'package:flutter/material.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:provider/provider.dart';
import '../controllers/flashcard_review_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/term.dart';
import '../service_locator.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/shared/app_empty_state.dart';
import '../widgets/shared/handwriting_canvas.dart';
import '../widgets/shared/review_progress_indicator.dart';
import '../widgets/shared/term_dialog.dart';
import '../services/dictionary_service.dart';

abstract class _K {
  static const double characterFontSize = 72.0;
  static const double romanizationFontSize = 16.0;
  static const double translationFontSize = 18.0;
  static const double intervalFontSize = 11.0;
  static const double buttonSpacing = 8.0;
  static const double completionIconSize = 80.0;
}

class StrokeReviewScreen extends StatelessWidget {
  final Language language;

  const StrokeReviewScreen({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FlashcardReviewController(language: language),
      child: const _StrokeReviewBody(),
    );
  }
}

class _StrokeReviewBody extends StatefulWidget {
  const _StrokeReviewBody();

  @override
  State<_StrokeReviewBody> createState() => _StrokeReviewBodyState();
}

class _StrokeReviewBodyState extends State<_StrokeReviewBody> {
  final _canvasKey = GlobalKey<HandwritingCanvasState>();
  bool _isRevealed = false;
  final _dictService = DictionaryService();

  void _reveal() {
    setState(() => _isRevealed = true);
  }

  Future<void> _rateCard(
    FlashcardReviewController controller,
    fsrs.Rating rating,
  ) async {
    await controller.rateCard(rating);
    if (mounted) {
      setState(() => _isRevealed = false);
      _canvasKey.currentState?.clear();
    }
  }

  Future<void> _editTerm(
    FlashcardReviewController controller,
    Term term,
  ) async {
    final dictionaries = await db.dictionaries.getAll(
      languageId: controller.language.id!,
    );
    if (!mounted) return;

    final result = await showDialog<TermDialogResult>(
      context: context,
      builder: (context) => TermDialog(
        term: term,
        sentence: term.sentence,
        dictionaries: dictionaries,
        onLookup: (ctx, dict) =>
            _dictService.lookupWord(ctx, term.text, dict),
        languageId: controller.language.id!,
        languageName: controller.language.name,
        languageCode: controller.language.languageCode,
      ),
    );

    if (result != null) {
      await db.terms.update(result.term);
      if (result.term.id != null) {
        await db.translations.replaceForTerm(
          result.term.id!,
          result.translations,
        );
      }
      await controller.reloadCurrentItem();
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) return '${duration.inDays}d';
    if (duration.inHours > 0) return '${duration.inHours}h';
    return '${duration.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<FlashcardReviewController>(
      builder: (context, controller, _) {
        Widget body;
        if (controller.isLoading || controller.isSeeding) {
          body = const Center(child: CircularProgressIndicator());
        } else if (controller.dueItems.isEmpty) {
          body = _buildEmptyState(l10n);
        } else if (controller.currentIndex >= controller.dueItems.length) {
          body = _buildCompletionState(l10n, controller);
        } else {
          body = _buildPracticeCard(l10n, controller);
        }

        return Scaffold(
          appBar: AppBar(title: Text(l10n.writingPractice)),
          body: body,
        );
      },
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return AppEmptyState(
      icon: Icons.check_circle_outline,
      iconSize: _K.completionIconSize,
      iconColor: TermStatus.colorFor(TermStatus.known),
      title: l10n.noCardsDue,
      action: ElevatedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
        label: Text(l10n.done),
      ),
    );
  }

  Widget _buildCompletionState(
    AppLocalizations l10n,
    FlashcardReviewController controller,
  ) {
    return ReviewCompletionState(
      reviewedCount: controller.reviewedCount,
      onDone: () => Navigator.pop(context),
      completionMessage: l10n.reviewComplete,
      reviewedCountMessage: l10n.reviewedCount(controller.reviewedCount),
      doneLabel: l10n.done,
    );
  }

  Widget _buildPracticeCard(
    AppLocalizations l10n,
    FlashcardReviewController controller,
  ) {
    final item = controller.currentItem!;
    final term = item.term;

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReviewProgressIndicator(
            currentIndex: controller.currentIndex,
            totalCount: controller.dueItems.length,
            termStatus: term.status,
          ),

          // Prompt card: translations + pinyin
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppConstants.spacingM,
                horizontal: AppConstants.spacingL,
              ),
              child: Column(
                children: [
                  ...item.translations.map(
                    (t) => Text(
                      t.meaning,
                      style: const TextStyle(
                        fontSize: _K.translationFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (term.romanization.isNotEmpty && _isRevealed) ...[
                    const SizedBox(height: AppConstants.spacingXS),
                    Text(
                      term.romanization,
                      style: TextStyle(
                        fontSize: _K.romanizationFontSize,
                        color: AppConstants.subtitleColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // Revealed character overlay OR drawing canvas
          Expanded(
            child: _isRevealed
                ? _buildRevealedCharacter(l10n, controller, item)
                : _buildCanvas(l10n),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // Bottom actions
          if (!_isRevealed)
            _buildRevealButton(l10n)
          else
            _buildRatingButtons(l10n, controller),
        ],
      ),
    );
  }

  Widget _buildCanvas(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: HandwritingCanvas(key: _canvasKey),
        ),
      ],
    );
  }

  Widget _buildRevealedCharacter(
    AppLocalizations l10n,
    FlashcardReviewController controller,
    ReviewItem item,
  ) {
    final term = item.term;
    return Stack(
      alignment: Alignment.center,
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.borderRadiusL),
          ),
          child: SizedBox.expand(
            child: Center(
              child: Text(
                term.text,
                style: const TextStyle(
                  fontSize: _K.characterFontSize,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        Positioned(
          top: AppConstants.spacingXS,
          right: AppConstants.spacingXS,
          child: IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.edit,
            onPressed: () => _editTerm(controller, term),
            iconSize: 20,
          ),
        ),
        Positioned(
          bottom: AppConstants.spacingS,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.volume_up),
                tooltip: l10n.pronounce,
                onPressed: () => ttsService.speak(
                  term.lowerText,
                  controller.language.languageCode,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRevealButton(AppLocalizations l10n) {
    return FilledButton.tonal(
      onPressed: _reveal,
      child: Text(l10n.showAnswer),
    );
  }

  Widget _buildRatingButtons(
    AppLocalizations l10n,
    FlashcardReviewController controller,
  ) {
    final intervals = controller.nextIntervals;

    return Row(
      children: [
        _buildRatingButton(
          controller: controller,
          label: l10n.rateAgain,
          rating: fsrs.Rating.again,
          color: Theme.of(context).colorScheme.error,
          interval: intervals?[fsrs.Rating.again],
        ),
        const SizedBox(width: _K.buttonSpacing),
        _buildRatingButton(
          controller: controller,
          label: l10n.rateHard,
          rating: fsrs.Rating.hard,
          color: context.appColors.warning,
          interval: intervals?[fsrs.Rating.hard],
        ),
        const SizedBox(width: _K.buttonSpacing),
        _buildRatingButton(
          controller: controller,
          label: l10n.rateGood,
          rating: fsrs.Rating.good,
          color: context.appColors.success,
          interval: intervals?[fsrs.Rating.good],
        ),
        const SizedBox(width: _K.buttonSpacing),
        _buildRatingButton(
          controller: controller,
          label: l10n.rateEasy,
          rating: fsrs.Rating.easy,
          color: Theme.of(context).colorScheme.primary,
          interval: intervals?[fsrs.Rating.easy],
        ),
      ],
    );
  }

  Widget _buildRatingButton({
    required FlashcardReviewController controller,
    required String label,
    required fsrs.Rating rating,
    required Color color,
    Duration? interval,
  }) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () => _rateCard(controller, rating),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding:
              const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (interval != null)
              Text(
                _formatDuration(interval),
                style: TextStyle(
                  fontSize: _K.intervalFontSize,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
