import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';

class MiniSparkline extends StatelessWidget {
  final List<double>? prices;
  final double? changePercent;
  final double width;
  final double height;
  final Color? color;

  const MiniSparkline({
    super.key,
    this.prices,
    this.changePercent,
    this.width = 42,
    this.height = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final points = _resolvePoints();
    if (points.length < 2) {
      return SizedBox(width: width, height: height);
    }

    final isPositive = points.last >= points.first;
    final lineColor =
        color ?? (isPositive ? AppColors.success : AppColors.danger);

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _MiniSparklinePainter(points: points, color: lineColor),
      ),
    );
  }

  List<double> _resolvePoints() {
    final raw = prices?.where((v) => v.isFinite).toList() ?? const <double>[];
    if (raw.length >= 2) return raw;

    final trend = changePercent ?? 0;
    return [0, trend * 0.3, trend * 0.6, trend];
  }
}

class _MiniSparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;

  const _MiniSparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final minVal = points.reduce((a, b) => a < b ? a : b);
    final maxVal = points.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).abs() < 0.000001 ? 1.0 : (maxVal - minVal);

    final stepX = points.length == 1
        ? size.width
        : size.width / (points.length - 1);
    final path = Path();

    for (var i = 0; i < points.length; i++) {
      final normalized = (points[i] - minVal) / range;
      final x = i * stepX;
      final y = size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.points != points;
  }
}
