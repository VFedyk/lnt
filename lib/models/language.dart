class Language {
  final int? id;
  final String name;
  final bool rightToLeft;
  final bool showRomanization;
  final bool splitByCharacter; // For languages like Chinese/Japanese
  final String characterSubstitutions;
  final String regexpWordCharacters;
  final String regexpSplitSentences;
  final String exceptionsSplitSentences;

  Language({
    this.id,
    required this.name,
    this.rightToLeft = false,
    this.showRomanization = false,
    this.splitByCharacter = false,
    this.characterSubstitutions = '',
    this.regexpWordCharacters = r'[\p{L}\p{M}]+',
    this.regexpSplitSentences = r'[.!?]+',
    this.exceptionsSplitSentences = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'right_to_left': rightToLeft ? 1 : 0,
      'show_romanization': showRomanization ? 1 : 0,
      'split_by_character': splitByCharacter ? 1 : 0,
      'character_substitutions': characterSubstitutions,
      'regexp_word_characters': regexpWordCharacters,
      'regexp_split_sentences': regexpSplitSentences,
      'exceptions_split_sentences': exceptionsSplitSentences,
    };
  }

  factory Language.fromMap(Map<String, dynamic> map) {
    return Language(
      id: map['id'],
      name: map['name'],
      rightToLeft: map['right_to_left'] == 1,
      showRomanization: map['show_romanization'] == 1,
      splitByCharacter: map['split_by_character'] == 1,
      characterSubstitutions: map['character_substitutions'] ?? '',
      regexpWordCharacters: map['regexp_word_characters'] ?? r'[\p{L}\p{M}]+',
      regexpSplitSentences: map['regexp_split_sentences'] ?? r'[.!?]+',
      exceptionsSplitSentences: map['exceptions_split_sentences'] ?? '',
    );
  }

  Language copyWith({
    int? id,
    String? name,
    bool? rightToLeft,
    bool? showRomanization,
    bool? splitByCharacter,
    String? characterSubstitutions,
    String? regexpWordCharacters,
    String? regexpSplitSentences,
    String? exceptionsSplitSentences,
  }) {
    return Language(
      id: id ?? this.id,
      name: name ?? this.name,
      rightToLeft: rightToLeft ?? this.rightToLeft,
      showRomanization: showRomanization ?? this.showRomanization,
      splitByCharacter: splitByCharacter ?? this.splitByCharacter,
      characterSubstitutions:
          characterSubstitutions ?? this.characterSubstitutions,
      regexpWordCharacters: regexpWordCharacters ?? this.regexpWordCharacters,
      regexpSplitSentences: regexpSplitSentences ?? this.regexpSplitSentences,
      exceptionsSplitSentences:
          exceptionsSplitSentences ?? this.exceptionsSplitSentences,
    );
  }
}
