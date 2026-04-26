import 'dart:convert';

/// Wrapper holding the DB row alongside the serialized FSRS card data.
class ReviewCardRecord {
  final String? id;
  final String termId;
  final Map<String, dynamic> cardData;
  final DateTime nextDue;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReviewCardRecord({
    this.id,
    required this.termId,
    required this.cardData,
    required this.nextDue,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'term_id': termId,
      'card_data': jsonEncode(cardData),
      'next_due': nextDue.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory ReviewCardRecord.fromMap(Map<String, dynamic> map) {
    return ReviewCardRecord(
      id: map['id'] as String?,
      termId: map['term_id'] as String,
      cardData: jsonDecode(map['card_data'] as String) as Map<String, dynamic>,
      nextDue: DateTime.parse(map['next_due'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  ReviewCardRecord copyWith({
    String? id,
    String? termId,
    Map<String, dynamic>? cardData,
    DateTime? nextDue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReviewCardRecord(
      id: id ?? this.id,
      termId: termId ?? this.termId,
      cardData: cardData ?? this.cardData,
      nextDue: nextDue ?? this.nextDue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
