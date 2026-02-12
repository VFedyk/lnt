import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/home_screen.dart';
import 'service_locator.dart';
import 'services/settings_service.dart';
import 'utils/cover_image_helper.dart';
import 'utils/helpers.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite_ffi for Linux and Windows
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  setupServiceLocator();
  await db.database;
  await CoverImageHelper.initialize();
  reviewService.initialize();

  if (PlatformHelper.isDesktop) {
    await windowManager.ensureInitialized();

    final width = await settings.getWindowWidth();
    final height = await settings.getWindowHeight();
    final maximized = await settings.getWindowMaximized();

    const minSize = Size(400, 300);

    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: Size(width, height),
        minimumSize: minSize,
        center: true,
      ),
      () async {
        if (maximized) {
          await windowManager.maximize();
        }
        await windowManager.show();
      },
    );
  }

  runApp(const LNTApp());
}

class LNTApp extends StatefulWidget {
  const LNTApp({super.key});

  @override
  State<LNTApp> createState() => _LNTAppState();
}

class _LNTAppState extends State<LNTApp> with WindowListener {
  Timer? _resizeDebounce;

  @override
  void initState() {
    super.initState();
    if (PlatformHelper.isDesktop) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (PlatformHelper.isDesktop) {
      windowManager.removeListener(this);
    }
    _resizeDebounce?.cancel();
    super.dispose();
  }

  @override
  void onWindowResize() {
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (await windowManager.isMaximized()) return;
      final size = await windowManager.getSize();
      await settings.saveWindowState(
        width: size.width,
        height: size.height,
        isMaximized: false,
      );
    });
  }

  @override
  void onWindowMaximize() {
    settings.saveWindowState(
      width: SettingsService.defaultWindowWidth,
      height: SettingsService.defaultWindowHeight,
      isMaximized: true,
    );
  }

  @override
  void onWindowUnmaximize() async {
    final size = await windowManager.getSize();
    await settings.saveWindowState(
      width: size.width,
      height: size.height,
      isMaximized: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppState())],
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'Language Nerd Tools',
            locale: appState.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('uk'),
            ],
            theme: ThemeData(
              primarySwatch: Colors.purple,
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
            ),
            navigatorObservers: [routeObserver],
            home: const HomeScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  static const String _selectedLanguageKey = 'selected_language_id';
  static const String _currentTextKey = 'current_text_id';
  static const String _appLocaleKey = 'app_locale';

  int? _selectedLanguageId;
  int? _currentTextId;
  Locale _locale = const Locale('en');
  SharedPreferences? _prefs;
  bool _isLoaded = false;

  int? get selectedLanguageId => _selectedLanguageId;
  int? get currentTextId => _currentTextId;
  Locale get locale => _locale;
  bool get isLoaded => _isLoaded;

  AppState() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _selectedLanguageId = _prefs?.getInt(_selectedLanguageKey);
    _currentTextId = _prefs?.getInt(_currentTextKey);

    // Load saved locale
    final localeCode = _prefs?.getString(_appLocaleKey);
    if (localeCode != null) {
      _locale = Locale(localeCode);
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    await _prefs?.setString(_appLocaleKey, locale.languageCode);
    notifyListeners();
  }

  Future<void> setSelectedLanguage(int? id) async {
    _selectedLanguageId = id;
    if (id != null) {
      await _prefs?.setInt(_selectedLanguageKey, id);
    } else {
      await _prefs?.remove(_selectedLanguageKey);
    }
    notifyListeners();
  }

  Future<void> setCurrentText(int? id) async {
    _currentTextId = id;
    if (id != null) {
      await _prefs?.setInt(_currentTextKey, id);
    } else {
      await _prefs?.remove(_currentTextKey);
    }
    notifyListeners();
  }

}
