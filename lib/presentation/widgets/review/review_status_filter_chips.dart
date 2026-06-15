import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../domain/value_objects/term_status.dart';
import '../../../utils/constants.dart';

/// User-facing grouping of term statuses for the review filter. Mirrors the
/// grouping used on the statistics screen (Learning folds the three learning
/// stages together).
enum ReviewStatusGroup {
  unknown([TermStatus.unknown]),
  learning([
    TermStatus.learning2,
    TermStatus.learning3,
    TermStatus.learning4,
  ]),
  known([TermStatus.known]),
  wellKnown([TermStatus.wellKnown]);

  const ReviewStatusGroup(this.statuses);

  final List<int> statuses;

  String label(AppLocalizations l10n) => switch (this) {
        ReviewStatusGroup.unknown => l10n.statusUnknown,
        ReviewStatusGroup.learning => l10n.learning,
        ReviewStatusGroup.known => l10n.statusKnown,
        ReviewStatusGroup.wellKnown => l10n.statusWellKnown,
      };

  /// Flattens [selected] to a status-id list, or null when the selection is
  /// empty or covers every group (both mean "no filter").
  static List<int>? filterFor(Set<ReviewStatusGroup> selected) {
    if (selected.isEmpty || selected.length == values.length) return null;
    return [for (final g in selected) ...g.statuses];
  }
}

/// Multi-select chip row that scopes a review session to chosen statuses.
class ReviewStatusFilterChips extends StatelessWidget {
  final Set<ReviewStatusGroup> selected;
  final ValueChanged<Set<ReviewStatusGroup>> onChanged;

  const ReviewStatusFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.reviewByStatus,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppConstants.spacingS),
        Wrap(
          spacing: AppConstants.spacingS,
          runSpacing: AppConstants.spacingS,
          children: ReviewStatusGroup.values.map((group) {
            return FilterChip(
              label: Text(group.label(l10n)),
              selected: selected.contains(group),
              onSelected: (isSelected) {
                final next = {...selected};
                if (isSelected) {
                  next.add(group);
                } else {
                  next.remove(group);
                }
                onChanged(next);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
