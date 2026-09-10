import 'package:flutter/material.dart';

/// Scales [values] onto 0..1 for drawing, preserving order.
///
/// A flat series would divide by a zero range, so it is drawn as a centre
/// line instead. Fewer than two points cannot make a line at all.
List<double> sparklineNormalise(List<double> values) {
  if (values.length < 2) return const [];

  final min = values.reduce((a, b) => a < b ? a : b);
  final max = values.reduce((a, b) => a > b ? a : b);
  final range = max - min;

  if (range == 0) return values.map((_) => 0.5).toList();
  return values.map((v) => (v - min) / range).toList();
}

/// A minimal trend line — no axes, no labels, no grid.
///
/// The number beside it carries the value; this only has to show direction,
/// which is the one thing a column of logged weights does not communicate.
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color lineColor;
  final double height;
  final double strokeWidth;

  const Sparkline({
    super.key,
    required this.values,
    required this.lineColor,
    this.height = 44,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    final normalised = sparklineNormalise(values);
    if (normalised.isEmpty) return SizedBox(height: height);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          points: normalised,
          color: lineColor,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  final double strokeWidth;

  _SparklinePainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final stepX = size.width / (points.length - 1);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      // Invert: 1.0 is the highest value, which is the top of the box.
      final y = size.height - (points[i] * size.height);
      final x = stepX * i;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
