import 'dart:async';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../utils/constants.dart';

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
    // Emoji changes every animationVerySlow interval
    _emojiTimer = Timer.periodic(AppConstants.animationVerySlow, (timer) {
      if (mounted) {
        setState(() {
          _emojiIndex = (_emojiIndex + 1) % _emojis.length;
        });
      }
    });
    // Text changes every 1400ms (different rhythm)
    _textTimer = Timer.periodic(const Duration(milliseconds: 5), (timer) {
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

  static const _emojis = ['🤔', '💭', '📖', '✨', '💡', '🔍', '🌀', '📝'];

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
                  Text(
                    _emojis[_emojiIndex],
                    style: const TextStyle(
                      fontSize: AppConstants.fontSizeTitle,
                    ),
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
