import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/domain/entities/language.dart';
import 'package:language_nerd_tools/l10n/generated/app_localizations.dart';
import 'package:language_nerd_tools/presentation/widgets/languages/language_presets.dart';
import 'package:language_nerd_tools/presentation/widgets/shared/language_quick_picker.dart';

Future<void> _pump(
  WidgetTester tester, {
  Set<String> existing = const {},
  Future<void> Function(LangPreset)? onSelected,
  VoidCallback? onCustom,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: LanguageQuickPicker(
        existingCodes: existing,
        onPresetSelected: onSelected ?? (_) async {},
        onCustomSettings: onCustom ?? () {},
      ),
    ),
  ));
}

void main() {
  testWidgets('shows popular chips when the query is empty', (tester) async {
    await _pump(tester);
    expect(find.text('Popular'), findsOneWidget);
    expect(find.byType(ActionChip), findsNWidgets(kPopularLangCodes.length));
    expect(find.text('All languages'), findsOneWidget);
  });

  testWidgets('hides existing languages from chips and list', (tester) async {
    await _pump(tester, existing: {'de'});
    expect(find.textContaining('German'), findsNothing);
    expect(find.byType(ActionChip), findsNWidgets(kPopularLangCodes.length - 1));
  });

  testWidgets('search filters by name and by code', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'germ');
    await tester.pump();
    expect(find.byType(ActionChip), findsNothing);
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('German'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'de');
    await tester.pump();
    expect(find.text('German'), findsOneWidget);
  });

  testWidgets('no match shows the empty text and keeps custom settings',
      (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'zzzzqq');
    await tester.pump();
    expect(find.text('No matching languages'), findsOneWidget);
    expect(find.text('Custom settings…'), findsOneWidget);
  });

  testWidgets('tap selects a preset; a second tap while pending is ignored',
      (tester) async {
    final completer = Completer<void>();
    final picked = <String>[];
    await _pump(tester, onSelected: (p) {
      picked.add(p.code);
      return completer.future;
    });

    await tester.tap(find.widgetWithText(ActionChip, '🇩🇪 German'));
    await tester.pump();
    expect(picked, ['de']);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, '🇫🇷 French'),
        warnIfMissed: false);
    await tester.pump();
    expect(picked, ['de']);

    completer.complete();
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('custom settings link calls back', (tester) async {
    var called = false;
    await _pump(tester, onCustom: () => called = true);
    await tester.tap(find.text('Custom settings…'));
    expect(called, isTrue);
  });

  test('LangPreset.toLanguage copies flags and leaves id null', () {
    final lang = kLangPresets
        .firstWhere((p) => p.code == 'zh')
        .toLanguage('Chinese');
    expect(lang, isA<Language>());
    expect(lang.id, isNull);
    expect(lang.name, 'Chinese');
    expect(lang.languageCode, 'zh');
    expect(lang.splitByCharacter, isTrue);
    expect(lang.useWordSegmentation, isTrue);
    expect(lang.rightToLeft, isFalse);
  });
}
