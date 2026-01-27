import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A professional, subtle sparkline for trend visualization
class TrendSparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;
  final bool showPoints;
  final bool useGradient;

  const TrendSparkline({
    super.key,
    required this.data,
    this.color = AppTheme.primaryCyan,
    this.height = 40,
    this.showPoints = false,
    this.useGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return SizedBox(height: height);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          data: data,
          color: color,
          showPoints: showPoints,
          useGradient: useGradient,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool showPoints;
  final bool useGradient;

  _SparklinePainter({
    required this.data,
    required this.color,
    required this.showPoints,
    required this.useGradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final double stepX = size.width / (data.length - 1);
    
    // Find min/max for scaling (or use 0-100 as these are scores)
    const double minVal = 0;
    const double maxVal = 100;
    final double range = maxVal - minVal;

    double getY(double value) {
      final normalized = (value - minVal) / (range == 0 ? 1 : range);
      return size.height - (normalized * size.height);
    }

    path.moveTo(0, getY(data[0]));

    for (int i = 1; i < data.length; i++) {
      path.lineTo(i * stepX, getY(data[i]));
    }

    if (useGradient) {
      final fillPath = Path.from(path);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.3),
            color.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);
    }

    canvas.drawPath(path, paint);

    if (showPoints) {
      final pointPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      for (int i = 0; i < data.length; i++) {
        canvas.drawCircle(Offset(i * stepX, getY(data[i])), 3, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}
