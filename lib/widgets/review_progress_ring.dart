import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'animated_counter.dart';

abstract class _ReviewProgressRingConstants {
  static const double defaultSize = 44.0;
  static const double strokeWidth = 4.0;
  static const double backgroundOpacity = 0.2;
  static const Duration animationDuration = Duration(milliseconds: 800);
  static const Curve animationCurve = Curves.easeOutCubic;
}

/// A compact circular progress ring showing review completion.
///
/// Renders only the ring with the [reviewedToday] count centered inside.
/// The caller is responsible for adding a label below to match other stat items.
class ReviewProgressRing extends StatefulWidget {
  final int reviewedToday;
  final int dueCount;
  final double size;
  final TextStyle? style;

  const ReviewProgressRing({
    super.key,
    required this.reviewedToday,
    required this.dueCount,
    this.size = _ReviewProgressRingConstants.defaultSize,
    this.style,
  });

  @override
  State<ReviewProgressRing> createState() => _ReviewProgressRingState();
}

class _ReviewProgressRingState extends State<ReviewProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousProgress = 0;

  double get _progress {
    final total = widget.reviewedToday + widget.dueCount;
    if (total == 0) return 1.0;
    return widget.reviewedToday / total;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: _ReviewProgressRingConstants.animationDuration,
      vsync: this,
    );
    _setupAnimation();
    _controller.forward();
  }

  void _setupAnimation() {
    _animation = Tween<double>(
      begin: _previousProgress,
      end: _progress,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: _ReviewProgressRingConstants.animationCurve,
    ));
  }

  @override
  void didUpdateWidget(ReviewProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reviewedToday != widget.reviewedToday ||
        oldWidget.dueCount != widget.dueCount) {
      final oldTotal = oldWidget.reviewedToday + oldWidget.dueCount;
      _previousProgress =
          oldTotal == 0 ? 1.0 : oldWidget.reviewedToday / oldTotal;
      _setupAnimation();
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _RingPainter(
            progress: _animation.value,
            color: colorScheme.primary,
            backgroundColor: colorScheme.primary.withValues(
              alpha: _ReviewProgressRingConstants.backgroundOpacity,
            ),
            strokeWidth: _ReviewProgressRingConstants.strokeWidth,
          ),
          child: child,
        );
      },
      child: SizedBox.square(
        dimension: widget.size,
        child: Center(
          child: AnimatedCounter(
            value: widget.reviewedToday,
            style: widget.style ??
                Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Foreground arc
    if (progress > 0) {
      final fgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // start at top
        2 * math.pi * progress,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
