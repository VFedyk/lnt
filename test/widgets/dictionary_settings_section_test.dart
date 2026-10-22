import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/l10n/generated/app_localizations.dart';
import 'package:language_nerd_tools/presentation/widgets/settings/dictionary_settings_section.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool darken,
    required bool cover,
    required ValueChanged<bool> onDarken,
    required ValueChanged<bool> onCover,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: DictionarySettingsSection(
              l10n: AppLocalizations.of(context),
              darkenPages: darken,
              onDarkenPagesChanged: onDarken,
              coverOnNavigation: cover,
              onCoverOnNavigationChanged: onCover,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders both switches in their current state', (tester) async {
    await pump(
      tester,
      darken: true,
      cover: false,
      onDarken: (_) {},
      onCover: (_) {},
    );

    final switches = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .toList();
    expect(switches, hasLength(2));
    expect(find.text('Darken pages in dark mode'), findsOneWidget);
    expect(find.text('Hide pages while they load'), findsOneWidget);
    final darken = switches.firstWhere(
      (s) => (s.title as Text).data == 'Darken pages in dark mode',
    );
    final cover = switches.firstWhere(
      (s) => (s.title as Text).data == 'Hide pages while they load',
    );
    expect(darken.value, isTrue);
    expect(cover.value, isFalse);
  });

  testWidgets('tapping a switch calls its callback', (tester) async {
    bool? darken;
    bool? cover;
    await pump(
      tester,
      darken: false,
      cover: false,
      onDarken: (v) => darken = v,
      onCover: (v) => cover = v,
    );

    await tester.tap(find.text('Darken pages in dark mode'));
    expect(darken, isTrue);
    expect(cover, isNull);

    await tester.tap(find.text('Hide pages while they load'));
    expect(cover, isTrue);
  });
}
