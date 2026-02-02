import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/term.dart';
import '../utils/constants.dart';

abstract class _StatusLegendConstants {
  static const double shadowAlpha = 0.1;
  static const double shadowBlur = 4.0;
  static const Offset shadowOffset = Offset(0, 2);
  static const double boxSize = 16.0;
  static const double borderRadiusXS = 3.0;
  static const double backgroundAlpha = 0.3;
  static const double borderAlpha = 0.5;
  static final Color wellKnownBorderColor = Colors.blue.shade300;
  static final Color wellKnownTextColor = Colors.blue.shade700;
}

class StatusLegend extends StatelessWidget {
  final Map<int, int>? termCounts;

  const StatusLegend({super.key, this.termCounts});

  String _getStatusName(int status, AppLocalizations l10n) {
    switch (status) {
      case TermStatus.ignored:
        return l10n.statusIgnored;
      case TermStatus.unknown:
        return l10n.statusUnknown;
      case TermStatus.learning2:
        return l10n.statusLearning2;
      case TermStatus.learning3:
        return l10n.statusLearning3;
      case TermStatus.learning4:
        return l10n.statusLearning4;
      case TermStatus.known:
        return l10n.statusKnown;
      case TermStatus.wellKnown:
        return l10n.statusWellKnown;
      default:
        return l10n.statusUnknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: _StatusLegendConstants.shadowAlpha,
            ),
            blurRadius: _StatusLegendConstants.shadowBlur,
            offset: _StatusLegendConstants.shadowOffset,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.statusLegendTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Wrap(
            spacing: AppConstants.spacingM,
            runSpacing: AppConstants.spacingS,
            children: TermStatus.allStatuses
                .map((status) => _buildLegendItem(
                      _getStatusName(status, l10n),
                      TermStatus.colorFor(status),
                      status,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int status) {
    final isIgnored = status == TermStatus.ignored;
    final isWellKnown = status == TermStatus.wellKnown;
    final count = termCounts?[status] ?? 0;
    final showCount = termCounts != null;

    if (isIgnored || isWellKnown) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _StatusLegendConstants.boxSize,
            height: _StatusLegendConstants.boxSize,
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(
                color: isIgnored
                    ? AppConstants.borderColor
                    : _StatusLegendConstants.wellKnownBorderColor,
              ),
              borderRadius: BorderRadius.circular(
                _StatusLegendConstants.borderRadiusXS,
              ),
            ),
            child: Center(
              child: Text(
                'A',
                style: TextStyle(
                  fontSize: AppConstants.fontSizeXS,
                  color: isIgnored
                      ? AppConstants.subtitleColor
                      : _StatusLegendConstants.wellKnownTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingXS),
          Text(
            showCount ? '$label ($count)' : label,
            style: const TextStyle(fontSize: AppConstants.fontSizeCaption),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _StatusLegendConstants.boxSize,
          height: _StatusLegendConstants.boxSize,
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: _StatusLegendConstants.backgroundAlpha,
            ),
            border: Border.all(
              color: color.withValues(
                alpha: _StatusLegendConstants.borderAlpha,
              ),
            ),
            borderRadius: BorderRadius.circular(
              _StatusLegendConstants.borderRadiusXS,
            ),
          ),
        ),
        const SizedBox(width: AppConstants.spacingXS),
        Text(
          showCount ? '$label ($count)' : label,
          style: const TextStyle(fontSize: AppConstants.fontSizeCaption),
        ),
      ],
    );
  }
}
