// FILE: lib/models/term.dart

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

/// Part of speech categories
class PartOfSpeech {
  static const String noun = 'noun';
  static const String verb = 'verb';
  static const String adjective = 'adjective';
  static const String adverb = 'adverb';
  static const String pronoun = 'pronoun';
  static const String preposition = 'preposition';
  static const String conjunction = 'conjunction';
  static const String interjection = 'interjection';
  static const String article = 'article';
  static const String numeral = 'numeral';
  static const String particle = 'particle';
  static const String other = 'other';

  static const List<String> all = [
    noun,
    verb,
    adjective,
    adverb,
    pronoun,
    preposition,
    conjunction,
    interjection,
    article,
    numeral,
    particle,
    other,
  ];

}

/// A single translation/meaning for a term
class Translation {
  final String? id;
  final String termId;
  final String meaning;
  final String? partOfSpeech;
  final String? baseTranslationId;
  final int sortOrder;

  Translation({
    this.id,
    required this.termId,
    required this.meaning,
    this.partOfSpeech,
    this.baseTranslationId,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'term_id': termId,
      'meaning': meaning,
      'part_of_speech': partOfSpeech,
      'base_translation_id': baseTranslationId,
      'sort_order': sortOrder,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Translation.fromMap(Map<String, dynamic> map) {
    return Translation(
      id: map['id'] as String?,
      termId: map['term_id'] as String,
      meaning: map['meaning'] ?? '',
      partOfSpeech: map['part_of_speech'] as String?,
      baseTranslationId: map['base_translation_id'] as String?,
      sortOrder: map['sort_order'] ?? 0,
    );
  }

  Translation copyWith({
    String? id,
    String? termId,
    String? meaning,
    String? partOfSpeech,
    String? baseTranslationId,
    int? sortOrder,
    bool clearPartOfSpeech = false,
    bool clearBaseTranslationId = false,
  }) {
    return Translation(
      id: id ?? this.id,
      termId: termId ?? this.termId,
      meaning: meaning ?? this.meaning,
      partOfSpeech:
          clearPartOfSpeech ? null : (partOfSpeech ?? this.partOfSpeech),
      baseTranslationId: clearBaseTranslationId ? null : (baseTranslationId ?? this.baseTranslationId),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class Term {
  final String? id;
  final String languageId;
  final String text;
  final String lowerText;
  final int status;
  final String translation;
  final String romanization;
  final String sentence;
  final DateTime createdAt;
  final DateTime lastAccessed;
  final String?
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

  String get statusName => TermStatus.nameFor(status);

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
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
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Term.fromMap(Map<String, dynamic> map) {
    return Term(
      id: map['id'] as String?,
      languageId: map['language_id'] as String,
      text: map['text'] as String,
      lowerText: map['lower_text'] as String,
      status: map['status'] as int,
      translation: map['translation'] ?? '',
      romanization: map['romanization'] ?? '',
      sentence: map['sentence'] ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      lastAccessed: DateTime.parse(map['last_accessed'] as String),
      baseTermId: map['base_term_id'] as String?,
    );
  }

  Term copyWith({
    String? id,
    String? languageId,
    String? text,
    String? lowerText,
    int? status,
    String? translation,
    String? romanization,
    String? sentence,
    DateTime? createdAt,
    DateTime? lastAccessed,
    String? baseTermId,
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
