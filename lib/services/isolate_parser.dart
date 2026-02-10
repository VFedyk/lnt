import 'dart:developer' as developer;
import '../models/language.dart';
import 'text_parser_service.dart';

/// Data passed to isolate for parsing
class ParseInput {
  final String content;
  final bool splitByCharacter;
  final String characterSubstitutions;
  final String regexpWordCharacters;
  final Map<String, Map<String, dynamic>> termsMapData; // Serialized terms

  ParseInput({
    required this.content,
    required this.splitByCharacter,
    required this.characterSubstitutions,
    required this.regexpWordCharacters,
    required this.termsMapData,
  });
}

/// Result from isolate parsing
class ParsedToken {
  final String text;
  final bool isWord;
  final int position;
  final String? termLowerText; // Reference to term by lowerText

  ParsedToken({
    required this.text,
    required this.isWord,
    required this.position,
    this.termLowerText,
  });
}

/// Top-level function for isolate parsing - O(n) algorithm
List<ParsedToken> parseInIsolate(ParseInput input) {
  final totalStopwatch = Stopwatch()..start();
  final stepWatch = Stopwatch();

  final parser = TextParserService();
  final tokens = <ParsedToken>[];
  final content = input.content;

  // Build term keys set for O(1) lookup
  stepWatch.start();
  final termKeys = input.termsMapData.keys.toSet();
  developer.log(
    '[PARSE] Build termKeys set: ${stepWatch.elapsedMilliseconds}ms (${termKeys.length} terms)',
  );
  stepWatch.reset();

  // Create language for word matching
  final tempLang = Language(
    name: '',
    languageCode: '',
    splitByCharacter: input.splitByCharacter,
    characterSubstitutions: input.characterSubstitutions,
    regexpWordCharacters: input.regexpWordCharacters,
  );

  // Get word matches with positions - O(n)
  stepWatch.start();
  final wordMatches = parser.getWordMatches(content, tempLang);
  developer.log(
    '[PARSE] getWordMatches: ${stepWatch.elapsedMilliseconds}ms (${wordMatches.length} words)',
  );
  stepWatch.reset();

  // Get multi-word terms for phrase matching
  stepWatch.start();
  final multiWordTerms = <String, String>{}; // lowerText -> originalText
  for (final entry in input.termsMapData.entries) {
    if (entry.key.contains(' ') ||
        (input.splitByCharacter && entry.key.length > 1)) {
      multiWordTerms[entry.key] = entry.value['text'] as String;
    }
  }
  final sortedMultiWordKeys = multiWordTerms.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  developer.log(
    '[PARSE] Build multi-word terms: ${stepWatch.elapsedMilliseconds}ms (${sortedMultiWordKeys.length} terms)',
  );
  stepWatch.reset();

  // Main parsing loop - O(n)
  stepWatch.start();
  int lastEnd = 0;
  int matchIndex = 0;

  while (matchIndex < wordMatches.length) {
    final match = wordMatches[matchIndex];

    // Add non-word text before this word
    if (match.start > lastEnd) {
      tokens.add(
        ParsedToken(
          text: content.substring(lastEnd, match.start),
          isWord: false,
          position: lastEnd,
        ),
      );
    }

    // Check if this word starts a multi-word term
    bool foundMultiWord = false;
    for (final termKey in sortedMultiWordKeys) {
      final termText = multiWordTerms[termKey]!;
      final endPos = match.start + termText.length;

      if (endPos <= content.length) {
        final substring = content.substring(match.start, endPos);
        if (substring.toLowerCase() == termText.toLowerCase()) {
          tokens.add(
            ParsedToken(
              text: substring,
              isWord: true,
              position: match.start,
              termLowerText: termKey,
            ),
          );

          // Skip all word matches that are within this multi-word term
          lastEnd = endPos;
          while (matchIndex < wordMatches.length &&
              wordMatches[matchIndex].start < endPos) {
            matchIndex++;
          }
          foundMultiWord = true;
          break;
        }
      }
    }

    if (foundMultiWord) continue;

    // Add single word token
    final lowerWord = parser.normalizeWord(match.word);
    tokens.add(
      ParsedToken(
        text: match.word,
        isWord: true,
        position: match.start,
        termLowerText: termKeys.contains(lowerWord) ? lowerWord : null,
      ),
    );

    lastEnd = match.end;
    matchIndex++;
  }

  // Add any remaining text after last word
  if (lastEnd < content.length) {
    tokens.add(
      ParsedToken(
        text: content.substring(lastEnd),
        isWord: false,
        position: lastEnd,
      ),
    );
  }

  developer.log(
    '[PARSE] Main loop: ${stepWatch.elapsedMilliseconds}ms (${tokens.length} tokens)',
  );
  stepWatch.reset();

  totalStopwatch.stop();
  developer.log('[PARSE] TOTAL: ${totalStopwatch.elapsedMilliseconds}ms');

  return tokens;
}
