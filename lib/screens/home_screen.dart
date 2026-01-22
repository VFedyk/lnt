// FILE: lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
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
        await Future.delayed(const Duration(milliseconds: 50));
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
        ).showSnackBar(SnackBar(content: Text('Error loading languages: $e')));
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

    switch (_selectedIndex) {
      case 0:
        return _DashboardTab(
          language: _selectedLanguage!,
          onRefresh: _loadLanguages,
        );
      case 1:
        return TextsScreen(language: _selectedLanguage!);
      case 2:
        return TermsScreen(language: _selectedLanguage!);
      case 3:
        return StatisticsScreen(language: _selectedLanguage!);
      case 4:
        return LanguagesScreen(onLanguagesChanged: _loadLanguages);
      default:
        return const Center(child: Text('Unknown screen'));
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.language, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Languages Yet',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a language to get started',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LanguagesScreen()),
              );
              _loadLanguages();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Language'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FLTR'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_languages.isNotEmpty)
            PopupMenuButton<Language>(
              icon: const Icon(Icons.language),
              tooltip: 'Select Language',
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
                            const Icon(Icons.check, size: 20),
                          if (lang.id == _selectedLanguage?.id)
                            const SizedBox(width: 8),
                          Text(lang.name),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _languages.isEmpty
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.article_outlined),
                  selectedIcon: Icon(Icons.article),
                  label: 'Texts',
                ),
                NavigationDestination(
                  icon: Icon(Icons.book_outlined),
                  selectedIcon: Icon(Icons.book),
                  label: 'Terms',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Stats',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Languages',
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
        limit: 5,
      );
      final recentlyAdded = await DatabaseService.instance
          .getRecentlyAddedTexts(widget.language.id!, limit: 5);
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

      setState(() {
        _recentlyReadTexts = recentlyRead;
        _recentlyAddedTexts = recentlyAdded;
        _termCounts = counts;
        _unknownCounts = unknownCounts;
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
      if (term == null || term.status == 1) {
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
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.language,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.language.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatsRow(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActions(),
          const SizedBox(height: 16),
          _buildRecentlyReadTexts(),
          const SizedBox(height: 16),
          _buildRecentlyAddedTexts(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalTerms = _termCounts.values.fold(0, (sum, count) => sum + count);
    final knownTerms = (_termCounts[5] ?? 0) + (_termCounts[99] ?? 0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem('Total Terms', totalTerms.toString(), Icons.book),
        _buildStatItem('Known', knownTerms.toString(), Icons.check_circle),
        _buildStatItem(
          'Texts',
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
        const SizedBox(height: 4),
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

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: const Text('Add Text'),
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
                  label: const Text('Import Terms'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recently read',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_recentlyReadTexts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No texts read yet.'),
              )
            else
              ..._recentlyReadTexts.map(
                (text) => ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(text.title),
                  subtitle: Text(
                    '${text.getCountLabel(widget.language.splitByCharacter)} • ${_unknownCounts[text.id] ?? 0} unknown',
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
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyAddedTexts() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recently added',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_recentlyAddedTexts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No texts yet. Add one to get started!'),
              )
            else
              ..._recentlyAddedTexts.map(
                (text) => ListTile(
                  leading: const Icon(Icons.article),
                  title: Text(text.title),
                  subtitle: Text(
                    '${text.getCountLabel(widget.language.splitByCharacter)} • ${_unknownCounts[text.id] ?? 0} unknown',
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}
