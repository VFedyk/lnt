import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/domain/entities/language.dart';
import 'package:language_nerd_tools/domain/value_objects/text_parsing_defaults.dart';
import 'package:language_nerd_tools/l10n/generated/app_localizations.dart';
import 'package:language_nerd_tools/presentation/screens/language_edit_screen.dart';
import 'package:language_nerd_tools/service_locator.dart';
import 'package:language_nerd_tools/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Language? lang,
    {required void Function(Language?) onPop, bool openAdvanced = true}) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => onPop(await Navigator.push<Language>(
            context,
            MaterialPageRoute(builder: (_) => LanguageEditScreen(language: lang)),
          )),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  if (openAdvanced) await tester.tap(find.text('Advanced'));
  await tester.pumpAndSettle();
}

final _english = Language(id: 'l1', name: 'English', languageCode: 'en');

void main() {
  testWidgets('shows the effective pattern for a legacy stored value',
      (tester) async {
    final lang = _english.copyWith(regexpWordCharacters: r'[\p{L}\p{M}]+');
    await _pump(tester, lang, onPop: (_) {});
    expect(find.text(TextParsingDefaults.wordPattern), findsOneWidget);
  });

  testWidgets('invalid regex blocks save and keeps the screen open',
      (tester) async {
    Language? popped;
    await _pump(tester, _english, onPop: (l) => popped = l);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Sentence ending pattern (regex)'),
        '[');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(LanguageEditScreen), findsOneWidget);
    expect(popped, isNull);
  });

  testWidgets('reset restores the default', (tester) async {
    await _pump(tester, _english, onPop: (_) {});
    final field =
        find.widgetWithText(TextFormField, 'Sentence ending pattern (regex)');
    await tester.enterText(field, r'[.]');
    await tester.pump();
    await tester.tap(find.byTooltip('Reset to default').last);
    await tester.pump();
    expect(find.text(TextParsingDefaults.sentencePattern), findsOneWidget);
  });

  group('System Dictionary switch', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await sl.reset();
      sl.registerSingleton<SettingsService>(SettingsService());
    });
    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await sl.reset();
    });

    testWidgets('hidden for a new language on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await _pump(tester, null, onPop: (_) {}, openAdvanced: false);
      expect(find.text('System Dictionary'), findsNothing);
      debugDefaultTargetPlatformOverride = null; // checked before tearDown
    });

    testWidgets('hidden on Android when editing', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await _pump(tester, _english, onPop: (_) {}, openAdvanced: false);
      expect(find.text('System Dictionary'), findsNothing);
      debugDefaultTargetPlatformOverride = null; // checked before tearDown
    });

    testWidgets('shown on iOS when editing; off + Save stores false',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      Language? popped;
      await _pump(tester, _english,
          onPop: (l) => popped = l, openAdvanced: false);
      expect(find.text('System Dictionary'), findsOneWidget);

      await tester.tap(find.text('System Dictionary'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null; // checked before tearDown

      expect(popped, isNotNull);
      expect(await sl<SettingsService>().getSystemDictionaryEnabled('l1'),
          isFalse);
    });
  });

  testWidgets('word field is disabled when splitting by character',
      (tester) async {
    final zh = Language(
        id: 'l2', name: 'Chinese', languageCode: 'zh', splitByCharacter: true);
    await _pump(tester, zh, onPop: (_) {});
    final word = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Word pattern (regex)'),
          matching: find.byType(TextField),
        ));
    expect(word.enabled, isFalse);
  });
}
