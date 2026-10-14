import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/domain/entities/language.dart';
import 'package:language_nerd_tools/domain/entities/text_document.dart';
import 'package:language_nerd_tools/l10n/generated/app_localizations.dart';
import 'package:language_nerd_tools/presentation/screens/text_edit_screen.dart';
import 'package:language_nerd_tools/presentation/widgets/reader/reader_context_menu.dart';
import 'package:language_nerd_tools/utils/cover_image_helper.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  final String path;
  _FakePathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

final _text = TextDocument(
  id: 't1',
  languageId: 'l1',
  title: 'Title',
  content: 'Some content',
);

Future<void> _open(
  WidgetTester tester, {
  Language? language,
  void Function(TextDocument?)? onResult,
}) async {
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
          onPressed: () async {
            final r = await Navigator.push<TextDocument>(
              context,
              MaterialPageRoute(
                builder: (_) => TextEditScreen(
                  text: _text,
                  language: language ??
                      Language(id: 'l1', name: 'English', languageCode: 'en'),
                  fontSize: 22,
                ),
              ),
            );
            onResult?.call(r);
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

EditableText _contentField(WidgetTester tester) => tester.widget<EditableText>(
      find.descendant(
        of: find.byType(TextFormField).last,
        matching: find.byType(EditableText),
      ),
    );

void main() {
  late Directory dir;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('lnt_text_edit_screen');
    PathProviderPlatform.instance = _FakePathProvider(dir.path);
    await CoverImageHelper.initialize();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('content uses the reader font size and line height',
      (tester) async {
    await _open(tester);
    final style = _contentField(tester).style;
    expect(style.fontSize, 22);
    expect(style.height, ReaderScreenConstants.lineHeight);
  });

  testWidgets('RTL language gives the content field RTL direction',
      (tester) async {
    await _open(
      tester,
      language: Language(
        id: 'l1',
        name: 'Arabic',
        languageCode: 'ar',
        rightToLeft: true,
      ),
    );
    expect(_contentField(tester).textDirection, TextDirection.rtl);
  });

  testWidgets('an empty title blocks save', (tester) async {
    var popped = false;
    await _open(tester, onResult: (_) => popped = true);
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(TextEditScreen), findsOneWidget);
    expect(popped, isFalse);
  });

  testWidgets('save pops the updated document', (tester) async {
    TextDocument? result;
    await _open(tester, onResult: (r) => result = r);
    await tester.enterText(find.byType(TextFormField).first, 'New title');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(TextEditScreen), findsNothing);
    expect(result?.title, 'New title');
    expect(result?.content, 'Some content');
  });

  testWidgets('back with no edits pops immediately', (tester) async {
    await _open(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(TextEditScreen), findsNothing);
  });

  testWidgets('back with unsaved edits asks to discard', (tester) async {
    await _open(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Edited');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(TextEditScreen), findsOneWidget);
    expect(find.text('Discard changes?'), findsWidgets);
  });
}
