import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../domain/entities/language.dart';
import '../domain/entities/text_document.dart';
import '../domain/repositories/text_word_repository.dart';
import 'isolate_parser.dart';
import 'text_parser_service.dart';

/// Builds and refreshes the local text ↔ word-form index (`text_words`).
///
/// The tokenization is deliberately **term-independent** — no terms map is fed
/// to the parser — so the index stays valid across term creation and deletion.
/// Only a change to the text's content invalidates it, which is detected via a
/// content hash rather than a timestamp.
class TextWordIndexService {
  TextWordIndexService({
    required TextWordRepository repo,
    TextParserService? parser,
  })  : _repo = repo,
        _parser = parser ?? TextParserService();

  final TextWordRepository _repo;
  final TextParserService _parser;

  static String contentHash(String content) =>
      sha1.convert(utf8.encode(content)).toString();

  /// Indexes [text] unless its content hash already matches. Returns true when
  /// an index exists afterwards.
  Future<bool> ensureIndexed(TextDocument text, Language language) async {
    final textId = text.id;
    if (textId == null) return false;

    final hash = contentHash(text.content);
    if (await _repo.indexedHash(textId) == hash) return true;

    final words = await _tokenize(text.content, language);
    await _repo.replaceIndex(textId, hash, _aggregate(words));
    return true;
  }

  /// Fast path: index from tokens the caller has already computed.
  /// [words] must be the plain tokenization — raw word strings with their
  /// positions, never term-bound tokens.
  Future<void> indexFromWords(
    String textId,
    String content,
    List<({String word, int position})> words,
  ) async {
    await _repo.replaceIndex(textId, contentHash(content), _aggregate(words));
  }

  Future<List<({String word, int position})>> _tokenize(
    String content,
    Language language,
  ) async {
    if (content.isEmpty) return const [];

    // jieba needs rootBundle, which a background isolate cannot reach — see the
    // comment block at the top of isolate_parser.dart.
    if (language.splitByCharacter && language.useWordSegmentation) {
      return _parser
          .getWordMatches(content, language)
          .map((m) => (word: m.word, position: m.start))
          .toList();
    }

    final tokens = await compute(
      parseInIsolate,
      ParseInput(
        content: content,
        splitByCharacter: language.splitByCharacter,
        characterSubstitutions: language.characterSubstitutions,
        regexpWordCharacters: language.regexpWordCharacters,
        // Empty on purpose: this is what keeps the index term-independent.
        termsMapData: const {},
      ),
    );
    return tokens
        .where((t) => t.isWord)
        .map((t) => (word: t.text, position: t.position))
        .toList();
  }

  Map<String, ({int occurrences, int firstPosition})> _aggregate(
    List<({String word, int position})> words,
  ) {
    final result = <String, ({int occurrences, int firstPosition})>{};
    for (final w in words) {
      final key = _parser.normalizeWord(w.word);
      if (key.isEmpty) continue;
      final existing = result[key];
      result[key] = existing == null
          ? (occurrences: 1, firstPosition: w.position)
          : (
              occurrences: existing.occurrences + 1,
              firstPosition: existing.firstPosition,
            );
    }
    return result;
  }
}
