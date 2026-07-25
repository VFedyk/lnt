/// Narrows which review cards a session draws from.
///
/// Bundling the filters into one value object keeps the three due-query methods
/// symmetric and leaves room for future scopes (collection, tag, dictionary)
/// without growing their parameter lists again.
class ReviewScope {
  const ReviewScope({
    this.statuses,
    this.textId,
    this.extraTermIds = const [],
    this.includeNotDue = false,
  });

  /// Term statuses to include; null or empty means no status filter.
  final List<int>? statuses;

  /// Restrict to terms occurring in this text (via the text_words index).
  final String? textId;

  /// Term ids to include on top of [textId] — used for multi-word terms,
  /// which the word index cannot represent. Capped at 400 by callers.
  final List<String> extraTermIds;

  /// When true, cards not yet due are returned after the due ones.
  final bool includeNotDue;

  bool get isUnscoped =>
      (statuses == null || statuses!.isEmpty) &&
      textId == null &&
      extraTermIds.isEmpty &&
      !includeNotDue;
}
