import '../../utils/dictionary_navigation.dart';
import '../theme/term_status_ui.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:provider/provider.dart';
import '../controllers/flashcard_review_controller.dart';
import '../models/review_session_spec.dart';
import '../widgets/shared/review_session_app_bar.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../domain/entities/term.dart';
import '../../service_locator.dart';
import '../../utils/constants.dart';
import '../widgets/shared/app_empty_state.dart';
import '../widgets/shared/highlighted_sentence.dart';
import 'term_edit_screen.dart';
import '../widgets/shared/reread_suggestion_card.dart';
import '../widgets/shared/review_progress_indicator.dart';
import '../widgets/shared/review_rating_buttons.dart';
import '../../domain/value_objects/term_status.dart';

abstract class _FlashcardReviewConstants {
  static const double cardElevation = 4.0;
  static const double cardBorderRadius = 16.0;
  static const double termFontSize = 28.0;
  static const double romanizationFontSize = 16.0;
  static const double sentenceFontSize = 16.0;
  static const double translationFontSize = 18.0;
  static const double statusDotSize = 12.0;
  static const double completionIconSize = 80.0;
  static const double minCardHeight = 300.0;
  static const double contentSpacing = 20.0;
  static const Duration flipDuration = Duration(milliseconds: 400);
}

class FlashcardReviewScreen extends StatelessWidget {
  final ReviewSessionSpec spec;

  const FlashcardReviewScreen({super.key, required this.spec});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FlashcardReviewController(spec: spec),
      child: const _FlashcardReviewScreenBody(),
    );
  }
}

class _FlashcardReviewScreenBody extends StatefulWidget {
  const _FlashcardReviewScreenBody();

  @override
  State<_FlashcardReviewScreenBody> createState() =>
      _FlashcardReviewScreenBodyState();
}

