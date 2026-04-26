import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../domain/entities/radical_progress.dart';
import '../service_locator.dart';
import '../utils/constants.dart';
import '../utils/radicals.dart';
import 'radical_writing_screen.dart';

class RadicalPracticeScreen extends StatefulWidget {
  const RadicalPracticeScreen({super.key});

  @override
  State<RadicalPracticeScreen> createState() => _RadicalPracticeScreenState();
}

class _RadicalPracticeScreenState extends State<RadicalPracticeScreen> {
  Map<String, RadicalProgress> _progress = {};
  int? _strokeFilter; // null = show all

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final progress = await db.radicalProgress.getAll();
    if (mounted) setState(() => _progress = progress);
  }

  List<Radical> get _filtered {
    if (_strokeFilter == null) return kRadicals;
    return kRadicals.where((r) => r.strokes == _strokeFilter).toList();
  }

  List<int> get _strokeCounts {
    final counts = kRadicals.map((r) => r.strokes).toSet().toList()..sort();
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.radicalPracticeTitle)),
      body: Column(
        children: [
          // Stroke-count filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingM,
                vertical: AppConstants.spacingXS,
              ),
              children: [
                FilterChip(
                  label: Text(l10n.allStrokes),
                  selected: _strokeFilter == null,
                  onSelected: (_) => setState(() => _strokeFilter = null),
                ),
                ...(_strokeCounts.map(
                  (n) => Padding(
                    padding: const EdgeInsets.only(left: AppConstants.spacingXS),
                    child: FilterChip(
                      label: Text(l10n.strokesN(n)),
                      selected: _strokeFilter == n,
                      onSelected: (_) =>
                          setState(() => _strokeFilter = _strokeFilter == n ? null : n),
                    ),
                  ),
                )),
              ],
            ),
          ),

          // Grid of radicals
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 110,
                mainAxisSpacing: AppConstants.spacingS,
                crossAxisSpacing: AppConstants.spacingS,
                childAspectRatio: 0.85,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final radical = filtered[i];
                final prog = _progress[radical.char];
                final practiced = prog != null && prog.practicedCount > 0;
                return _RadicalCard(
                  radical: radical,
                  practicedCount: prog?.practicedCount ?? 0,
                  practiced: practiced,
                  colorScheme: colorScheme,
                  l10n: l10n,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RadicalWritingScreen(radical: radical),
                      ),
                    );
                    _loadProgress();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RadicalCard extends StatelessWidget {
  final Radical radical;
  final int practicedCount;
  final bool practiced;
  final ColorScheme colorScheme;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _RadicalCard({
    required this.radical,
    required this.practicedCount,
    required this.practiced,
    required this.colorScheme,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingS),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    radical.char,
                    style: const TextStyle(fontSize: AppConstants.fontSizeDisplay),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    radical.name,
                    style: Theme.of(context).textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    l10n.strokesN(radical.strokes),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
            if (practicedCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$practicedCount×',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: AppConstants.fontSizeBadge,
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
