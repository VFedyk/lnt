import 'package:flutter/material.dart';

abstract class _AnimatedCounterConstants {
  static const Duration defaultDuration = Duration(milliseconds: 800);
  static const Curve defaultCurve = Curves.easeOutCubic;
}

class AnimatedCounter extends StatefulWidget {
  final int value;
  final Duration duration;
  final Curve curve;
  final TextStyle? style;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = _AnimatedCounterConstants.defaultDuration,
    this.curve = _AnimatedCounterConstants.defaultCurve,
    this.style,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _setupAnimation();
    _controller.forward();
  }

  void _setupAnimation() {
    _animation = Tween<double>(
      begin: _previousValue.toDouble(),
      end: widget.value.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          _animation.value.round().toString(),
          style: widget.style,
        );
      },
    );
  }
}
