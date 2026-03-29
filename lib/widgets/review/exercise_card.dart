import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class ExerciseCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int dueCount;
  final VoidCallback onTap;

  const ExerciseCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.dueCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              Badge(
                label: Text(dueCount.toString()),
                isLabelVisible: dueCount > 0,
                child: Icon(icon, size: 60, color: colorScheme.primary),
              ),
              const SizedBox(width: AppConstants.spacingL),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
