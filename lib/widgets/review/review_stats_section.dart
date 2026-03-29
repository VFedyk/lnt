import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../utils/constants.dart';
import '../../widgets/shared/animated_counter.dart';
import '../../widgets/shared/review_progress_ring.dart';

class ReviewStatsSection extends StatelessWidget {
  final int dueCount;
  final int reviewedToday;
  final VoidCallback onStatsTap;

  const ReviewStatsSection({
    super.key,
    required this.dueCount,
    required this.reviewedToday,
    required this.onStatsTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Cards due
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule, color: colorScheme.secondary),
                      const SizedBox(width: AppConstants.spacingXS),
                      AnimatedCounter(
                        value: dueCount,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(l10n.cardsDue, style: textTheme.bodySmall),
                ],
              ),

              // Reviewed today
              Column(
                children: [
                  ReviewProgressRing(
                    reviewedToday: reviewedToday,
                    dueCount: dueCount,
                  ),
                  const Spacer(),
                  Text(l10n.reviewedToday, style: textTheme.bodySmall),
                ],
              ),

              // Detailed stats button
              InkWell(
                onTap: onStatsTap,
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  children: [
                    Icon(
                      Icons.bar_chart,
                      size: 44,
                      color: colorScheme.secondary,
                    ),
                    const Spacer(),
                    Text(l10n.detailedStats, style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
