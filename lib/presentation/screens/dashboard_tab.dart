import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/text_document.dart';
import '../../domain/value_objects/term_status.dart';
import '../../utils/constants.dart';
import '../../utils/cover_image_helper.dart';
import '../../utils/helpers.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/dashboard/activity_heatmap.dart';
import '../widgets/shared/animated_counter.dart';
import '../widgets/shared/app_empty_state.dart';
import '../widgets/dashboard/dashboard_charts.dart';
import '../widgets/shared/review_progress_ring.dart';
import 'reader_screen.dart';

abstract class _DashboardConstants {
  static const double thumbnailWidth = 40.0;
  static const double thumbnailHeight = 56.0;
  static const double thumbnailBorderRadius = 4.0;
  static const double desktopHeatmapWidth = 795.0;
  static const double tabletBreakpoint = 600.0;
  static const int maxHeatmapWeeks = 52;
  static const int compactHeatmapWeeks = 26;
}

class DashboardTab extends StatelessWidget {
  final Language language;

  const DashboardTab({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardController(language: language),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    final l10n = AppLocalizations.of(context);

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null) {
      return AppErrorState(
        title: l10n.failedToLoadData,
        message: controller.error,
        onRetry: controller.loadData,
        retryLabel: l10n.retry,
      );
    }

    final media = MediaQuery.of(context);
    final isWideTabletLandscape =
        !PlatformHelper.isDesktop &&
        media.orientation == Orientation.landscape &&
        media.size.shortestSide >= _DashboardConstants.tabletBreakpoint;
    final useDesktopStyleLayout = PlatformHelper.isDesktop || isWideTabletLandscape;

    return RefreshIndicator(
      onRefresh: controller.loadData,
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        children: [
          if (useDesktopStyleLayout)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppConstants.spacingL),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LanguageHeader(language: controller.language),
                            const SizedBox(height: AppConstants.spacingL),
                            _StatsRow(controller: controller),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingL),
                  SizedBox(
                    width: _DashboardConstants.desktopHeatmapWidth,
                    child: ActivityHeatmap(
                      activityData: controller.activityData,
                      weeksToShow: _DashboardConstants.maxHeatmapWeeks,
                      useTooltip: true,
                      streakDays: controller.streakDays,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.language, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(
                          controller.language.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spacingL),
                    _StatsRow(controller: controller),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            ActivityHeatmap(
              activityData: controller.activityData,
              weeksToShow: _DashboardConstants.compactHeatmapWeeks,
              streakDays: controller.streakDays,
            ),
          ],
          const SizedBox(height: AppConstants.spacingL),
          _ChartsSection(controller: controller, useDesktopLayout: useDesktopStyleLayout),
          const SizedBox(height: AppConstants.spacingL),
          if (useDesktopStyleLayout)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _RecentTextsCard(controller: controller, recentlyRead: true)),
                const SizedBox(width: AppConstants.spacingL),
                Expanded(child: _RecentTextsCard(controller: controller, recentlyRead: false)),
              ],
            )
          else ...[
            _RecentTextsCard(controller: controller, recentlyRead: true),
            const SizedBox(height: AppConstants.spacingL),
            _RecentTextsCard(controller: controller, recentlyRead: false),
          ],
        ],
      ),
    );
  }
}

class _LanguageHeader extends StatelessWidget {
  final Language language;
  const _LanguageHeader({required this.language});

