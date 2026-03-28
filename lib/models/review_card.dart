import 'dart:convert';
import 'package:fsrs/fsrs.dart' as fsrs;

/// Wrapper holding the DB row alongside the deserialized FSRS Card.
class ReviewCardRecord {
  final String? id;
  final String termId;
  final fsrs.Card card;
  final DateTime nextDue;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReviewCardRecord({
    this.id,
    required this.termId,
    required this.card,
    required this.nextDue,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'term_id': termId,
      'card_data': jsonEncode(card.toMap()),
      'next_due': nextDue.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory ReviewCardRecord.fromMap(Map<String, dynamic> map) {
    final cardMap =
        jsonDecode(map['card_data'] as String) as Map<String, dynamic>;
    final card = fsrs.Card.fromMap(cardMap);
    return ReviewCardRecord(
      id: map['id'] as String?,
      termId: map['term_id'] as String,
      card: card,
      nextDue: DateTime.parse(map['next_due'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  ReviewCardRecord copyWith({
    String? id,
    String? termId,
    fsrs.Card? card,
    DateTime? nextDue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReviewCardRecord(
      id: id ?? this.id,
      termId: termId ?? this.termId,
      card: card ?? this.card,
      nextDue: nextDue ?? this.nextDue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
