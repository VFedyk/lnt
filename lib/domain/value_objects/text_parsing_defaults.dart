/// Canonical tokenizer/splitter defaults.
///
/// These are also the *sentinels* `TextParserService` recognises: a language
/// row whose stored pattern is one of the legacy values below is treated as
/// unconfigured and gets the current default, because there is deliberately no
/// migration rewriting those rows (see docs/sentence-mining-plan.md).
class TextParsingDefaults {
  /// Letters and combining marks, joined by any apostrophe form.
  static const wordPattern = r"[\p{L}\p{M}]+(?:['’ʼ‘][\p{L}\p{M}]+)*";

  /// Terminal punctuation, Latin + CJK + ellipsis.
  static const sentencePattern = r'[.!?…‽。！？｡]+';

  /// Applied when a language stores no exception list of its own.
  static const abbreviations =
      'Mr.|Mrs.|Ms.|Dr.|Prof.|St.|Jr.|Sr.|vs.|etc.|e.g.|i.e.|cf.|approx.|'
      'No.|Fig.|Vol.|Ch.|pp.|Ave.|Rd.|Inc.|Ltd.|Co.';

  /// Historical values that must be read as "unconfigured". Never remove an
  /// entry: rows in the wild still hold them.
  static const legacyWordPatterns = <String>{
    '',
    r'[\p{L}\p{M}]+',
    // Shipped default up to 2026-09; the class holds three ASCII apostrophes,
    // so U+2019 — the apostrophe real texts use — never matched.
    r"[\p{L}\p{M}]+(?:['''][\p{L}\p{M}]+)*",
  };

  static const legacySentencePatterns = <String>{'', r'[.!?]+'};
}
