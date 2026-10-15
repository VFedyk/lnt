import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/domain/entities/dictionary.dart';

void main() {
  test('Dictionary.system is a valid system entry', () {
    final d = Dictionary.system('l1');
    expect(d.isSystem, isTrue);
    expect(d.isValidUrl, isTrue);
    expect(d.languageId, 'l1');
  });

  test('a normal dictionary is not a system entry', () {
    final d = Dictionary(languageId: 'l1', name: 'X', url: 'https://x/###');
    expect(d.isSystem, isFalse);
  });
}
