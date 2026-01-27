import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.database;
  runApp(const LNTApp());
}

class LNTApp extends StatelessWidget {
  const LNTApp({super.key});

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
