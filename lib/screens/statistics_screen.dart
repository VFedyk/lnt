// FILE: lib/screens/statistics_screen.dart
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/term.dart';
import '../service_locator.dart';
import '../services/logger_service.dart';
import '../utils/constants.dart';

abstract class _StatisticsConstants {
  static const double progressBarHeight = 10.0;
  static const double statusBarHeight = 8.0;
  static const double progressCardBackgroundOpacity = 0.1;
  static const double progressCardBorderOpacity = 0.3;
  static const Color totalTermsColor = Colors.blue;
  static const Color textsColor = Colors.purple;
}

class StatisticsScreen extends StatefulWidget {
  final Language language;

  const StatisticsScreen({super.key, required this.language});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<int, int> _statusCounts = {};
  int _totalTerms = 0;
  int _totalTexts = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  @override
  void didUpdateWidget(StatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language.id != widget.language.id) {
      _loadStatistics();
    }
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final counts = await db.terms.getCountsByStatus(
        widget.language.id!,
      );
      final termCount = await db.terms.getTotalCount(
        widget.language.id!,
      );
      final textCount = await db.texts.getCountByLanguage(
        widget.language.id!,
      );

      setState(() {
        _statusCounts = counts;
        _totalTerms = termCount;
        _totalTexts = textCount;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('Statistics load failed', error: e, stackTrace: stackTrace);
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.stats)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.stats)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: AppConstants.spacingM),
              Text(l10n.failedToLoadData, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppConstants.spacingM),
              ElevatedButton.icon(
                onPressed: _loadStatistics,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    final knownCount = (_statusCounts[5] ?? 0) + (_statusCounts[99] ?? 0);
    final learningCount =
        (_statusCounts[1] ?? 0) +
        (_statusCounts[2] ?? 0) +
        (_statusCounts[3] ?? 0) +
        (_statusCounts[4] ?? 0);
    final ignoredCount = _statusCounts[0] ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.stats)),
      body: RefreshIndicator(
        onRefresh: _loadStatistics,
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              child: Column(
                children: [
                  Text(
                    widget.language.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppConstants.spacingXL),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        l10n.totalTerms,
                        _totalTerms.toString(),
                        Icons.book,
                        _StatisticsConstants.totalTermsColor,
                      ),
                      _buildStatColumn(
                        l10n.known,
                        knownCount.toString(),
                        Icons.check_circle,
                        AppConstants.successColor,
                      ),
                      _buildStatColumn(
                        l10n.texts,
                        _totalTexts.toString(),
                        Icons.article,
                        _StatisticsConstants.textsColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingL),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.termsByStatus,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppConstants.spacingL),
                  _buildStatusBar(
                    TermStatus.ignored,
                    l10n.statusIgnored,
                    ignoredCount,
                    TermStatus.colorFor(TermStatus.ignored),
                  ),
                  _buildStatusBar(
                    TermStatus.unknown,
                    l10n.statusUnknown,
                    _statusCounts[TermStatus.unknown] ?? 0,
                    TermStatus.colorFor(TermStatus.unknown),
                  ),
                  _buildStatusBar(
                    TermStatus.learning2,
                    l10n.statusLearning2,
                    _statusCounts[TermStatus.learning2] ?? 0,
                    TermStatus.colorFor(TermStatus.learning2),
                  ),
                  _buildStatusBar(
                    TermStatus.learning3,
                    l10n.statusLearning3,
                    _statusCounts[TermStatus.learning3] ?? 0,
                    TermStatus.colorFor(TermStatus.learning3),
                  ),
                  _buildStatusBar(
                    TermStatus.learning4,
                    l10n.statusLearning4,
                    _statusCounts[TermStatus.learning4] ?? 0,
                    TermStatus.colorFor(TermStatus.learning4),
                  ),
                  _buildStatusBar(
                    TermStatus.known,
                    l10n.statusKnown,
                    _statusCounts[TermStatus.known] ?? 0,
                    TermStatus.colorFor(TermStatus.known),
                  ),
                  _buildStatusBar(
                    TermStatus.wellKnown,
                    l10n.statusWellKnown,
                    _statusCounts[TermStatus.wellKnown] ?? 0,
                    TermStatus.colorFor(TermStatus.wellKnown),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingL),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.progressOverview,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppConstants.spacingL),
                  LinearProgressIndicator(
                    value: _totalTerms > 0 ? knownCount / _totalTerms : 0,
                    minHeight: _StatisticsConstants.progressBarHeight,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(AppConstants.successColor),
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    _totalTerms > 0
                        ? l10n.percentKnown((knownCount / _totalTerms * 100).toStringAsFixed(1))
                        : l10n.noTermsYet,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppConstants.spacingL),
                  Row(
                    children: [
                      Expanded(
                        child: _buildProgressCard(
                          l10n.learning,
                          learningCount,
                          AppConstants.warningColor,
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingS),
                      Expanded(
                        child: _buildProgressCard(
                          l10n.known,
                          knownCount,
                          AppConstants.successColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildStatColumn(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: AppConstants.iconSizeM, color: color),
        const SizedBox(height: AppConstants.spacingS),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label),
      ],
    );
  }

  Widget _buildStatusBar(int status, String label, int count, Color color) {
    final percentage = _totalTerms > 0 ? count / _totalTerms : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingXS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$label ($count)'),
              Text('${(percentage * 100).toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: AppConstants.spacingXS),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: _StatisticsConstants.statusBarHeight,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _StatisticsConstants.progressCardBackgroundOpacity),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
        border: Border.all(color: color.withValues(alpha: _StatisticsConstants.progressCardBorderOpacity)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label),
        ],
      ),
    );
  }
}
