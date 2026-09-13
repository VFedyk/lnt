import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/data/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_tts');
  late List<MethodCall> calls;
  late int setLanguageResult;

  setUp(() {
    calls = [];
    setLanguageResult = 1;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'setLanguage' ? setLanguageResult : 1;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<MethodCall> setLanguageCalls() =>
      calls.where((c) => c.method == 'setLanguage').toList();

  test('sets the language once while it is unchanged', () async {
    final tts = TtsService();
    await tts.speak('hallo', 'de');
    await tts.speak('welt', 'de');

    expect(setLanguageCalls(), hasLength(1));
    expect(calls.where((c) => c.method == 'speak'), hasLength(2));
  });

  test('retries setLanguage after the platform rejects it', () async {
    final tts = TtsService();
    setLanguageResult = 0;
    await tts.speak('привіт', 'uk');
    setLanguageResult = 1;
    await tts.speak('привіт', 'uk');
    await tts.speak('привіт', 'uk');

    expect(setLanguageCalls(), hasLength(2));
    expect(calls.where((c) => c.method == 'speak'), hasLength(3));
  });

  test('ignores empty text or language', () async {
    final tts = TtsService();
    await tts.speak('', 'de');
    await tts.speak('hallo', '');

    expect(calls, isEmpty);
  });
}
