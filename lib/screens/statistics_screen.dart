// FILE: lib/screens/statistics_screen.dart
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/term.dart';
import '../services/database_service.dart';

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
    setState(() => _isLoading = true);
    try {
      final counts = await DatabaseService.instance.getTermCountsByStatus(
        widget.language.id!,
      );
      final termCount = await DatabaseService.instance.getTotalTermCount(
        widget.language.id!,
      );
      final textCount = await DatabaseService.instance.getTotalTextCount(
        widget.language.id!,
      );

      setState(() {
        _statusCounts = counts;
        _totalTerms = termCount;
        _totalTexts = textCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final knownCount = (_statusCounts[5] ?? 0) + (_statusCounts[99] ?? 0);
    final learningCount =
        (_statusCounts[1] ?? 0) +
        (_statusCounts[2] ?? 0) +
        (_statusCounts[3] ?? 0) +
        (_statusCounts[4] ?? 0);
    final ignoredCount = _statusCounts[0] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    widget.language.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        l10n.totalTerms,
                        _totalTerms.toString(),
                        Icons.book,
                        Colors.blue,
                      ),
                      _buildStatColumn(
                        l10n.known,
                        knownCount.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                      _buildStatColumn(
                        l10n.texts,
                        _totalTexts.toString(),
                        Icons.article,
                        Colors.purple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.termsByStatus,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.progressOverview,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _totalTerms > 0 ? knownCount / _totalTerms : 0,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _totalTerms > 0
                        ? l10n.percentKnown((knownCount / _totalTerms * 100).toStringAsFixed(1))
                        : l10n.noTermsYet,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildProgressCard(
                          l10n.learning,
                          learningCount,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildProgressCard(
                          l10n.known,
                          knownCount,
                          Colors.green,
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
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
