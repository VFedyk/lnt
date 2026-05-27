import 'dart:async';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';

class AiThinkingDialog extends StatefulWidget {
  const AiThinkingDialog({super.key});

  @override
  State<AiThinkingDialog> createState() => _AiThinkingDialogState();
}

class _AiThinkingDialogState extends State<AiThinkingDialog> {
  int _emojiIndex = 0;
  int _textIndex = 0;
  Timer? _emojiTimer;
  Timer? _textTimer;

  @override
  void initState() {
    super.initState();
    _emojiTimer = Timer.periodic(AppConstants.animationSlow, (timer) {
      if (mounted) {
        setState(() {
          _emojiIndex = (_emojiIndex + 1) % _waveFrames.length;
        });
      }
    });
    // Text changes every 1400ms (different rhythm)
    _textTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          _textIndex = (_textIndex + 1) % 4;
        });
      }
    });
  }

  @override
  void dispose() {
    _emojiTimer?.cancel();
    _textTimer?.cancel();
    super.dispose();
  }

  // Ping-pong: active dot index per frame → 0,1,2,1 → wave effect
  static const _waveFrames = [0, 1, 2, 1];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textStages = [
      l10n.aiThinking,
      l10n.aiAnalyzing,
      l10n.aiProcessing,
      l10n.aiGenerating,
    ];

    return Dialog(
      child: IntrinsicWidth(
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final isActive = _waveFrames[_emojiIndex] == i;
                      return Text(
                        isActive ? '●' : '○',
                        style: TextStyle(
                          fontSize: AppConstants.fontSizeTitle,
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: AppConstants.spacingS),
                  Text(
                    textStages[_textIndex],
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
