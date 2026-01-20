import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.database;
  runApp(const FLTRApp());
}

class FLTRApp extends StatelessWidget {
  const FLTRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppState())],
      child: MaterialApp(
        title: 'FLTR - Foreign Language Text Reader',
        theme: ThemeData(
          primarySwatch: Colors.blue,
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
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  static const String _selectedLanguageKey = 'selected_language_id';
  static const String _currentTextKey = 'current_text_id';

  int? _selectedLanguageId;
  int? _currentTextId;
  SharedPreferences? _prefs;
  bool _isLoaded = false;

  int? get selectedLanguageId => _selectedLanguageId;
  int? get currentTextId => _currentTextId;
  bool get isLoaded => _isLoaded;

  AppState() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _selectedLanguageId = _prefs?.getInt(_selectedLanguageKey);
    _currentTextId = _prefs?.getInt(_currentTextKey);
    _isLoaded = true;
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
