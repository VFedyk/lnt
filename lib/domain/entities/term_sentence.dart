class TermSentence {
  final String? id;
  final String termId;
  final String sentence;
  final String? sourceTextId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TermSentence({
    this.id,
    required this.termId,
    required this.sentence,
    this.sourceTextId,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'term_id': termId,
        'sentence': sentence,
        'source_text_id': sourceTextId,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': (updatedAt ?? createdAt).toUtc().toIso8601String(),
      };

  static TermSentence fromMap(Map<String, dynamic> map) => TermSentence(
        id: map['id'] as String?,
        termId: map['term_id'] as String,
        sentence: map['sentence'] as String,
        sourceTextId: map['source_text_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: (map['updated_at'] as String?) != null
            ? DateTime.parse(map['updated_at'] as String)
            : null,
      );
}

/// Buffered sentence changes flushed on Save. Cancel discards everything, and
/// the new-term case (no `term_id` yet) uses the same code path as an existing
/// term — the ids in [edited] / [deleted] refer to already-persisted rows.
class TermSentenceEdits {
  final List<String> added; // new sentence texts
  final Map<String, String> edited; // existing id -> new text
  final List<String> deleted; // existing ids

  const TermSentenceEdits({
    this.added = const [],
    this.edited = const {},
    this.deleted = const [],
  });

  static const empty = TermSentenceEdits();

  bool get isEmpty => added.isEmpty && edited.isEmpty && deleted.isEmpty;
}
