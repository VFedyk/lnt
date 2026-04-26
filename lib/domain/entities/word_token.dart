import 'term.dart';

class WordToken {
  final String text;
  final bool isWord;
  final Term? term;
  final int position;
  final int globalIndex; // Index in word tokens list for selection tracking

  WordToken({
    required this.text,
    required this.isWord,
    this.term,
    this.position = 0,
    this.globalIndex = -1,
  });

  WordToken copyWithIndex(int index) => WordToken(
    text: text,
    isWord: isWord,
    term: term,
    position: position,
    globalIndex: index,
  );
}
