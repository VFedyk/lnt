import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// A freehand drawing canvas for handwriting practice.
///
/// Tracks strokes as lists of offsets, renders them on a [CustomPainter],
/// and provides a clear button. Designed for CJK character writing practice.
class HandwritingCanvas extends StatefulWidget {
  final VoidCallback? onStrokeAdded;

  const HandwritingCanvas({super.key, this.onStrokeAdded});

  @override
  State<HandwritingCanvas> createState() => HandwritingCanvasState();
}

class HandwritingCanvasState extends State<HandwritingCanvas> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;

  bool get hasStrokes => _strokes.isNotEmpty;

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
    });
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentStroke = [details.localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_currentStroke == null) return;
    setState(() {
      _currentStroke = [..._currentStroke!, details.localPosition];
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentStroke == null || _currentStroke!.isEmpty) return;
    setState(() {
      _strokes.add(List.unmodifiable(_currentStroke!));
      _currentStroke = null;
    });
    widget.onStrokeAdded?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strokeColor = colorScheme.onSurface;
    final guideColor = colorScheme.outlineVariant.withValues(alpha: 0.5);

    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  painter: _HandwritingPainter(
                    strokes: _strokes,
                    currentStroke: _currentStroke,
                    strokeColor: strokeColor,
                    guideColor: guideColor,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingS),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: hasStrokes ? clear : null,
            icon: const Icon(Icons.clear, size: 18),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}

class _HandwritingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset>? currentStroke;
  final Color strokeColor;
  final Color guideColor;

  const _HandwritingPainter({
    required this.strokes,
    required this.currentStroke,
    required this.strokeColor,
    required this.guideColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGuideLines(canvas, size);
    _drawStrokes(canvas, size);
  }

  void _drawGuideLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = guideColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Center cross-hair
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Diagonal guidelines (like Chinese writing practice grid)
    final dashPaint = Paint()
      ..color = guideColor.withValues(alpha: 0.4)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    _drawDashedLine(
      canvas,
      Offset(0, 0),
      Offset(size.width, size.height),
      dashPaint,
    );
    _drawDashedLine(
      canvas,
      Offset(size.width, 0),
      Offset(0, size.height),
      dashPaint,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLength = 6.0;
    const gapLength = 4.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final length = (p2 - p1).distance;
    final unitX = dx / length;
    final unitY = dy / length;

    double drawn = 0;
    while (drawn < length) {
      final endDash = drawn + dashLength > length ? length : drawn + dashLength;
      canvas.drawLine(
        Offset(p1.dx + unitX * drawn, p1.dy + unitY * drawn),
        Offset(p1.dx + unitX * endDash, p1.dy + unitY * endDash),
        paint,
      );
      drawn += dashLength + gapLength;
    }
  }

  void _drawStrokes(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      _drawSingleStroke(canvas, stroke, strokePaint);
    }

    if (currentStroke != null && currentStroke!.isNotEmpty) {
      _drawSingleStroke(canvas, currentStroke!, strokePaint);
    }
  }

  void _drawSingleStroke(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      canvas.drawCircle(points.first, 2.0, paint);
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HandwritingPainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.currentStroke != currentStroke ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.guideColor != guideColor;
}
