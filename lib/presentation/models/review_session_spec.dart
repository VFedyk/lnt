import '../../domain/entities/language.dart';
import '../../domain/value_objects/review_scope.dart';

/// Everything an exercise screen needs to know about the session it is running.
class ReviewSessionSpec {
  const ReviewSessionSpec({
    required this.language,
    this.scope = const ReviewScope(),
    this.graded = true,
    this.sourceTextId,
    this.sourceTextTitle,
  });

  /// The ordinary, whole-language session started from the review screen.
  factory ReviewSessionSpec.forLanguage(
    Language language,
    List<int>? statuses,
  ) =>
      ReviewSessionSpec(
        language: language,
        scope: ReviewScope(statuses: statuses),
      );

  final Language language;
  final ReviewScope scope;

  /// When false the session is a practice pass: ratings advance the deck but
  /// write nothing — no review log, no card update, no status log, no FSRS
  /// state change.
  final bool graded;

  /// Set when the session was started from a text; drives the app-bar subtitle
  /// and keeps the reread suggestion from proposing the text just reviewed.
  final String? sourceTextId;
  final String? sourceTextTitle;
}
