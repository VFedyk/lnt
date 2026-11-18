import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalCupertinoLocalizations, GlobalMaterialLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/domain/entities/term.dart';
import 'package:language_nerd_tools/l10n/generated/app_localizations.dart';
import 'package:language_nerd_tools/presentation/controllers/reader_controller.dart';
import 'package:language_nerd_tools/presentation/widgets/reader/reader_foreign_word_dialog.dart';
import 'package:language_nerd_tools/presentation/widgets/reader/reader_translation_dialog.dart';
import 'package:language_nerd_tools/presentation/widgets/reader/reader_word_popup.dart';

void main() {
  const screen = Size(400, 800);
  const child = Size(200, 100);
  const gap = ReaderWordPopupLayoutDelegate.gap;

  Offset place(Rect? anchor, {EdgeInsets padding = EdgeInsets.zero}) =>
      ReaderWordPopupLayoutDelegate(anchorRect: anchor, padding: padding)
          .getPositionForChild(screen, child);

  group('ReaderWordPopupLayoutDelegate', () {
    test('goes below the word when it fits, centered on it', () {
      final anchor = Rect.fromLTWH(150, 200, 100, 20);
      expect(place(anchor), Offset(100, 220 + gap));
    });

    test('goes above the word near the bottom edge', () {
      final anchor = Rect.fromLTWH(150, 740, 100, 20);
      expect(place(anchor), Offset(100, 740 - gap - child.height));
    });

    test('picks the larger side when neither fits', () {
      const tall = Size(200, 500);
      final anchor = Rect.fromLTWH(150, 300, 100, 20);
      // 300 above, 480 below -> below.
      final below = ReaderWordPopupLayoutDelegate(
        anchorRect: anchor,
        padding: EdgeInsets.zero,
      ).getPositionForChild(screen, tall);
      expect(below.dy, 320 + gap);

      final anchor2 = Rect.fromLTWH(150, 480, 100, 20);
      // 480 above, 300 below -> above.
      final above = ReaderWordPopupLayoutDelegate(
        anchorRect: anchor2,
        padding: EdgeInsets.zero,
      ).getPositionForChild(screen, tall);
      expect(above.dy, 480 - gap - tall.height);
    });

    test('clamps horizontally at both edges', () {
      expect(place(Rect.fromLTWH(0, 200, 20, 20)).dx, 0);
      expect(place(Rect.fromLTWH(380, 200, 20, 20)).dx, 200);
    });

    test('respects padding', () {
      const pad = EdgeInsets.fromLTRB(10, 50, 10, 40);
      expect(place(Rect.fromLTWH(0, 200, 20, 20), padding: pad).dx, 10);
      expect(place(Rect.fromLTWH(380, 200, 20, 20), padding: pad).dx, 190);
      // Near the bottom: bottom padding pushes it above.
      final y = place(Rect.fromLTWH(150, 700, 100, 20), padding: pad).dy;
      expect(y, 700 - gap - child.height);
    });

    test('centers when there is no anchor', () {
      expect(place(null), const Offset(100, 350));
    });

    test('shouldRelayout compares both fields', () {
      final a = ReaderWordPopupLayoutDelegate(
        anchorRect: const Rect.fromLTWH(0, 0, 1, 1),
        padding: EdgeInsets.zero,
      );
      expect(
        a.shouldRelayout(
          ReaderWordPopupLayoutDelegate(
            anchorRect: const Rect.fromLTWH(0, 0, 1, 1),
            padding: EdgeInsets.zero,
          ),
        ),
        isFalse,
      );
      expect(
        a.shouldRelayout(
          ReaderWordPopupLayoutDelegate(
            anchorRect: const Rect.fromLTWH(0, 0, 2, 1),
            padding: EdgeInsets.zero,
          ),
        ),
        isTrue,
      );
      expect(
        a.shouldRelayout(
          ReaderWordPopupLayoutDelegate(
            anchorRect: const Rect.fromLTWH(0, 0, 1, 1),
            padding: const EdgeInsets.all(1),
          ),
        ),
        isTrue,
      );
    });
  });

  group('popup widgets', () {
    Future<void> pump(WidgetTester tester, Widget popup, {double width = 400}) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showReaderWordPopup<void>(
                context: context,
                anchorRect: const Rect.fromLTWH(100, 100, 40, 20),
                builder: (_) => popup,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Widget translation(AppLocalizations l10n, int count) =>
        ReaderTranslationDialog(
          term: Term(languageId: 'l', text: 'hello', lowerText: 'hello'),
          translations: [Translation(termId: 't', meaning: 'привіт')],
          translationsById: const {},
          termsById: const {},
          languageCode: 'en',
          l10n: l10n,
          onEdit: () {},
          onPronounce: () {},
          sentenceCount: count,
        );

    Widget foreign(AppLocalizations l10n, int count) => ReaderForeignWordDialog(
      lowerWord: 'hallo',
      info: ForeignTermInfo(
        languageName: 'German',
        languageId: 'de',
        translations: const [],
        sentenceCount: count,
      ),
      l10n: l10n,
      onRemove: () {},
      removeIconSize: 18,
    );

    for (final width in [400.0, 320.0]) {
      testWidgets('translation popup shows examples only when > 0 ($width)', (
        tester,
      ) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await pump(tester, translation(l10n, 3), width: width);
        expect(find.textContaining(l10n.tooltipExampleCount(3)), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('translation popup hides examples at 0 ($width)', (
        tester,
      ) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await pump(tester, translation(l10n, 0), width: width);
        expect(find.textContaining('example'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('foreign popup shows examples only when > 0 ($width)', (
        tester,
      ) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await pump(tester, foreign(l10n, 2), width: width);
        expect(find.textContaining(l10n.tooltipExampleCount(2)), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('tapping outside closes the popup', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pump(tester, translation(l10n, 0));
      expect(find.byType(ReaderTranslationDialog), findsOneWidget);
      await tester.tapAt(const Offset(390, 790));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderTranslationDialog), findsNothing);
    });
  });
}
