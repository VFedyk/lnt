import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:provider/provider.dart';
import '../controllers/flashcard_review_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/term.dart';
import '../service_locator.dart';
import '../services/dictionary_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/review_progress_indicator.dart';
import '../widgets/term_dialog.dart';

abstract class _FlashcardReviewConstants {
  static const double cardElevation = 4.0;
  static const double cardBorderRadius = 16.0;
  static const double termFontSize = 28.0;
  static const double romanizationFontSize = 16.0;
  static const double sentenceFontSize = 16.0;
  static const double translationFontSize = 18.0;
  static const double statusDotSize = 12.0;
  static const double completionIconSize = 80.0;
  static const double buttonSpacing = 8.0;
  static const double intervalFontSize = 11.0;
  static const double minCardHeight = 300.0;
  static const double contentSpacing = 20.0;
  static const Duration flipDuration = Duration(milliseconds: 400);
}

class FlashcardReviewScreen extends StatelessWidget {
  final Language language;

  const FlashcardReviewScreen({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FlashcardReviewController(language: language),
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
  final _dictService = DictionaryService();
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

    // When answer is not yet revealed, any rating key reveals it first
    if (!controller.isAnswerRevealed) {
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

    final result = await showDialog<TermDialogResult>(
      context: context,
      builder: (context) => TermDialog(
        term: term,
        sentence: term.sentence,
        dictionaries: dictionaries,
        onLookup: (ctx, dict) =>
            _dictService.lookupWord(ctx, term.text, dict.url),
        languageId: controller.language.id!,
        languageName: controller.language.name,
        languageCode: controller.language.languageCode,
      ),
    );

    if (result != null) {
      // Save the updated term and translations to database
      await db.terms.update(result.term);
      if (result.term.id != null) {
        await db.translations.replaceForTerm(
          result.term.id!,
          result.translations,
        );
      }
      // Reload the current item's data to reflect changes
      await controller.reloadCurrentItem();
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  Widget _buildHighlightedSentence(
    String sentence,
    String termText,
    int status,
  ) {
    // Try to find the term in the sentence (case-insensitive)
    final lowerSentence = sentence.toLowerCase();
    final lowerTerm = termText.toLowerCase();
    final index = lowerSentence.indexOf(lowerTerm);

    if (index == -1) {
      // Term not found in sentence, return plain text
      return Text(
        sentence,
        style: TextStyle(
          fontSize: _FlashcardReviewConstants.sentenceFontSize,
          color: AppConstants.subtitleColor,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Split sentence into parts: before, term, after
    final before = sentence.substring(0, index);
    final term = sentence.substring(index, index + termText.length);
    final after = sentence.substring(index + termText.length);

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: _FlashcardReviewConstants.sentenceFontSize,
          color: AppConstants.subtitleColor,
          fontStyle: FontStyle.italic,
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: term,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: TermStatus.colorFor(status),
              fontStyle: FontStyle.normal,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
      textAlign: TextAlign.center,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
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
          body = _buildReviewCard(l10n, controller);
        }

        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Scaffold(
            appBar: AppBar(title: Text(l10n.flashcardReview)),
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
          if (controller.isAnswerRevealed) ...[
            const SizedBox(height: AppConstants.spacingM),
            _buildRatingButtons(l10n, controller),
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
                color: AppConstants.subtitleColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (term.sentence.isNotEmpty) ...[
            const SizedBox(height: _FlashcardReviewConstants.contentSpacing),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingL,
              ),
              child: _buildHighlightedSentence(
                term.sentence,
                term.text,
                term.status,
              ),
            ),
          ],
          const SizedBox(height: AppConstants.spacingXL),
          Text(
            l10n.showAnswer,
            style: TextStyle(
              color: AppConstants.subtitleColor,
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
                    color: AppConstants.subtitleColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (term.sentence.isNotEmpty) ...[
                const SizedBox(
                  height: _FlashcardReviewConstants.contentSpacing,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingL,
                  ),
                  child: _buildHighlightedSentence(
                    term.sentence,
                    term.text,
                    term.status,
                  ),
                ),
              ],
              const SizedBox(height: _FlashcardReviewConstants.contentSpacing),
              const Divider(),
              const SizedBox(height: AppConstants.spacingM),
              ...item.translations.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: AppConstants.spacingS),
                  child: Text(
                    t.partOfSpeech != null && t.partOfSpeech!.isNotEmpty
                        ? '${t.meaning} (${PartOfSpeech.localizedNameFor(t.partOfSpeech!, l10n)})'
                        : t.meaning,
                    style: const TextStyle(
                      fontSize: _FlashcardReviewConstants.translationFontSize,
                    ),
                    textAlign: TextAlign.center,
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
        const SizedBox(width: _FlashcardReviewConstants.buttonSpacing),
        _buildRatingButton(
          controller: controller,
          label: l10n.rateHard,
          rating: fsrs.Rating.hard,
          color: context.appColors.warning,
          interval: intervals?[fsrs.Rating.hard],
        ),
        const SizedBox(width: _FlashcardReviewConstants.buttonSpacing),
        _buildRatingButton(
          controller: controller,
          label: l10n.rateGood,
          rating: fsrs.Rating.good,
          color: context.appColors.success,
          interval: intervals?[fsrs.Rating.good],
        ),
        const SizedBox(width: _FlashcardReviewConstants.buttonSpacing),
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
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (interval != null)
              Text(
                _formatDuration(interval),
                style: TextStyle(
                  fontSize: _FlashcardReviewConstants.intervalFontSize,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
