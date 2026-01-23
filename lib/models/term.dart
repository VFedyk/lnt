// FILE: lib/models/term.dart
import 'package:flutter/material.dart';

/// Centralized definition of term statuses with their colors and names
class TermStatus {
  static const int ignored = 0;
  static const int unknown = 1;
  static const int learning2 = 2;
  static const int learning3 = 3;
  static const int learning4 = 4;
  static const int known = 5;
  static const int wellKnown = 99;

  static const List<int> allStatuses = [
    ignored,
    unknown,
    learning2,
    learning3,
    learning4,
    known,
    wellKnown,
  ];

  static Color colorFor(int status) {
    switch (status) {
      case ignored:
        return Colors.grey.shade400;
      case unknown:
        return Colors.red.shade400;
      case learning2:
        return Colors.orange.shade400;
      case learning3:
        return Colors.yellow.shade700;
      case learning4:
        return Colors.lightGreen.shade500;
      case known:
        return Colors.green.shade600;
      case wellKnown:
        return Colors.blue.shade400;
      default:
        return Colors.red.shade400;
    }
  }

  static String nameFor(int status) {
    switch (status) {
      case ignored:
        return 'Ignored';
      case unknown:
        return 'Unknown';
      case learning2:
        return 'Learning 2';
      case learning3:
        return 'Learning 3';
      case learning4:
        return 'Learning 4';
      case known:
        return 'Known';
      case wellKnown:
        return 'Well Known';
      default:
        return 'Unknown';
    }
  }
}

class Term {
  final int? id;
  final int languageId;
  final String text;
  final String lowerText;
  final int status;
  final String translation;
  final String romanization;
  final String sentence;
  final DateTime createdAt;
  final DateTime lastAccessed;
  final int?
  baseTermId; // Reference to base form term (e.g., "hablar" for "hablo")

  Term({
    this.id,
    required this.languageId,
    required this.text,
    required this.lowerText,
    this.status = 1,
    this.translation = '',
    this.romanization = '',
    this.sentence = '',
    DateTime? createdAt,
    DateTime? lastAccessed,
    this.baseTermId,
  }) : createdAt = createdAt ?? DateTime.now(),
       lastAccessed = lastAccessed ?? DateTime.now();

  Color get statusColor => TermStatus.colorFor(status);

  String get statusName => TermStatus.nameFor(status);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'language_id': languageId,
      'text': text,
      'lower_text': lowerText,
      'status': status,
      'translation': translation,
      'romanization': romanization,
      'sentence': sentence,
      'created_at': createdAt.toIso8601String(),
      'last_accessed': lastAccessed.toIso8601String(),
      'base_term_id': baseTermId,
    };
  }

  factory Term.fromMap(Map<String, dynamic> map) {
    return Term(
      id: map['id'],
      languageId: map['language_id'],
      text: map['text'],
      lowerText: map['lower_text'],
      status: map['status'],
      translation: map['translation'] ?? '',
      romanization: map['romanization'] ?? '',
      sentence: map['sentence'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      lastAccessed: DateTime.parse(map['last_accessed']),
      baseTermId: map['base_term_id'] as int?,
    );
  }

  Term copyWith({
    int? id,
    int? languageId,
    String? text,
    String? lowerText,
    int? status,
    String? translation,
    String? romanization,
    String? sentence,
    DateTime? createdAt,
    DateTime? lastAccessed,
    int? baseTermId,
    bool clearBaseTermId = false,
  }) {
    return Term(
      id: id ?? this.id,
      languageId: languageId ?? this.languageId,
      text: text ?? this.text,
      lowerText: lowerText ?? this.lowerText,
      status: status ?? this.status,
      translation: translation ?? this.translation,
      romanization: romanization ?? this.romanization,
      sentence: sentence ?? this.sentence,
      createdAt: createdAt ?? this.createdAt,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      baseTermId: clearBaseTermId ? null : (baseTermId ?? this.baseTermId),
    );
  }
}
