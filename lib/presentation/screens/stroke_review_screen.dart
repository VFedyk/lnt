import '../../utils/dictionary_navigation.dart';
import '../theme/term_status_ui.dart';
import 'package:flutter/material.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:provider/provider.dart';
import '../controllers/flashcard_review_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/term.dart';
import '../../service_locator.dart';
import '../../utils/constants.dart';
import '../widgets/shared/app_empty_state.dart';
import '../widgets/shared/handwriting_canvas.dart';
import '../widgets/shared/review_progress_indicator.dart';
import '../widgets/shared/review_rating_buttons.dart';
import '../widgets/shared/term_dialog.dart';
import '../../domain/value_objects/term_status.dart';

abstract class _K {
  static const double characterFontSize = 72.0;
  static const double romanizationFontSize = 16.0;
  static const double translationFontSize = 18.0;
  static const double completionIconSize = 80.0;
}

class StrokeReviewScreen extends StatelessWidget {
  final Language language;
  final List<int>? statusFilter;

  const StrokeReviewScreen({super.key, required this.language, this.statusFilter});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          FlashcardReviewController(language: language, statusFilter: statusFilter),
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

    final result = await TermDialog.show(
      context,
      term: term,
      sentence: term.sentence,
      dictionaries: dictionaries,
      onLookup: (ctx, dict) =>
          openDictionaryLookup(ctx, term.text, dict),
      languageId: controller.language.id!,
      languageName: controller.language.name,
      languageCode: controller.language.languageCode,
    );

    if (!mounted) return;
    if (result == null) return;
    if (result.deleted) {
      await db.terms.delete(term.id!);
    } else {
      await saveTerm(result.term, result.translations, isNew: false);
    }
    await controller.reloadCurrentItem();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<FlashcardReviewController>(
      builder: (context, controller, _) {
        Widget body;
        if (controller.phase == ReviewPhase.loading ||
            controller.phase == ReviewPhase.seeding) {
          body = const Center(child: CircularProgressIndicator());
        } else if (controller.phase == ReviewPhase.empty) {
          body = _buildEmptyState(l10n);
        } else if (controller.phase == ReviewPhase.done) {
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
      iconColor: TermStatusUI.colorFor(TermStatus.known),
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            ReviewRatingButtons(
              nextIntervals: controller.nextIntervals,
              onRate: (rating) => _rateCard(controller, rating),
            ),
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

}
