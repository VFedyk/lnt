// FILE: lib/screens/home_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart';
import '../models/language.dart';
import '../models/text_document.dart';
import '../models/term.dart';
import '../services/database_service.dart';
import '../services/text_parser_service.dart';
import 'languages_screen.dart';
import 'texts_screen.dart';
import 'reader_screen.dart';
import 'terms_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';

/// Navigation tabs for the home screen
enum HomeTab {
  dashboard,
  texts,
  terms,
  statistics,
  languages,
}

/// Layout and sizing constants for the home screen
abstract class _HomeScreenConstants {
  // Icon sizes
  static const double emptyStateIconSize = 80.0;
  static const double checkIconSize = 20.0;

  // Thumbnail dimensions
  static const double thumbnailWidth = 40.0;
  static const double thumbnailHeight = 56.0;
  static const double thumbnailBorderRadius = 4.0;

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 24.0;

  // Data limits
  static const int recentTextsLimit = 5;
  static const Duration appStatePollingInterval = Duration(milliseconds: 50);

  // Empty state colors
  static const Color emptyStateIconColor = Color(0xFFBDBDBD); // Colors.grey[400]
  static const Color emptyStateTextColor = Color(0xFF757575); // Colors.grey[600]
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeTab _selectedTab = HomeTab.dashboard;
  List<Language> _languages = [];
  Language? _selectedLanguage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Delay to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLanguages();
    });
  }

  Future<void> _loadLanguages() async {
    setState(() => _isLoading = true);
    try {
      // Wait for AppState preferences to load
      final appState = context.read<AppState>();
      while (!appState.isLoaded) {
        await Future.delayed(_HomeScreenConstants.appStatePollingInterval);
      }

      final languages = await DatabaseService.instance.getLanguages();

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

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).errorLoadingLanguages(e.toString()))));
      }
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_languages.isEmpty) {
      return _buildEmptyState();
    }

    switch (_selectedTab) {
      case HomeTab.dashboard:
        return _DashboardTab(
          language: _selectedLanguage!,
          onRefresh: _loadLanguages,
        );
      case HomeTab.texts:
        return TextsScreen(language: _selectedLanguage!);
      case HomeTab.terms:
        return TermsScreen(language: _selectedLanguage!);
      case HomeTab.statistics:
        return StatisticsScreen(language: _selectedLanguage!);
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
          const SizedBox(height: _HomeScreenConstants.spacingL),
          Text(
            l10n.noLanguagesYet,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: _HomeScreenConstants.emptyStateTextColor),
          ),
          const SizedBox(height: _HomeScreenConstants.spacingS),
          Text(
            l10n.addLanguageToStart,
            style: const TextStyle(color: _HomeScreenConstants.emptyStateTextColor),
          ),
          const SizedBox(height: _HomeScreenConstants.spacingXL),
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
                            const SizedBox(width: _HomeScreenConstants.spacingS),
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
                  label: l10n.texts,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.book_outlined),
                  selectedIcon: const Icon(Icons.book),
                  label: l10n.vocabulary,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.bar_chart_outlined),
                  selectedIcon: const Icon(Icons.bar_chart),
                  label: l10n.stats,
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

class _DashboardTab extends StatefulWidget {
  final Language language;
  final VoidCallback onRefresh;

  const _DashboardTab({required this.language, required this.onRefresh});

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  List<TextDocument> _recentlyReadTexts = [];
  List<TextDocument> _recentlyAddedTexts = [];
  Map<int, int> _termCounts = {};
  Map<int, int> _unknownCounts = {};
  Map<int, String> _collectionNames = {};
  bool _isLoading = true;
  final _textParser = TextParserService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(_DashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language.id != widget.language.id) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final recentlyRead = await DatabaseService.instance.getRecentlyReadTexts(
        widget.language.id!,
        limit: _HomeScreenConstants.recentTextsLimit,
      );
      final recentlyAdded = await DatabaseService.instance
          .getRecentlyAddedTexts(widget.language.id!, limit: _HomeScreenConstants.recentTextsLimit);
      final counts = await DatabaseService.instance.getTermCountsByStatus(
        widget.language.id!,
      );

      // Load terms map and calculate unknown counts
      final termsMap = await DatabaseService.instance.getTermsMap(
        widget.language.id!,
      );

      final unknownCounts = <int, int>{};
      final allTexts = {...recentlyRead, ...recentlyAdded};
      for (final text in allTexts) {
        unknownCounts[text.id!] = _calculateUnknownCount(text, termsMap);
      }

      // Load collection names for texts in collections
      final collectionNames = <int, String>{};
      final collectionIds = allTexts
          .where((t) => t.collectionId != null)
          .map((t) => t.collectionId!)
          .toSet();
      for (final collectionId in collectionIds) {
        final collection = await DatabaseService.instance.getCollection(
          collectionId,
        );
        if (collection != null) {
          collectionNames[collectionId] = collection.name;
        }
      }

