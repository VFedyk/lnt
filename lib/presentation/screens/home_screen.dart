// FILE: lib/screens/home_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../main.dart';
import '../../domain/entities/language.dart';
import '../../service_locator.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../widgets/shared/app_empty_state.dart';
import '../widgets/shared/share_import_dialog.dart';
import 'dashboard_tab.dart';
import 'languages_screen.dart';
import 'library_screen.dart';
import 'vocabulary_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';

/// Navigation tabs for the home screen
enum HomeTab {
  dashboard,
  texts,
  terms,
  review,
}

enum _MenuItem { dashboard, texts, terms, review, settings }

class _DesktopSidebar extends StatelessWidget {
  final HomeTab selectedTab;
  final int dueCount;
  final ValueChanged<HomeTab> onTabSelected;
  final VoidCallback onSettings;

  const _DesktopSidebar({
    required this.selectedTab,
    required this.dueCount,
    required this.onTabSelected,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme.primary;
    final selectedColor = Theme.of(context).colorScheme.primaryContainer;

    Widget navTile(HomeTab tab, String label, IconData icon, {Widget? trailing}) {
      final selected = selectedTab == tab;
      return ListTile(
        leading: Icon(icon, color: selected ? color : null),
        title: Text(
          label,
          style: selected ? TextStyle(color: color, fontWeight: FontWeight.bold) : null,
        ),
        trailing: trailing,
        selected: selected,
        selectedTileColor: selectedColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        onTap: () => onTabSelected(tab),
      );
    }

    return SizedBox(
      width: 220,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingS,
          vertical: AppConstants.spacingM,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            navTile(HomeTab.dashboard, l10n.home, Icons.home),
            navTile(HomeTab.texts, l10n.libraryTab, Icons.article),
            navTile(HomeTab.terms, l10n.vocabulary, Icons.book),
            navTile(
              HomeTab.review,
              l10n.review,
              Icons.school,
              trailing: dueCount > 0
                  ? Badge(label: Text(dueCount.toString()))
                  : null,
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(l10n.settings),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              onTap: onSettings,
            ),
          ],
        ),
      ),
    );
  }
}

/// Layout and sizing constants for the home screen
abstract class _HomeScreenConstants {
  // Icon sizes
  static const double emptyStateIconSize = 80.0;
  static const double checkIconSize = 20.0;
  static const double flagEmojiFontSize = 20.0;

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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  HomeTab _selectedTab = HomeTab.dashboard;
  late final AnimationController _sidebarController;
  late final Animation<double> _sidebarAnimation;
  List<Language> _languages = [];
  Language? _selectedLanguage;
  bool _isLoading = true;
  bool _loadInProgress = false;
  bool _pendingReload = false;
  int _dueCount = 0;
  StreamSubscription<List<SharedMediaFile>>? _sharingSubscription;

  static const _navigationChannel = MethodChannel('lnt/navigation');

