class TermSentence {
  final String? id;
  final String termId;
  final String sentence;
  final String? sourceTextId;
  final DateTime createdAt;

  const TermSentence({
    this.id,
    required this.termId,
    required this.sentence,
    this.sourceTextId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'term_id': termId,
        'sentence': sentence,
        'source_text_id': sourceTextId,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  static TermSentence fromMap(Map<String, dynamic> map) => TermSentence(
        id: map['id'] as String?,
        termId: map['term_id'] as String,
        sentence: map['sentence'] as String,
        sourceTextId: map['source_text_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
