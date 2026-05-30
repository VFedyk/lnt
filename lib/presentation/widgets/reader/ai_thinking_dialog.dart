import 'dart:async';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

class AiThinkingDialog extends StatefulWidget {
  const AiThinkingDialog({super.key});

  @override
  State<AiThinkingDialog> createState() => _AiThinkingDialogState();
}

class _AiThinkingDialogState extends State<AiThinkingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  int _textIndex = 0;
  Timer? _textTimer;

  @override
  void initState() {
    super.initState();
    _textTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() => _textIndex = (_textIndex + 1) % 4);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _textTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final textStages = [
      l10n.aiThinking,
      l10n.aiAnalyzing,
      l10n.aiProcessing,
      l10n.aiGenerating,
    ];

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: SizedBox(
        width: 220,
        height: 56,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, _) => CustomPaint(
            painter: _BorderDotPainter(progress: _controller.value),
            child: Center(
              child: Text(
                textStages[_textIndex],
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BorderDotPainter extends CustomPainter {
  final double progress;

  static const _borderRadius = 28.0;
  static const _dotColor = Color(0xFF42A5F5); // blue.shade400
  static const _tailColor = Color(0xFF90CAF9); // blue.shade200
  static const _tailFraction = 0.20;
  static const _tailSamples = 40;

  const _BorderDotPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(_borderRadius),
    );
    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    final perimeter = metric.length;

    // --- Tail ---
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < _tailSamples; i++) {
      final t = i / _tailSamples; // 0 = tail tip, 1 = dot
      final dist = ((progress - _tailFraction + t * _tailFraction) % 1.0)
          * perimeter;
      final tangent = metric.getTangentForOffset(dist);
      if (tangent == null) continue;

      final opacity = (t * 0.6).clamp(0.0, 1.0);
      final radius = 1.5 + t * 2.0; // grows toward the dot
      paint.color = _tailColor.withValues(alpha: opacity);
      canvas.drawCircle(tangent.position, radius, paint);
    }

    // --- Glowing dot ---
    final dotDist = progress * perimeter;
    final dotTangent = metric.getTangentForOffset(dotDist);
    if (dotTangent == null) return;
    final pos = dotTangent.position;

    // Outer glow
    paint
      ..color = _dotColor.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(pos, 10, paint);

    // Inner glow
    paint
      ..color = _dotColor.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(pos, 6, paint);

    // Solid core
    paint
      ..color = _dotColor
      ..maskFilter = null;
    canvas.drawCircle(pos, 3.5, paint);
  }

  @override
  bool shouldRepaint(_BorderDotPainter old) => old.progress != progress;
}

