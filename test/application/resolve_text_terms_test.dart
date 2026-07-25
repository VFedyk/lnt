import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/application/use_cases/texts/resolve_text_terms.dart';
import 'package:language_nerd_tools/domain/entities/language.dart';
import 'package:language_nerd_tools/domain/entities/term.dart';
import 'package:language_nerd_tools/domain/entities/text_document.dart';
import 'package:language_nerd_tools/domain/repositories/term_repository.dart';
import 'package:language_nerd_tools/domain/repositories/text_word_repository.dart';
import 'package:language_nerd_tools/domain/value_objects/term_status.dart';
import 'package:language_nerd_tools/services/text_word_index_service.dart';

class _FakeTextWordRepository implements TextWordRepository {
  final Map<String, String> hashes = {};

  @override
  Future<String?> indexedHash(String textId) async => hashes[textId];

  @override
  Future<void> replaceIndex(String textId, String contentHash,
      Map<String, ({int occurrences, int firstPosition})> words) async {
    hashes[textId] = contentHash;
  }

  @override
  Future<void> invalidate(String textId) async => hashes.remove(textId);

  @override
  Future<List<String>> termIdsInText(String textId, String languageId) async =>
      const [];

  @override
  Future<List<({String textId, String title, int hits})>> textsContainingTerms(
    String languageId,
    List<String> termIds, {
    int minHits = 2,
    int limit = 3,
  }) async =>
      const [];
}

/// Only [getMapByLanguage] is exercised; everything else would be dead weight.
class _FakeTermRepository implements TermRepository {
  _FakeTermRepository(this.map);

  final Map<String, Term> map;
  int getMapCalls = 0;

  @override
  Future<Map<String, Term>> getMapByLanguage(String languageId) async {
    getMapCalls++;
    return map;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Term _term(String id, String lowerText) => Term(
      id: id,
      languageId: 'lang-1',
      text: lowerText,
      lowerText: lowerText,
      status: TermStatus.learning2,
    );

TextDocument _text(String content) => TextDocument(
      id: 'x1',
      languageId: 'lang-1',
      title: 'T',
      content: content,
    );

final _english = Language(id: 'lang-1', name: 'English', languageCode: 'en');
final _characterSplit = Language(
  id: 'lang-1',
  name: 'Chinese',
  languageCode: 'zh',
  splitByCharacter: true,
);

({ResolveTextTerms resolve, _FakeTextWordRepository index}) _useCase(
  Map<String, Term> terms, {
  _FakeTermRepository? repo,
}) {
  final index = _FakeTextWordRepository();
  return (
    resolve: ResolveTextTerms(
      index: TextWordIndexService(repo: index),
      terms: repo ?? _FakeTermRepository(terms),
    ),
    index: index,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('detects multi-word terms present in a space-separated text', () async {
    final resolve = _useCase({
      'give up': _term('t-phrase', 'give up'),
      'not here': _term('t-absent', 'not here'),
      'give': _term('t-single', 'give'),
    }).resolve;

    final scope = await resolve(_text('I will give up soon.'), _english);

    // Single-word terms come from the index, not the extras list.
    expect(scope.extraTermIds, ['t-phrase']);
    expect(scope.textId, 'x1');
    expect(scope.includeNotDue, isFalse);
  });

  test('treats multi-character terms as multi-word when splitting by character',
      () async {
    final resolve = _useCase({
      '你好': _term('t-pair', '你好'),
      '再见': _term('t-absent', '再见'),
      '你': _term('t-single', '你'),
    }).resolve;

    final scope = await resolve(_text('你好世界'), _characterSplit);

    expect(scope.extraTermIds, ['t-pair']);
  });

  test('jieba languages treat only spaced forms as multi-word', () async {
    final segmented = Language(
      id: 'lang-1',
      name: 'Chinese',
      languageCode: 'zh',
      splitByCharacter: true,
      useWordSegmentation: true,
    );
    final deps = _useCase({'你好': _term('t-pair', '你好')});
    final text = _text('你好世界');
    // jieba cannot run in a unit test, so pre-warm the index the way the reader
    // would; ensureIndexed then short-circuits on the matching hash.
    deps.index.hashes[text.id!] = TextWordIndexService.contentHash(text.content);

    // With segmentation on, 你好 is a single index token — no extra needed.
    final scope = await deps.resolve(text, segmented);
    expect(scope.extraTermIds, isEmpty);
  });

  test('caps extras at 400', () async {
    final terms = <String, Term>{};
    final buffer = StringBuffer();
    for (var i = 0; i < 450; i++) {
      final key = 'phrase $i';
      terms[key] = _term('t$i', key);
      buffer.write('$key ');
    }
    final resolve = _useCase(terms).resolve;

    final scope = await resolve(_text(buffer.toString()), _english);
    expect(scope.extraTermIds.length, ResolveTextTerms.maxExtraTermIds);
  });

  test('the reader fast path skips the content scan entirely', () async {
    final repo = _FakeTermRepository({'give up': _term('t-phrase', 'give up')});
    final resolve = _useCase(const {}, repo: repo).resolve;

    final scope = await resolve(
      _text('unrelated content'),
      _english,
      knownMultiWordTerms: [_term('t-known', 'give up')],
    );

    expect(scope.extraTermIds, ['t-known']);
    expect(repo.getMapCalls, 0);
  });

  test('passes statuses and includeNotDue through', () async {
    final resolve = _useCase(const {}).resolve;

    final scope = await resolve(
      _text('hello'),
      _english,
      statuses: [TermStatus.known],
      includeNotDue: true,
    );

    expect(scope.statuses, [TermStatus.known]);
    expect(scope.includeNotDue, isTrue);
  });
}
