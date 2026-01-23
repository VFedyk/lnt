import 'package:flutter/material.dart';
import '../models/term.dart';

class StatusLegend extends StatelessWidget {
  final Map<int, int>? termCounts; // Optional term counts by status

  const StatusLegend({super.key, this.termCounts});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status Legend',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: TermStatus.allStatuses
                .map((status) => _buildLegendItem(
                      TermStatus.nameFor(status),
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
      // Show as plain text for ignored and well-known
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(
                color: isIgnored ? Colors.grey.shade400 : Colors.blue.shade300,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Center(
              child: Text(
                'A',
                style: TextStyle(
                  fontSize: 10,
                  color: isIgnored
                      ? Colors.grey.shade600
                      : Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            showCount ? '$label ($count)' : label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            border: Border.all(color: color.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          showCount ? '$label ($count)' : label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
