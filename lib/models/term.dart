// FILE: lib/models/term.dart
import 'package:flutter/material.dart';

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
  }) : createdAt = createdAt ?? DateTime.now(),
       lastAccessed = lastAccessed ?? DateTime.now();

  Color get statusColor {
    switch (status) {
      case 0:
        return Colors.grey.shade400;
      case 1:
        return Colors.red.shade400;
      case 2:
        return Colors.orange.shade400;
      case 3:
        return Colors.yellow.shade700;
      case 4:
        return Colors.lightGreen.shade500;
      case 5:
        return Colors.green.shade600;
      case 99:
        return Colors.blue.shade400;
      default:
        return Colors.grey;
    }
  }

  String get statusName {
    switch (status) {
      case 0:
        return 'Ignored';
      case 1:
        return 'Unknown';
      case 2:
        return 'Learning 2';
      case 3:
        return 'Learning 3';
      case 4:
        return 'Learning 4';
      case 5:
        return 'Known';
      case 99:
        return 'Well Known';
      default:
        return 'Unknown';
    }
  }

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
    );
  }
}
