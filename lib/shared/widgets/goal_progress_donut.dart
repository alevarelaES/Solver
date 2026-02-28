import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_premium_theme.dart';

class GoalProgressDonut extends StatefulWidget {
  final double percent; // 0.0 to 100.0
  final double size;
  final Color? color;
  final String? centerLabel;
  final double strokeWidth;

  const GoalProgressDonut({
    super.key,
    required this.percent,
    this.size = 100,
    this.color,
    this.centerLabel,
    this.strokeWidth = 10,
  });

  @override
  State<GoalProgressDonut> createState() => _GoalProgressDonutState();
}

class _GoalProgressDonutState extends State<GoalProgressDonut> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0, end: widget.percent).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant GoalProgressDonut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percent != widget.percent) {
      _animation = Tween<double>(begin: _animation.value, end: widget.percent).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
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
    final theme = Theme.of(context);
    final p = theme.extension<PremiumThemeExtension>()!;
    final color = widget.color ?? theme.colorScheme.primary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _DonutPainter(
                  percent: _animation.value,
                  color: color,
                  backgroundColor: p.glassBorder,
                  strokeWidth: widget.strokeWidth,
                ),
              );
            },
          ),
          if (widget.centerLabel != null)
            Text(
              widget.centerLabel!,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.brightness == Brightness.dark ? Colors.white : Colors.black87,
              ),
            ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double percent;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _DonutPainter({
    required this.percent,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw background track
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    // Draw full circle for the background track
    canvas.drawArc(rect, 0, 2 * 3.141592653589793, false, bgPaint);

    // Draw progress arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Start at top (-pi/2)
    final startAngle = -3.141592653589793 / 2;
    // Sweep depends on percent
    final sweepAngle = 2 * 3.141592653589793 * (percent / 100).clamp(0.0, 1.0);

    // Only draw sweep if progress > 0 to avoid artifacts
    if (sweepAngle > 0) {
      canvas.drawArc(rect, startAngle, sweepAngle, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.percent != percent ||
           oldDelegate.color != color ||
           oldDelegate.backgroundColor != backgroundColor ||
           oldDelegate.strokeWidth != strokeWidth;
  }
}
