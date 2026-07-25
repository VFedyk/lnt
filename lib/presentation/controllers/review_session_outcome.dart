import 'package:fsrs/fsrs.dart' as fsrs;

/// Accumulates what went wrong during one review session so the completion
/// screen can act on it. Deliberately a plain object, not a ChangeNotifier —
/// nothing observes it mid-session.
class ReviewSessionOutcome {
  final Set<String> failedTermIds = {};
  int reviewedCount = 0;

  /// FSRS Rating.again is the only rating that counts as a failure. Recorded in
  /// practice mode too: failing a word there is still signal, even though the
  /// pass writes nothing.
  void record(String termId, fsrs.Rating rating) {
    reviewedCount++;
    if (rating == fsrs.Rating.again) failedTermIds.add(termId);
  }
}