class _FlashcardReviewScreenBodyState extends State<_FlashcardReviewScreenBody>
    with TickerProviderStateMixin {
  final _focusNode = FocusNode();
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: _FlashcardReviewConstants.flipDuration,
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    final controller = context.read<FlashcardReviewController>();

    // When review is complete or empty, Space/Enter/Esc dismisses the screen
    if (controller.phase == ReviewPhase.done ||
        controller.phase == ReviewPhase.empty) {
      if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.escape) {
        Navigator.pop(context);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // When answer is not yet revealed, any rating key reveals it first
    if (controller.phase == ReviewPhase.question) {
      if (key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.digit1 ||
          key == LogicalKeyboardKey.digit2 ||
          key == LogicalKeyboardKey.digit3 ||
          key == LogicalKeyboardKey.digit4 ||
          key == LogicalKeyboardKey.keyA ||
          key == LogicalKeyboardKey.keyS ||
          key == LogicalKeyboardKey.keyD ||
          key == LogicalKeyboardKey.keyF) {
        _revealAnswer(controller);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (controller.phase != ReviewPhase.revealed) {
      return KeyEventResult.ignored;
    }

    // Answer is revealed — rate the card
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.keyA) {
      _rateCard(controller, fsrs.Rating.again);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.keyS) {
      _rateCard(controller, fsrs.Rating.hard);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.keyD) {
      _rateCard(controller, fsrs.Rating.good);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.keyF) {
      _rateCard(controller, fsrs.Rating.easy);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _revealAnswer(FlashcardReviewController controller) {
    controller.revealAnswer();
    _flipController.forward();
  }

  Future<void> _rateCard(
    FlashcardReviewController controller,
    fsrs.Rating rating,
  ) async {
    await controller.rateCard(rating);
    _flipController.reset();
  }

  Future<void> _editTerm(
    FlashcardReviewController controller,
    Term term,
  ) async {
    final dictionaries = await db.dictionaries.getAll(
      languageId: controller.language.id!,
    );

    if (!mounted) return;

    final result = await TermEditScreen.open(
      context,
      term: term,
      sentence: '',
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
      await saveTerm(result.term, result.translations,
          isNew: false, sentences: result.sentenceEdits);
    }
    // Reload the current item's data to reflect changes
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
          body = _buildReviewCard(l10n, controller);
        }

        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Scaffold(
            appBar: reviewSessionAppBar(
                context, controller.spec, l10n.flashcardReview),
            body: body,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return AppEmptyState(
      icon: Icons.check_circle_outline,
      iconSize: _FlashcardReviewConstants.completionIconSize,
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
      footer: RereadSuggestionCard(
        language: controller.spec.language,
        failedTermIds: controller.outcome.failedTermIds,
        excludeTextId: controller.spec.sourceTextId,
      ),
    );
  }

  Widget _buildReviewCard(
    AppLocalizations l10n,
    FlashcardReviewController controller,
  ) {
    final item = controller.currentItem!;
    final term = item.term;

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        children: [
          // Progress indicator
          ReviewProgressIndicator(
            currentIndex: controller.currentIndex,
            totalCount: controller.dueItems.length,
            termStatus: term.status,
            statusDotSize: _FlashcardReviewConstants.statusDotSize,
          ),

          // Flashcard with flip animation
          Expanded(
            child: AnimatedBuilder(
              key: ValueKey('card_${controller.currentIndex}_${controller.reloadVersion}'),
              animation: _flipAnimation,
              builder: (context, _) {
                final angle = _flipAnimation.value;
                final showBack = angle >= math.pi / 2;

                // Counter-rotate the back face so it reads correctly
                final transform = Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // perspective
                  ..rotateY(showBack ? angle - math.pi : angle);

                return Transform(
                  transform: transform,
                  alignment: Alignment.center,
                  child: showBack
                      ? _buildCardBack(l10n, controller, item)
                      : _buildCardFront(l10n, controller, item),
                );
              },
            ),
          ),

          // Rating buttons
          if (controller.phase == ReviewPhase.revealed) ...[
            const SizedBox(height: AppConstants.spacingM),
            ReviewRatingButtons(
              nextIntervals: controller.nextIntervals,
              onRate: (rating) => _rateCard(controller, rating),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardShell({required Widget child, VoidCallback? onTap}) {
    return Card(
      elevation: _FlashcardReviewConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          _FlashcardReviewConstants.cardBorderRadius,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          _FlashcardReviewConstants.cardBorderRadius,
        ),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: _FlashcardReviewConstants.minCardHeight,
          ),
          padding: const EdgeInsets.all(AppConstants.spacingXL),
          child: child,
        ),
      ),
    );
  }

  Widget _buildCardFront(
    AppLocalizations l10n,
    FlashcardReviewController controller,
    ReviewItem item,
  ) {
    final term = item.term;
    return _buildCardShell(
      onTap: () => _revealAnswer(controller),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            term.text,
            style: const TextStyle(
              fontSize: _FlashcardReviewConstants.termFontSize,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (controller.language.languageCode.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.volume_up),
              tooltip: l10n.pronounce,
              onPressed: () => ttsService.speak(
                term.lowerText,
                controller.language.languageCode,
              ),
              visualDensity: VisualDensity.compact,
            ),
          if (term.romanization.isNotEmpty) ...[
            const SizedBox(height: _FlashcardReviewConstants.contentSpacing),
            Text(
              term.romanization,
              style: TextStyle(
                fontSize: _FlashcardReviewConstants.romanizationFontSize,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (controller.sentenceFor(term.id ?? '') case final s?) ...[
            const SizedBox(height: _FlashcardReviewConstants.contentSpacing),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingL,
              ),
              child: HighlightedSentence(
                sentence: s,
                termText: term.text,
                status: term.status,
                fontSize: _FlashcardReviewConstants.sentenceFontSize,
                language: controller.language,
              ),
            ),
          ],
          const SizedBox(height: AppConstants.spacingXL),
          Text(
            l10n.showAnswer,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: AppConstants.fontSizeCaption,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(
    AppLocalizations l10n,
    FlashcardReviewController controller,
    ReviewItem item,
  ) {
    final term = item.term;
    return _buildCardShell(
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                term.text,
                style: const TextStyle(
                  fontSize: _FlashcardReviewConstants.termFontSize,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (controller.language.languageCode.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: l10n.pronounce,
                  onPressed: () => ttsService.speak(
                    term.lowerText,
                    controller.language.languageCode,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              if (term.romanization.isNotEmpty) ...[
                const SizedBox(
                  height: _FlashcardReviewConstants.contentSpacing,
                ),
                Text(
                  term.romanization,
                  style: TextStyle(
                    fontSize: _FlashcardReviewConstants.romanizationFontSize,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (controller.sentenceFor(term.id ?? '') case final s?) ...[
                const SizedBox(
                  height: _FlashcardReviewConstants.contentSpacing,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingL,
                  ),
                  child: HighlightedSentence(
                    sentence: s,
                    termText: term.text,
                    status: term.status,
                    fontSize: _FlashcardReviewConstants.sentenceFontSize,
                    language: controller.language,
                  ),
                ),
              ],
              const SizedBox(height: _FlashcardReviewConstants.contentSpacing),
              const Divider(),
              const SizedBox(height: AppConstants.spacingM),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: item.translations.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: AppConstants.spacingS),
                        child: t.partOfSpeech != null && t.partOfSpeech!.isNotEmpty
                            ? RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: _FlashcardReviewConstants.translationFontSize,
                                  ),
                                  children: [
                                    TextSpan(text: t.meaning),
                                    TextSpan(
                                      text: ' (${PartOfSpeechUI.localizedNameFor(t.partOfSpeech!, l10n)})',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontSize: _FlashcardReviewConstants.translationFontSize - 2,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Text(
                                t.meaning,
                                style: const TextStyle(
                                  fontSize: _FlashcardReviewConstants.translationFontSize,
                                ),
                              ),
                      ),
                    ).toList(),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.edit,
              onPressed: () => _editTerm(controller, term),
              iconSize: 20,
            ),
          ),
        ],
      ),
    );
  }

}