  @override
  void initState() {
    super.initState();
    _sidebarController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
      value: 1.0,
    );
    _sidebarAnimation = CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeInOut,
    );
    dataChanges.languages.addListener(_loadLanguages);
    dataChanges.reviewCards.addListener(_refreshDueCount);
    if (Platform.isMacOS) {
      _navigationChannel.setMethodCallHandler(_handleNativeNavigation);
    }
    if (Platform.isIOS || Platform.isAndroid) {
      _initSharingIntent();
    }
    // Delay to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLanguages();
    });
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    dataChanges.languages.removeListener(_loadLanguages);
    dataChanges.reviewCards.removeListener(_refreshDueCount);
    if (Platform.isMacOS) {
      _navigationChannel.setMethodCallHandler(null);
    }
    _sharingSubscription?.cancel();
    super.dispose();
  }

  Future<dynamic> _handleNativeNavigation(MethodCall call) async {
    if (call.method == 'openSettings' && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsScreen()),
      );
    }
  }

  void _initSharingIntent() {
    _sharingSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_onSharedMedia);
    ReceiveSharingIntent.instance.getInitialMedia().then(_onSharedMedia);
  }

  void _onSharedMedia(List<SharedMediaFile> media) {
    final url = media
        .where((m) => m.type == SharedMediaType.url)
        .map((m) => m.path)
        .firstOrNull;
    if (url == null || url.isEmpty || !mounted) return;
    ReceiveSharingIntent.instance.reset();
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShareImportDialog(url: url),
    );
  }

  Future<void> _loadLanguages() async {
    if (_loadInProgress) {
      _pendingReload = true;
      return;
    }
    _loadInProgress = true;
    _pendingReload = false;

    setState(() => _isLoading = true);
    try {
      // Wait for AppState preferences to load
      final appState = context.read<AppState>();
      while (!appState.isLoaded) {
        await Future.delayed(_HomeScreenConstants.appStatePollingInterval);
      }

      final languages = await db.languages.getAll();

      if (!mounted) return;
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

      if (!mounted) return;
      setState(() {
        _dueCount = dueCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).errorLoadingLanguages(e.toString()))));
    } finally {
      _loadInProgress = false;
      if (_pendingReload && mounted) {
        _loadLanguages();
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
        );
      case HomeTab.texts:
        return LibraryScreen(key: langKey, language: _selectedLanguage!);
      case HomeTab.terms:
        return VocabularyScreen(key: langKey, language: _selectedLanguage!);
      case HomeTab.review:
        return ReviewScreen(key: langKey, language: _selectedLanguage!);
    }
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return AppEmptyState(
      icon: Icons.language,
      iconSize: _HomeScreenConstants.emptyStateIconSize,
      iconColor: _HomeScreenConstants.emptyStateIconColor,
      title: l10n.noLanguagesYet,
      titleStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppConstants.subtitleColor,
      ),
      subtitle: l10n.addLanguageToStart,
      action: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LanguagesScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.addLanguage),
      ),
    );
  }

  void _navigateTo(HomeTab tab) {
    setState(() => _selectedTab = tab);
    _refreshDueCount();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDesktop = PlatformHelper.isDesktop;
    return Scaffold(
      appBar: AppBar(
        leading: isDesktop
            ? IconButton(
                icon: const Icon(Icons.view_sidebar),
                onPressed: () {
                  if (_sidebarController.isCompleted) {
                    _sidebarController.reverse();
                  } else {
                    _sidebarController.forward();
                  }
                },
              )
            : PopupMenuButton<_MenuItem>(
          icon: const Icon(Icons.menu),
          onSelected: (item) {
            if (item == _MenuItem.settings) {
              _openSettings();
            } else {
              _navigateTo(HomeTab.values[item.index]);
            }
          },
          itemBuilder: (context) {
            final color = Theme.of(context).colorScheme.primary;
            PopupMenuItem<_MenuItem> navItem(
              _MenuItem item,
              String label,
              IconData icon,
            ) {
              final selected = _selectedTab == HomeTab.values[item.index];
              return PopupMenuItem(
                value: item,
                child: Row(
                  children: [
                    Icon(icon, color: selected ? color : null),
                    const SizedBox(width: AppConstants.spacingM),
                    Expanded(
                      child: Text(
                        label,
                        style: selected
                            ? TextStyle(color: color, fontWeight: FontWeight.bold)
                            : null,
                      ),
                    ),
                  ],
                ),
              );
            }

            return [
              navItem(_MenuItem.dashboard, l10n.home, Icons.home),
              navItem(_MenuItem.texts, l10n.libraryTab, Icons.article),
              navItem(_MenuItem.terms, l10n.vocabulary, Icons.book),
              PopupMenuItem(
                value: _MenuItem.review,
                child: Row(
                  children: [
                    Badge(
                      isLabelVisible: _dueCount > 0,
                      label: Text(_dueCount.toString()),
                      child: Icon(
                        Icons.school,
                        color: _selectedTab == HomeTab.review ? color : null,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingM),
                    Expanded(
                      child: Text(
                        l10n.review,
                        style: _selectedTab == HomeTab.review
                            ? TextStyle(color: color, fontWeight: FontWeight.bold)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _MenuItem.settings,
                child: Row(
                  children: [
                    const Icon(Icons.settings),
                    const SizedBox(width: AppConstants.spacingM),
                    Text(l10n.settings),
                  ],
                ),
              ),
            ];
          },
        ),
        title: Text(l10n.appTitle),
        actions: [
          if (_languages.isNotEmpty && _selectedLanguage != null)
            PopupMenuButton<Language?>(
              tooltip: l10n.languages,
              onSelected: (language) {
                if (language == null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LanguagesScreen()),
                  );
                  return;
                }
                setState(() => _selectedLanguage = language);
                context.read<AppState>().setSelectedLanguage(language.id);
                _refreshDueCount();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingS,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedLanguage!.flagEmoji.isNotEmpty)
                      Text(
                        _selectedLanguage!.flagEmoji,
                        style: const TextStyle(fontSize: _HomeScreenConstants.flagEmojiFontSize),
                      ),
                    if (_selectedLanguage!.flagEmoji.isNotEmpty)
                      const SizedBox(width: AppConstants.spacingXS),
                    Text(
                      _selectedLanguage!.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                ..._languages.map(
                  (lang) => PopupMenuItem<Language?>(
                    value: lang,
                    child: Row(
                      children: [
                        if (lang.flagEmoji.isNotEmpty) ...[
                          Text(lang.flagEmoji),
                          const SizedBox(width: AppConstants.spacingS),
                        ],
                        Expanded(child: Text(lang.name)),
                        if (lang.id == _selectedLanguage?.id)
                          const Icon(Icons.check, size: _HomeScreenConstants.checkIconSize),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<Language?>(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LanguagesScreen()),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tune, size: _HomeScreenConstants.checkIconSize),
                      const SizedBox(width: AppConstants.spacingS),
                      Text(l10n.manageLanguages),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: isDesktop
          ? Row(
              children: [
                FocusScope(
                  canRequestFocus: false,
                  child: AnimatedBuilder(
                  animation: _sidebarController,
                  builder: (context, _) {
                    if (_sidebarController.isDismissed) {
                      return const SizedBox.shrink();
                    }
                    return SizeTransition(
                      axis: Axis.horizontal,
                      sizeFactor: _sidebarAnimation,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _DesktopSidebar(
                            selectedTab: _selectedTab,
                            dueCount: _dueCount,
                            onTabSelected: _navigateTo,
                            onSettings: _openSettings,
                          ),
                          const VerticalDivider(width: 1, thickness: 1),
                        ],
                      ),
                    );
                  },
                ),
                ),
                Expanded(child: _buildBody()),
              ],
            )
          : _buildBody(),
    );
  }
}
