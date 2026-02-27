import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_premium_theme.dart';

class PremiumSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double? borderRadius;
  final bool isCircle;

  const PremiumSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.isCircle = false,
  });

  factory PremiumSkeleton.kpiCard() {
    return const _KpiCard();
  }

  factory PremiumSkeleton.listItem() {
    return const _ListItem();
  }

  factory PremiumSkeleton.chart({double height = 180}) {
    return PremiumSkeleton(width: double.infinity, height: height);
  }

  factory PremiumSkeleton.textLine({double width = double.infinity}) {
    return PremiumSkeleton(width: width, height: 16);
  }

  factory PremiumSkeleton.heroCard() {
    return const _HeroCard();
  }

  @override
  State<PremiumSkeleton> createState() => _PremiumSkeletonState();
}

class _PremiumSkeletonState extends State<PremiumSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = Theme.of(context).extension<PremiumThemeExtension>();
    if (p != null) {
      _controller.duration = p.skeletonDuration;
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Gradient stops: x - 0.2, x, x + 0.2
        // So it moves horizontally across the box width.
        // We use Alignment(-1 + 2*v, 0) logic
        final x = -1.0 + 3.0 * _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.isCircle
                ? null
                : BorderRadius.circular(widget.borderRadius ?? p.skeletonRadius),
            gradient: LinearGradient(
              colors: [
                p.skeletonBase,
                p.skeletonShimmer,
                p.skeletonBase,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(x - 1, 0),
              end: Alignment(x + 1, 0),
            ),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Composites
// -----------------------------------------------------------------------------

class _KpiCard extends PremiumSkeleton {
  const _KpiCard() : super(width: double.infinity, height: 100);

  @override
  State<PremiumSkeleton> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            PremiumSkeleton(width: 40, height: 40, isCircle: true),
            PremiumSkeleton(width: 50, height: 24, borderRadius: 12),
          ],
        ),
        const SizedBox(height: 16),
        PremiumSkeleton(width: 100, height: 24),
        const SizedBox(height: 8),
        PremiumSkeleton(width: double.infinity, height: 32),
      ],
    );
  }
}

class _ListItem extends PremiumSkeleton {
  const _ListItem() : super(width: double.infinity, height: 60);

  @override
  State<PremiumSkeleton> createState() => _ListItemState();
}

class _ListItemState extends State<_ListItem> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          PremiumSkeleton(width: 40, height: 40, isCircle: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                PremiumSkeleton(width: 120, height: 16),
                const SizedBox(height: 8),
                PremiumSkeleton(width: 80, height: 12),
              ],
            ),
          ),
          PremiumSkeleton(width: 60, height: 16),
        ],
      ),
    );
  }
}

class _HeroCard extends PremiumSkeleton {
  const _HeroCard() : super(width: double.infinity, height: 200);

  @override
  State<PremiumSkeleton> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<PremiumThemeExtension>()!;
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: p.glassSurfaceHero,
        border: Border.all(color: p.glassBorder),
        borderRadius: BorderRadius.circular(20.0),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               PremiumSkeleton(width: 100, height: 16),
               PremiumSkeleton(width: 150, height: 16),
            ],
          ),
          const SizedBox(height: 24),
          PremiumSkeleton(width: 200, height: 48),
          const Spacer(),
          PremiumSkeleton(width: double.infinity, height: 64),
        ],
      ),
    );
  }
}
