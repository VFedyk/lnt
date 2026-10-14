import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/domain/entities/language.dart';
import 'package:language_nerd_tools/domain/value_objects/text_parsing_defaults.dart';
import 'package:language_nerd_tools/l10n/generated/app_localizations.dart';
import 'package:language_nerd_tools/presentation/screens/language_edit_screen.dart';

Future<void> _pump(WidgetTester tester, Language? lang,
    {required void Function(Language?) onPop}) async {
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
  await tester.tap(find.text('Advanced'));
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