  @override
  Widget build(BuildContext context) {
    if (language.flagEmoji.isNotEmpty) {
      return Row(
        children: [
          Text(language.flagEmoji, style: const TextStyle(fontSize: AppConstants.fontSizeTitle)),
          const SizedBox(width: AppConstants.spacingS),
          Text(language.name, style: Theme.of(context).textTheme.headlineSmall),
        ],
      );
    }
    return Row(
      children: [
        Icon(Icons.language, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppConstants.spacingS),
        Text(language.name, style: Theme.of(context).textTheme.headlineSmall),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final DashboardController controller;
  const _StatsRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totalTerms = controller.termCounts.values.fold(0, (s, c) => s + c);
    final knownTerms =
        (controller.termCounts[TermStatus.known] ?? 0) +
        (controller.termCounts[TermStatus.wellKnown] ?? 0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(label: l10n.totalTerms, value: totalTerms, icon: Icons.book),
        _StatItem(label: l10n.known, value: knownTerms, icon: Icons.check_circle),
        _StatItem(label: l10n.texts, value: controller.totalTextsCount, icon: Icons.article),
        _StatItem(label: l10n.textsFinished, value: controller.finishedTextsCount, icon: Icons.done_all),
        _ReviewStatItem(controller: controller),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  const _StatItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isMobile = !PlatformHelper.isDesktop;
    final numberStyle = isMobile
        ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold);

    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(height: AppConstants.spacingXS),
        AnimatedCounter(value: value, style: numberStyle),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ReviewStatItem extends StatelessWidget {
  final DashboardController controller;
  const _ReviewStatItem({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        ReviewProgressRing(
          reviewedToday: controller.reviewedToday,
          dueCount: controller.dueCount,
        ),
        const SizedBox(height: AppConstants.spacingXS),
        Text(l10n.reviewedToday, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ChartsSection extends StatelessWidget {
  final DashboardController controller;
  final bool useDesktopLayout;
  const _ChartsSection({required this.controller, required this.useDesktopLayout});

  @override
  Widget build(BuildContext context) {
    if (useDesktopLayout) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 2, child: DailyActivityBarChart(data: controller.dailyActivityData, height: 280)),
            const SizedBox(width: AppConstants.spacingL),
            Expanded(flex: 2, child: VocabularyGrowthLineChart(data: controller.vocabularyGrowthData, height: 280)),
            const SizedBox(width: AppConstants.spacingL),
            SizedBox(width: 220, child: StatusDistributionDonutChart(data: controller.statusDistributionData)),
          ],
        ),
      );
    }
    return Column(
      children: [
        DailyActivityBarChart(data: controller.dailyActivityData, height: 250),
        const SizedBox(height: AppConstants.spacingL),
        VocabularyGrowthLineChart(data: controller.vocabularyGrowthData, height: 250),
        const SizedBox(height: AppConstants.spacingL),
        StatusDistributionDonutChart(data: controller.statusDistributionData),
      ],
    );
  }
}

class _RecentTextsCard extends StatelessWidget {
  final DashboardController controller;
  final bool recentlyRead;
  const _RecentTextsCard({required this.controller, required this.recentlyRead});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final texts = recentlyRead ? controller.recentlyReadTexts : controller.recentlyAddedTexts;
    final title = recentlyRead ? l10n.recentlyRead : l10n.recentlyAdded;
    final emptyMessage = recentlyRead ? l10n.noTextsReadYet : l10n.noTextsYetAddOne;
    final fallbackIcon = recentlyRead ? Icons.history : Icons.article;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppConstants.spacingM),
            if (texts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingL),
                child: Text(emptyMessage),
              )
            else
              ...texts.map(
                (text) => _TextListTile(
                  text: text,
                  controller: controller,
                  fallbackIcon: fallbackIcon,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TextListTile extends StatelessWidget {
  final TextDocument text;
  final DashboardController controller;
  final IconData fallbackIcon;
  const _TextListTile({required this.text, required this.controller, required this.fallbackIcon});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = controller.language;
    final collectionName = text.collectionId != null
        ? controller.collectionNames[text.collectionId]
        : null;
    final unknownCount = controller.unknownCounts[text.id] ?? 0;

    final subtitle = [
      ?collectionName,
      language.splitByCharacter
          ? l10n.charactersCount(text.characterCount)
          : l10n.wordsCount(text.wordCount),
      l10n.unknownCount(unknownCount),
    ].join(' • ');

    return ListTile(
      leading: _TextThumbnail(text: text, fallbackIcon: fallbackIcon),
      title: Text(text.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReaderScreen(text: text, language: language),
          ),
        );
      },
    );
  }
}

class _TextThumbnail extends StatelessWidget {
  final TextDocument text;
  final IconData fallbackIcon;
  const _TextThumbnail({required this.text, required this.fallbackIcon});

  @override
  Widget build(BuildContext context) {
    final resolvedCover = CoverImageHelper.resolve(text.coverImage);
    if (resolvedCover != null && File(resolvedCover).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_DashboardConstants.thumbnailBorderRadius),
        child: Image.file(
          File(resolvedCover),
          width: _DashboardConstants.thumbnailWidth,
          height: _DashboardConstants.thumbnailHeight,
          fit: BoxFit.cover,
        ),
      );
    }
    return SizedBox(
      width: _DashboardConstants.thumbnailWidth,
      height: _DashboardConstants.thumbnailHeight,
      child: Icon(fallbackIcon, size: _DashboardConstants.thumbnailWidth),
    );
  }
}
