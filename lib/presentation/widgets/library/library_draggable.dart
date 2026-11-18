import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Drag source for library items that keeps touch scrolling working.
///
/// - Mouse / trackpad: press and move drags immediately; long-press or
///   right-click opens the options ([onShowOptions]).
/// - Touch / stylus: a quick swipe scrolls the parent; hold-then-move drags;
///   hold-then-lift without moving opens the options.
class LibraryDraggable extends StatefulWidget {
  final Object data;
  final Widget feedback;
  final Widget childWhenDragging;
  final Widget child;
  final VoidCallback? onShowOptions;

  const LibraryDraggable({
    super.key,
    required this.data,
    required this.feedback,
    required this.childWhenDragging,
    required this.child,
    this.onShowOptions,
  });

  @override
  State<LibraryDraggable> createState() => _LibraryDraggableState();
}

const _pointerDevices = {PointerDeviceKind.mouse, PointerDeviceKind.trackpad};
const _touchDevices = {
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.unknown,
};

class _LibraryDraggableState extends State<LibraryDraggable> {
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    final onShowOptions = widget.onShowOptions;

    Widget result = _PointerDraggable(
      data: widget.data,
      feedback: widget.feedback,
      childWhenDragging: widget.childWhenDragging,
      child: _TouchDraggable(
        data: widget.data,
        feedback: widget.feedback,
        childWhenDragging: widget.childWhenDragging,
        onDragStarted: () => _dragDistance = 0,
        onDragUpdate: (details) => _dragDistance += details.delta.distance,
        onDraggableCanceled: (_, _) {
          if (_dragDistance < kTouchSlop) onShowOptions?.call();
        },
        child: widget.child,
      ),
    );

    if (onShowOptions != null) {
      result = GestureDetector(
        supportedDevices: _pointerDevices,
        onLongPress: onShowOptions,
        onSecondaryTap: onShowOptions,
        child: result,
      );
    }
    return result;
  }
}

class _PointerDraggable extends Draggable<Object> {
  const _PointerDraggable({
    required super.data,
    required super.feedback,
    required super.childWhenDragging,
    required super.child,
  });

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) {
    return ImmediateMultiDragGestureRecognizer(
      supportedDevices: _pointerDevices,
      allowedButtonsFilter: allowedButtonsFilter,
    )..onStart = onStart;
  }
}

class _TouchDraggable extends Draggable<Object> {
  const _TouchDraggable({
    required super.data,
    required super.feedback,
    required super.childWhenDragging,
    required super.child,
    super.onDragStarted,
    super.onDragUpdate,
    super.onDraggableCanceled,
  });

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) {
    return DelayedMultiDragGestureRecognizer(
      delay: kLongPressTimeout,
      supportedDevices: _touchDevices,
      allowedButtonsFilter: allowedButtonsFilter,
    )..onStart = (Offset position) {
      final Drag? result = onStart(position);
      if (result != null) HapticFeedback.selectionClick();
      return result;
    };
  }
}
