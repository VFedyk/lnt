// FILE: lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart';
import '../models/language.dart';
import '../service_locator.dart';
import '../utils/constants.dart';
import 'dashboard_tab.dart';
import 'languages_screen.dart';
import 'library_screen.dart';
import 'terms_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';

/// Navigation tabs for the home screen
enum HomeTab {
  dashboard,
  texts,
  terms,
  review,
  languages,
}

/// Layout and sizing constants for the home screen
abstract class _HomeScreenConstants {
  // Icon sizes
  static const double emptyStateIconSize = 80.0;
  static const double checkIconSize = 20.0;

  // Data limits
  static const Duration appStatePollingInterval = Duration(milliseconds: 50);

  // Empty state colors
  static const Color emptyStateIconColor = Color(0xFFBDBDBD); // Colors.grey[400]
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  HomeTab _selectedTab = HomeTab.dashboard;
  List<Language> _languages = [];
  Language? _selectedLanguage;
  bool _isLoading = true;
  int _dueCount = 0;

  @override
  void initState() {
    super.initState();
    // Delay to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLanguages();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _refreshDueCount();
  }

  Future<void> _loadLanguages() async {
    setState(() => _isLoading = true);
    try {
      // Wait for AppState preferences to load
      final appState = context.read<AppState>();
      while (!appState.isLoaded) {
        await Future.delayed(_HomeScreenConstants.appStatePollingInterval);
      }

      final languages = await db.getLanguages();

      setState(() {
        _languages = languages;
      });

      // Try to restore previously selected language
      if (appState.selectedLanguageId != null && _languages.isNotEmpty) {
        // Check if the stored language still exists
        final storedLangIndex = _languages.indexWhere(
          (lang) => lang.id == appState.selectedLanguageId,
        );

        if (storedLangIndex != -1) {
          setState(() => _selectedLanguage = _languages[storedLangIndex]);
        } else {
          // Stored language was deleted, select first available
          setState(() => _selectedLanguage = _languages.first);
          await appState.setSelectedLanguage(_languages.first.id);
        }
      } else if (_languages.isNotEmpty && _selectedLanguage == null) {
        // No stored language, select first one
        setState(() => _selectedLanguage = _languages.first);
        await appState.setSelectedLanguage(_languages.first.id);
      }

      final dueCount = _selectedLanguage != null
          ? await db.reviewCards.getDueCount(_selectedLanguage!.id!)
          : 0;

      setState(() {
        _dueCount = dueCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).errorLoadingLanguages(e.toString()))));
      }
    }
  }

  Future<void> _refreshDueCount() async {
    if (_selectedLanguage == null) return;
    final dueCount = await db.reviewCards
        .getDueCount(_selectedLanguage!.id!);
    if (mounted && dueCount != _dueCount) {
      setState(() => _dueCount = dueCount);
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_languages.isEmpty) {
      return _buildEmptyState();
    }

    final langKey = ValueKey(_selectedLanguage!.id);
    switch (_selectedTab) {
      case HomeTab.dashboard:
        return DashboardTab(
          key: langKey,
          language: _selectedLanguage!,
          onRefresh: _loadLanguages,
        );
      case HomeTab.texts:
        return LibraryScreen(key: langKey, language: _selectedLanguage!);
      case HomeTab.terms:
        return TermsScreen(key: langKey, language: _selectedLanguage!);
      case HomeTab.review:
        return ReviewScreen(key: langKey, language: _selectedLanguage!);
      case HomeTab.languages:
        return LanguagesScreen(onLanguagesChanged: _loadLanguages);
    }
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.language, size: _HomeScreenConstants.emptyStateIconSize, color: _HomeScreenConstants.emptyStateIconColor),
          const SizedBox(height: AppConstants.spacingL),
          Text(
            l10n.noLanguagesYet,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: AppConstants.subtitleColor),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            l10n.addLanguageToStart,
            style: TextStyle(color: AppConstants.subtitleColor),
          ),
          const SizedBox(height: AppConstants.spacingXL),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LanguagesScreen()),
              );
              _loadLanguages();
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.addLanguage),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_languages.isNotEmpty)
            PopupMenuButton<Language>(
              icon: const Icon(Icons.language),
              tooltip: l10n.languages,
              onSelected: (language) {
                setState(() => _selectedLanguage = language);
                context.read<AppState>().setSelectedLanguage(language.id);
              },
              itemBuilder: (context) => _languages
                  .map(
                    (lang) => PopupMenuItem(
                      value: lang,
                      child: Row(
                        children: [
                          if (lang.id == _selectedLanguage?.id)
                            const Icon(Icons.check, size: _HomeScreenConstants.checkIconSize),
                          if (lang.id == _selectedLanguage?.id)
                            const SizedBox(width: AppConstants.spacingS),
                          Text(lang.name),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settings,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _languages.isEmpty
          ? null
          : NavigationBar(
              selectedIndex: _selectedTab.index,
              onDestinationSelected: (index) {
                setState(() => _selectedTab = HomeTab.values[index]);
                _refreshDueCount();
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: l10n.home,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.article_outlined),
                  selectedIcon: const Icon(Icons.article),
                  label: l10n.libraryTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.book_outlined),
                  selectedIcon: const Icon(Icons.book),
                  label: l10n.vocabulary,
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: _dueCount > 0,
                    label: Text(_dueCount.toString()),
                    child: const Icon(Icons.school_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: _dueCount > 0,
                    label: Text(_dueCount.toString()),
                    child: const Icon(Icons.school),
                  ),
                  label: l10n.review,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: l10n.languages,
                ),
              ],
            ),
    );
  }
}
