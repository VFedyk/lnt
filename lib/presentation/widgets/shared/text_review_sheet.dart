import 'package:flutter/material.dart';

import '../../../domain/entities/language.dart';
import '../../../domain/entities/term.dart';
import '../../../domain/entities/text_document.dart';
import '../../../domain/value_objects/review_scope.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../service_locator.dart';
import '../../../services/logger_service.dart';
import '../../../utils/constants.dart';
import '../../models/review_session_spec.dart';
import '../../screens/cloze_review_screen.dart';
import '../../screens/flashcard_review_screen.dart';
import '../../screens/multiple_choice_review_screen.dart';
import '../../screens/stroke_review_screen.dart';
import '../../screens/typing_review_screen.dart';

/// Bottom sheet that starts a review session scoped to one text.
///
/// Shows the due count and the total practice count, then routes to an
/// exercise picker. The two modes are deliberately separate: grading cards that
/// are not yet due would distort FSRS, so "practice all" never writes.
///
/// [multiWordTerms] is the reader's fast path — it has already resolved which
/// multi-word terms occur in the text while parsing, which saves a content scan.
Future<void> showTextReviewSheet(
  BuildContext context, {
  required TextDocument text,
  required Language language,
  Iterable<Term>? multiWordTerms,
}) async {
  // The mode sheet only *chooses* a spec; the picker is shown from the caller's
  // context afterwards, so neither sheet navigates from a route being popped.
  final spec = await showModalBottomSheet<ReviewSessionSpec>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TextReviewSheet(
      text: text,
      language: language,
      multiWordTerms: multiWordTerms,
    ),
  );
  if (spec == null || !context.mounted) return;

  final exercise = await showModalBottomSheet<WidgetBuilder>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ExercisePickerSheet(spec: spec),
  );
  if (exercise == null || !context.mounted) return;

  // Pushed only once the sheet is fully gone. Popping and pushing in the same
  // frame leaves the sheet's focus scope and modal barrier tearing down over
  // the new route, which swallows taps and keeps `autofocus` from landing —
  // the exercise screen comes up inert.
  await Navigator.push(context, MaterialPageRoute(builder: exercise));
}

class _TextReviewSheet extends StatefulWidget {
  const _TextReviewSheet({
    required this.text,
    required this.language,
    this.multiWordTerms,
  });

  final TextDocument text;
  final Language language;
  final Iterable<Term>? multiWordTerms;

  @override
  State<_TextReviewSheet> createState() => _TextReviewSheetState();
}

class _TextReviewSheetState extends State<_TextReviewSheet> {
  ReviewScope? _dueScope;
  ReviewScope? _practiceScope;
  int _dueCount = 0;
  int _practiceCount = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final dueScope = await resolveTextTerms(
        widget.text,
        widget.language,
        knownMultiWordTerms: widget.multiWordTerms,
      );
      // The index is warm after the first call, so this one is cheap.
      final practiceScope = await resolveTextTerms(
        widget.text,
        widget.language,
        includeNotDue: true,
        knownMultiWordTerms: widget.multiWordTerms,
      );

      final languageId = widget.language.id!;
      final dueCount =
          await db.reviewCards.getDueCount(languageId, scope: dueScope);
      final practiceCount =
          await db.reviewCards.getDueCount(languageId, scope: practiceScope);

      if (!mounted) return;
      setState(() {
        _dueScope = dueScope;
        _practiceScope = practiceScope;
        _dueCount = dueCount;
        _practiceCount = practiceCount;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('Text-scoped review scan failed',
          error: e, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _start({required bool graded}) {
    final scope = graded ? _dueScope : _practiceScope;
    if (scope == null) return;

    Navigator.pop(
      context,
      ReviewSessionSpec(
        language: widget.language,
        scope: scope,
        graded: graded,
        sourceTextId: widget.text.id,
        sourceTextTitle: widget.text.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingL,
                0,
                AppConstants.spacingL,
                AppConstants.spacingM,
              ),
              child: Text(
                widget.text.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isLoading)
              ListTile(
                leading: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text(l10n.scanningText),
              )
            else if (_error != null)
              ListTile(
                leading: Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error),
                title: Text(l10n.failedToLoadData),
              )
            else if (_dueCount == 0 && _practiceCount == 0)
              ListTile(
                leading: const Icon(Icons.inbox_outlined),
                title: Text(l10n.textReviewNoWords),
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.school),
                title: Text(l10n.textReviewDue(_dueCount)),
                enabled: _dueCount > 0,
                onTap: () => _start(graded: true),
              ),
              ListTile(
                leading: const Icon(Icons.fitness_center),
                title: Text(l10n.textReviewPracticeAll(_practiceCount)),
                subtitle: Text(l10n.textReviewPracticeNote),
                enabled: _practiceCount > 0,
                onTap: () => _start(graded: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Second step: which exercise to run the scoped session with.
///
/// Pops with the builder for the chosen screen rather than navigating itself —
/// the caller pushes once this sheet has closed.
class _ExercisePickerSheet extends StatelessWidget {
  const _ExercisePickerSheet({required this.spec});

  final ReviewSessionSpec spec;

  void _push(BuildContext context, Widget screen) {
    Navigator.pop<WidgetBuilder>(context, (_) => screen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = spec.language;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.style),
              title: Text(l10n.flashcardReview),
              onTap: () =>
                  _push(context, FlashcardReviewScreen(spec: spec)),
            ),
            ListTile(
              leading: const Icon(Icons.keyboard),
              title: Text(l10n.typingSourceToTarget),
              onTap: () => _push(
                context,
                TypingReviewScreen(
                  spec: spec,
                  direction: TypingDirection.sourceToTarget,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.keyboard),
              title: Text(l10n.typingTargetToSource),
              onTap: () => _push(
                context,
                TypingReviewScreen(
                  spec: spec,
                  direction: TypingDirection.targetToSource,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.quiz),
              title: Text(l10n.multipleChoiceSourceToTarget),
              onTap: () => _push(
                context,
                MultipleChoiceReviewScreen(
                  spec: spec,
                  direction: MultipleChoiceDirection.sourceToTarget,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.quiz),
              title: Text(l10n.multipleChoiceTargetToSource),
              onTap: () => _push(
                context,
                MultipleChoiceReviewScreen(
                  spec: spec,
                  direction: MultipleChoiceDirection.targetToSource,
                ),
              ),
            ),
            if (language.showRomanization)
              ListTile(
                leading: const Icon(Icons.record_voice_over),
                title: Text(l10n.multipleChoiceRomanization),
                onTap: () => _push(
                  context,
                  MultipleChoiceReviewScreen(
                    spec: spec,
                    direction: MultipleChoiceDirection.romanization,
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: Text('${l10n.clozeReview} — ${l10n.clozeEasyMode}'),
              onTap: () => _push(
                context,
                ClozeReviewScreen(spec: spec, mode: ClozeMode.easy),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: Text('${l10n.clozeReview} — ${l10n.clozeAdvancedMode}'),
              onTap: () => _push(
                context,
                ClozeReviewScreen(spec: spec, mode: ClozeMode.advanced),
              ),
            ),
            if (language.splitByCharacter)
              ListTile(
                leading: const Icon(Icons.draw_outlined),
                title: Text(l10n.writingPractice),
                onTap: () => _push(context, StrokeReviewScreen(spec: spec)),
              ),
          ],
        ),
      ),
    );
  }
}
