import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../service_locator.dart';
import '../../utils/constants.dart';
import '../../utils/radicals.dart';
import '../widgets/shared/hanzi_writer_widget.dart';

class RadicalWritingScreen extends StatefulWidget {
  final Radical radical;

  const RadicalWritingScreen({super.key, required this.radical});

  @override
  State<RadicalWritingScreen> createState() => _RadicalWritingScreenState();
}

class _RadicalWritingScreenState extends State<RadicalWritingScreen> {
  int _strokesDone = 0;
  int _totalStrokes = 0;
  int _mistakes = 0;

  void _onEvent(HanziWriterEvent event) {
    if (!mounted) return;
    switch (event) {
      case HanziWriterStrokeEvent(:final strokeNum, :final totalStrokes):
        setState(() {
          _strokesDone = strokeNum + 1;
          _totalStrokes = totalStrokes;
        });
      case HanziWriterMistakeEvent():
        setState(() => _mistakes++);
      case HanziWriterCompleteEvent(:final totalMistakes):
        setState(() {
          _mistakes = totalMistakes;
        });
        db.radicalProgress.recordCompletion(widget.radical.char);
        _showCompleteDialog();
      case HanziWriterLoadErrorEvent():
        break;
    }
  }

  void _showCompleteDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.practiceComplete),
        content: Text(l10n.mistakesCount(_mistakes)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(l10n.close),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _strokesDone = 0;
                _totalStrokes = 0;
                _mistakes = 0;
                _widgetKey = UniqueKey();
              });
            },
            child: Text(l10n.practiceAgain),
          ),
        ],
      ),
    );
  }

  Key _widgetKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.radicalWritingTitle(widget.radical.char)),
        actions: [
          if (_totalStrokes > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppConstants.spacingM),
              child: Center(
                child: Text(
                  l10n.strokeProgress(_strokesDone, _totalStrokes),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Mistake counter
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingL,
              vertical: AppConstants.spacingS,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.radical.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_mistakes > 0)
                  Text(
                    l10n.mistakesCount(_mistakes),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.error,
                        ),
                  ),
              ],
            ),
          ),

          // Stroke progress bar
          if (_totalStrokes > 0)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingL,
              ),
              child: LinearProgressIndicator(
                value: _strokesDone / _totalStrokes,
                backgroundColor:
                    colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
              ),
            ),

          const SizedBox(height: AppConstants.spacingS),

          // Hanzi Writer canvas
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: HanziWriterWidget(
                key: _widgetKey,
                character: widget.radical.char,
                onEvent: _onEvent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
