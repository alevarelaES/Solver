import 'package:flutter/material.dart';

class MiniSparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double strokeWidth;

  const MiniSparkline({
    super.key,
    required this.data,
    required this.color,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    return CustomPaint(
      painter: _SparklinePainter(data: data, color: color, strokeWidth: strokeWidth),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double strokeWidth;

  _SparklinePainter({required this.data, required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    
    // Normalize data
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final range = maxVal - minVal;
    
    // Safety check to avoid division by zero
    final safeRange = range == 0 ? 1.0 : range;

    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      // Invert Y axis: 0 is at the bottom, size.height is at the top conceptually,
      // but canvas 0,0 is top-left.
      final normalizedY = (data[i] - minVal) / safeRange;
      final y = size.height - (normalizedY * size.height);
      final x = i * stepX;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return data != oldDelegate.data || color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
  }
}
