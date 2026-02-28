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

class _GoalProgressDonutState extends State<GoalProgressDonut>
    with SingleTickerProviderStateMixin {
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
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.percent,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
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
    final isDark = theme.brightness == Brightness.dark;
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
                  isDark: isDark,
                ),
              );
            },
          ),
          if (widget.centerLabel != null)
            Text(
              widget.centerLabel!,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 34,
                color: widget.color ??
                    (isDark ? Colors.white : Colors.black87),
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
  final bool isDark;

  _DonutPainter({
    required this.percent,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
    required this.isDark,
  });

  static const double _pi = 3.141592653589793;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * _pi, false, bgPaint);

    final startAngle = -_pi / 2;
    final sweepAngle = 2 * _pi * (percent / 100).clamp(0.0, 1.0);

    if (sweepAngle <= 0) return;

    // Glow pass (dark mode only)
    if (isDark) {
      final glowPaint = Paint()
        ..color = color.withAlpha(70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2.2
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
    }

    // Main arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweepAngle, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.isDark != isDark;
  }
}
