import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../domain/entities/term.dart';
import '../../controllers/term_dialog_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/term_status_ui.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';

/// "History" tab of the term dialog: a summary, a status-journey chart, the
/// status-change timeline, and the full review log for a single term.
class TermHistoryView extends StatelessWidget {
  final TermDialogController controller;
  final Term term;

  const TermHistoryView({
    super.key,
    required this.controller,
    required this.term,
  });

  // Maps a term status to a vertical rank for the journey chart (low = new).
  static const Map<int, int> _statusRank = {1: 0, 2: 1, 3: 2, 4: 3, 5: 4, 99: 5};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (term.id == null) {
      return _centeredHint(context, l10n.noHistoryYet);
    }
    if (controller.historyLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingS),
      children: [
        _summaryCard(context, l10n),
        if (controller.statusTransitions.length >= 2) ...[
          const SizedBox(height: AppConstants.spacingL),
          _journeyCard(context, l10n),
        ],
        if (controller.statusTransitions.isNotEmpty) ...[
          const SizedBox(height: AppConstants.spacingL),
          _statusTimelineCard(context, l10n),
        ],
        if (controller.reviewHistory.isNotEmpty) ...[
          const SizedBox(height: AppConstants.spacingL),
          _reviewLogCard(context, l10n),
        ],
      ],
    );
  }

  Widget _centeredHint(BuildContext context, String text) => Center(
        child: Text(
          text,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );

  Widget _summaryCard(BuildContext context, AppLocalizations l10n) {
    final total = controller.totalReviews;
    final lastReviewed = controller.lastReviewedAt;
    final nextDue = controller.nextDue;
    final retention = total > 0
        ? ' · ${(controller.recalledCount / total * 100).round()}%'
        : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    TermStatusUI.localizedNameFor(term.status, l10n),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _statusDot(term.status),
              ],
            ),
            const Divider(height: AppConstants.spacingL),
            _summaryRow(context, l10n.created, DateHelper.formatDate(term.createdAt)),
            _summaryRow(
              context,
              l10n.lastReviewed,
              lastReviewed != null
                  ? DateHelper.formatRelativeTime(lastReviewed)
                  : l10n.neverReviewed,
            ),
            _summaryRow(context, l10n.reviews, '$total$retention'),
            if (nextDue != null)
              _summaryRow(
                context,
                l10n.nextReview,
                DateHelper.formatRelativeFuture(nextDue),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingXS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _journeyCard(BuildContext context, AppLocalizations l10n) {
    final transitions = controller.statusTransitions;
    final spots = <FlSpot>[
      for (var i = 0; i < transitions.length; i++)
        FlSpot(i.toDouble(), (_statusRank[transitions[i].status] ?? 0).toDouble()),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.statusChanges, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppConstants.spacingL),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: -0.5,
                  maxY: 5.5,
                  minX: 0,
                  maxX: (transitions.length - 1).toDouble(),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= transitions.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: AppConstants.spacingXS),
                            child: Text(
                              DateHelper.formatDate(transitions[i].changedAt),
                              style: TextStyle(
                                fontSize: AppConstants.fontSizeCaption,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      barWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                          radius: 4,
                          color: TermStatusUI.colorFor(
                            transitions[spot.x.toInt()].status,
                          ),
                          strokeWidth: 0,
                        ),
                      ),
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

  Widget _statusTimelineCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.statusChanges, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppConstants.spacingS),
            for (final t in controller.statusTransitions.reversed)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppConstants.spacingXS),
                child: Row(
                  children: [
                    _statusDot(t.status),
                    const SizedBox(width: AppConstants.spacingM),
                    Expanded(
                      child: Text(TermStatusUI.localizedNameFor(t.status, l10n)),
                    ),
                    Text(
                      DateHelper.formatDate(t.changedAt),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: AppConstants.fontSizeCaption,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _reviewLogCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.reviews, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppConstants.spacingS),
            for (final r in controller.reviewHistory.reversed)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppConstants.spacingXS),
                child: Row(
                  children: [
                    _ratingChip(context, l10n, r.rating),
                    const Spacer(),
                    Text(
                      DateHelper.formatRelativeTime(r.reviewedAt),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: AppConstants.fontSizeCaption,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusDot(int status) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: TermStatusUI.colorFor(status),
          shape: BoxShape.circle,
        ),
      );

  Widget _ratingChip(BuildContext context, AppLocalizations l10n, int rating) {
    final (color, label) = switch (rating) {
      1 => (Theme.of(context).colorScheme.error, l10n.rateAgain),
      2 => (context.appColors.warning, l10n.rateHard),
      3 => (context.appColors.success, l10n.rateGood),
      4 => (context.appColors.success, l10n.rateEasy),
      _ => (Theme.of(context).colorScheme.onSurfaceVariant, '?'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingS,
        vertical: AppConstants.spacingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
