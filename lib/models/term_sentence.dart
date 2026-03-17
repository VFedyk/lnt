class TermSentence {
  final int? id;
  final int termId;
  final String sentence;
  final int? sourceTextId;
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
        id: map['id'] as int?,
        termId: map['term_id'] as int,
        sentence: map['sentence'] as String,
        sourceTextId: map['source_text_id'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
