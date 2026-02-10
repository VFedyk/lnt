class Language {
  final int? id;
  final String name;
  final String languageCode; // ISO 639-1 code (e.g., 'en', 'de', 'uk')
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
    required this.languageCode,
    this.rightToLeft = false,
    this.showRomanization = false,
    this.splitByCharacter = false,
    this.characterSubstitutions = '',
    this.regexpWordCharacters = r"[\p{L}\p{M}]+(?:['''][\p{L}\p{M}]+)*",
    this.regexpSplitSentences = r'[.!?]+',
    this.exceptionsSplitSentences = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'language_code': languageCode,
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
      languageCode: map['language_code'] ?? '',
      rightToLeft: map['right_to_left'] == 1,
      showRomanization: map['show_romanization'] == 1,
      splitByCharacter: map['split_by_character'] == 1,
      characterSubstitutions: map['character_substitutions'] ?? '',
      regexpWordCharacters:
          map['regexp_word_characters'] ??
          r"[\p{L}\p{M}]+(?:['''][\p{L}\p{M}]+)*",
      regexpSplitSentences: map['regexp_split_sentences'] ?? r'[.!?]+',
      exceptionsSplitSentences: map['exceptions_split_sentences'] ?? '',
    );
  }

  /// Returns a flag emoji for this language, or empty string if unknown.
  String get flagEmoji {
    const langToCountry = {
      'ar': 'SA', 'bg': 'BG', 'cs': 'CZ', 'da': 'DK', 'de': 'DE',
      'el': 'GR', 'en': 'GB', 'es': 'ES', 'et': 'EE', 'fi': 'FI',
      'fr': 'FR', 'ga': 'IE', 'he': 'IL', 'hi': 'IN', 'hu': 'HU',
      'id': 'ID', 'it': 'IT', 'ja': 'JP', 'ko': 'KR', 'lt': 'LT',
      'lv': 'LV', 'nb': 'NO', 'nl': 'NL', 'pl': 'PL', 'pt': 'PT',
      'ro': 'RO', 'ru': 'RU', 'sk': 'SK', 'sl': 'SI', 'sv': 'SE',
      'th': 'TH', 'tr': 'TR', 'uk': 'UA', 'vi': 'VN', 'zh': 'CN',
    };
    final country = langToCountry[languageCode.toLowerCase()];
    if (country == null || country.length != 2) return '';
    final first = 0x1F1E6 + country.codeUnitAt(0) - 0x41;
    final second = 0x1F1E6 + country.codeUnitAt(1) - 0x41;
    return String.fromCharCodes([first, second]);
  }

  Language copyWith({
    int? id,
    String? name,
    String? languageCode,
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
      languageCode: languageCode ?? this.languageCode,
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