      setState(() {
        _recentlyReadTexts = recentlyRead;
        _recentlyAddedTexts = recentlyAdded;
        _termCounts = counts;
        _unknownCounts = unknownCounts;
        _collectionNames = collectionNames;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int _calculateUnknownCount(TextDocument text, Map<String, Term> termsMap) {
    final words = _textParser.splitIntoWords(text.content, widget.language);
    int unknownCount = 0;

    final seenWords = <String>{};
    for (final word in words) {
      final normalized = word.toLowerCase();
      if (seenWords.contains(normalized)) continue;
      seenWords.add(normalized);

      final term = termsMap[normalized];
      if (term == null || term.status == TermStatus.unknown) {
        unknownCount++;
      }
    }

    return unknownCount;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(_HomeScreenConstants.spacingL),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(_HomeScreenConstants.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.language,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: _HomeScreenConstants.spacingS),
                      Text(
                        widget.language.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: _HomeScreenConstants.spacingL),
                  _buildStatsRow(),
                ],
              ),
            ),
          ),
          const SizedBox(height: _HomeScreenConstants.spacingL),
          _buildQuickActions(),
          const SizedBox(height: _HomeScreenConstants.spacingL),
          _buildRecentlyReadTexts(),
          const SizedBox(height: _HomeScreenConstants.spacingL),
          _buildRecentlyAddedTexts(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final l10n = AppLocalizations.of(context);
    final totalTerms = _termCounts.values.fold(0, (sum, count) => sum + count);
    final knownTerms = (_termCounts[TermStatus.known] ?? 0) + (_termCounts[TermStatus.wellKnown] ?? 0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(l10n.totalTerms, totalTerms.toString(), Icons.book),
        _buildStatItem(l10n.known, knownTerms.toString(), Icons.check_circle),
        _buildStatItem(
          l10n.texts,
          _recentlyAddedTexts.length.toString(),
          Icons.article,
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(height: _HomeScreenConstants.spacingXS),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildTextThumbnail(TextDocument text, IconData fallbackIcon) {
    if (text.coverImage != null && File(text.coverImage!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_HomeScreenConstants.thumbnailBorderRadius),
        child: Image.file(
          File(text.coverImage!),
          width: _HomeScreenConstants.thumbnailWidth,
          height: _HomeScreenConstants.thumbnailHeight,
          fit: BoxFit.cover,
        ),
      );
    }
    return Icon(fallbackIcon);
  }

  Widget _buildQuickActions() {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(_HomeScreenConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.quickActions,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: _HomeScreenConstants.spacingM),
            Wrap(
              spacing: _HomeScreenConstants.spacingS,
              runSpacing: _HomeScreenConstants.spacingS,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: Text(l10n.addText),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TextsScreen(language: widget.language),
                      ),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.import_export),
                  label: Text(l10n.importVocabulary),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TermsScreen(language: widget.language),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyReadTexts() {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(_HomeScreenConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.recentlyRead,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: _HomeScreenConstants.spacingM),
            if (_recentlyReadTexts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(_HomeScreenConstants.spacingL),
                child: Text(l10n.noTextsReadYet),
              )
            else
              ..._recentlyReadTexts.map((text) {
                final collectionName = text.collectionId != null
                    ? _collectionNames[text.collectionId]
                    : null;
                return ListTile(
                  leading: _buildTextThumbnail(text, Icons.history),
                  title: Text(text.title),
                  subtitle: Text(
                    '${collectionName != null ? '$collectionName • ' : ''}${widget.language.splitByCharacter ? l10n.charactersCount(text.characterCount) : l10n.wordsCount(text.wordCount)} • ${l10n.unknownCount(_unknownCounts[text.id] ?? 0)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReaderScreen(text: text, language: widget.language),
                      ),
                    );
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyAddedTexts() {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(_HomeScreenConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.recentlyAdded,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: _HomeScreenConstants.spacingM),
            if (_recentlyAddedTexts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(_HomeScreenConstants.spacingL),
                child: Text(l10n.noTextsYetAddOne),
              )
            else
              ..._recentlyAddedTexts.map((text) {
                final collectionName = text.collectionId != null
                    ? _collectionNames[text.collectionId]
                    : null;
                return ListTile(
                  leading: _buildTextThumbnail(text, Icons.article),
                  title: Text(text.title),
                  subtitle: Text(
                    '${collectionName != null ? '$collectionName • ' : ''}${widget.language.splitByCharacter ? l10n.charactersCount(text.characterCount) : l10n.wordsCount(text.wordCount)} • ${l10n.unknownCount(_unknownCounts[text.id] ?? 0)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReaderScreen(text: text, language: widget.language),
                      ),
                    );
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}
