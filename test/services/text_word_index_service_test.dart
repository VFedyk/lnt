import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/domain/entities/language.dart';
import 'package:language_nerd_tools/domain/entities/text_document.dart';
import 'package:language_nerd_tools/domain/repositories/text_word_repository.dart';
import 'package:language_nerd_tools/domain/value_objects/text_parsing_defaults.dart';
import 'package:language_nerd_tools/services/text_word_index_service.dart';

/// Records what the service asked it to do so tests can assert on writes
/// (in particular: that the hash short-circuit performs none).
class _SpyTextWordRepository implements TextWordRepository {
  final Map<String, String> hashes = {};
  final Map<String, Map<String, ({int occurrences, int firstPosition})>>
      indexes = {};
  int replaceCalls = 0;

  @override
  Future<String?> indexedHash(String textId) async => hashes[textId];

  @override
  Future<void> replaceIndex(
    String textId,
    String contentHash,
    Map<String, ({int occurrences, int firstPosition})> words,
  ) async {
    replaceCalls++;
    hashes[textId] = contentHash;
    indexes[textId] = words;
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

TextDocument _text(String content, {String id = 'x1'}) => TextDocument(
      id: id,
      languageId: 'lang-1',
      title: 'T',
      content: content,
    );

final _english = Language(id: 'lang-1', name: 'English', languageCode: 'en');
final _characterSplit = Language(
  id: 'lang-2',
  name: 'Chinese',
  languageCode: 'zh',
  splitByCharacter: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SpyTextWordRepository repo;
  late TextWordIndexService service;

  setUp(() {
    repo = _SpyTextWordRepository();
    service = TextWordIndexService(repo: repo);
  });

  test('contentHash is stable and content-sensitive', () {
    expect(
      TextWordIndexService.contentHash('hello'),
      TextWordIndexService.contentHash('hello'),
    );
    expect(
      TextWordIndexService.contentHash('hello'),
      isNot(TextWordIndexService.contentHash('hello ')),
    );
  });

  test('indexes words with occurrence counts and first positions', () async {
    final ok = await service.ensureIndexed(
      _text('The cat sat on the mat, the cat.'),
      _english,
    );

    expect(ok, isTrue);
    final index = repo.indexes['x1']!;
    expect(index['the']!.occurrences, 3);
    expect(index['the']!.firstPosition, 0);
    expect(index['cat']!.occurrences, 2);
    expect(index['cat']!.firstPosition, 4);
    expect(index.containsKey('mat'), isTrue);
    // Normalized: no punctuation-only or empty keys.
    expect(index.keys.any((k) => k.trim().isEmpty), isFalse);
  });

  test('second call with unchanged content performs no write', () async {
    final text = _text('alpha beta');
    await service.ensureIndexed(text, _english);
    expect(repo.replaceCalls, 1);

    await service.ensureIndexed(text, _english);
    expect(repo.replaceCalls, 1);
  });

  test('reindexes after the content changes', () async {
    await service.ensureIndexed(_text('alpha beta'), _english);
    await service.ensureIndexed(_text('gamma delta'), _english);

    expect(repo.replaceCalls, 2);
    expect(repo.indexes['x1']!.keys.toSet(), {'gamma', 'delta'});
  });

  test('splitByCharacter indexes single characters', () async {
    await service.ensureIndexed(_text('你好你'), _characterSplit);

    final index = repo.indexes['x1']!;
    expect(index.keys.toSet(), {'你', '好'});
    expect(index['你']!.occurrences, 2);
    expect(index['好']!.firstPosition, 1);
  });

  test('returns false and writes nothing for a text with no id', () async {
    final ok = await service.ensureIndexed(
      TextDocument(languageId: 'lang-1', title: 'T', content: 'alpha'),
      _english,
    );
    expect(ok, isFalse);
    expect(repo.replaceCalls, 0);
  });

  test('empty content still records the hash with no words', () async {
    await service.ensureIndexed(_text(''), _english);
    expect(repo.indexes['x1'], isEmpty);
    expect(repo.hashes['x1'], TextWordIndexService.indexHash('', _english));
  });

  test('reindexes when the word pattern changes, not when it is unchanged',
      () async {
    final text = _text('alpha-beta gamma');
    await service.ensureIndexed(text, _english);
    expect(repo.indexes['x1']!.keys.toSet(), {'alpha', 'beta', 'gamma'});

    await service.ensureIndexed(text, _english);
    expect(repo.replaceCalls, 1);

    final custom = _english.copyWith(regexpWordCharacters: r'[\p{L}\-]+');
    await service.ensureIndexed(text, custom);
    expect(repo.replaceCalls, 2);
    expect(repo.indexes['x1']!.keys.toSet(), {'alpha-beta', 'gamma'});
  });

  test('a legacy stored pattern hashes the same as the default', () {
    final legacy = _english.copyWith(regexpWordCharacters: r'[\p{L}\p{M}]+');
    final current = _english.copyWith(
      regexpWordCharacters: TextParsingDefaults.wordPattern,
    );
    expect(
      TextWordIndexService.indexHash('x', legacy),
      TextWordIndexService.indexHash('x', current),
    );
  });
}
