import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/domain/entities/dictionary.dart';
import 'package:language_nerd_tools/l10n/generated/app_localizations.dart';
import 'package:language_nerd_tools/presentation/theme/app_theme.dart';
import 'package:language_nerd_tools/utils/dictionary_navigation.dart';

const _channel = MethodChannel('lnt/system_dictionary');

class _CountingObserver extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route route, Route? previousRoute) => pushes++;
}

Future<BuildContext> _pump(WidgetTester tester, NavigatorObserver obs) async {
  late BuildContext ctx;
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    navigatorObservers: [obs],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })),
  ));
  return ctx;
}

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  testWidgets('system entry sends lookUp with the trimmed word, no route',
      (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return null;
    });
    final obs = _CountingObserver();
    final ctx = await _pump(tester, obs);
    final before = obs.pushes;

    await openDictionaryLookup(ctx, '  hello ', Dictionary.system('l1'));

    expect(calls.single.method, 'lookUp');
    expect(calls.single.arguments, 'hello');
    expect(obs.pushes, before);
  });

  testWidgets('a PlatformException shows the error SnackBar', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      throw PlatformException(code: 'NO_PRESENTER');
    });
    final ctx = await _pump(tester, _CountingObserver());

    await openDictionaryLookup(ctx, 'hello', Dictionary.system('l1'));
    await tester.pump();

    expect(find.text('Could not open the System Dictionary'), findsOneWidget);
  });

  testWidgets('dictionaryDisplayName localizes only the system entry',
      (tester) async {
    final ctx = await _pump(tester, _CountingObserver());
    final l10n = AppLocalizations.of(ctx);
    expect(dictionaryDisplayName(l10n, Dictionary.system('l1')),
        'System Dictionary');
    expect(
        dictionaryDisplayName(
            l10n, Dictionary(languageId: 'l1', name: 'Foo', url: 'u/###')),
        'Foo');
  });
}
