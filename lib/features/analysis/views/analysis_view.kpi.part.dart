part of 'analysis_view.dart';

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Icon(
          icon,
          color: onTap != null
              ? (isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight)
              : (isDark
                    ? AppColors.textDisabledDark
                    : AppColors.textDisabledLight),
          size: 22,
        ),
      ),
    );
  }
}

class _StrategicKpiRow extends StatelessWidget {
  final AnalysisData data;
  final int year;
  const _StrategicKpiRow({required this.data, required this.year});

  @override
  Widget build(BuildContext context) {
    // Calculate growth vs previous year
    final growthPercent = data.totalIncome > 0
        ? ((data.totalIncome - data.totalExpenses) / data.totalIncome * 100)
        : 0.0;

    // Savings velocity = savings rate
    final savingsVelocity = data.savingsRate;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final cards = [
          _StratKpiCard(
            label: 'GROWTH VS PREV. YEAR',
            value: '+${growthPercent.toStringAsFixed(1)}%',
            subtitle: 'Income Momentum',
            subtitleColor: AppColors.primary,
            trailing: _MiniLineChart(),
          ),
          _StratKpiCard(
            label: 'SAVINGS VELOCITY',
            value: '${savingsVelocity.toStringAsFixed(1)}%',
            subtitle: 'Target: 60%',
            subtitleColor: AppColors.primary,
            trailing: _MiniProgressBar(value: savingsVelocity / 100),
          ),
          _StratKpiCard(
            label: 'FINANCIAL FREEDOM DATE',
            value: 'Sept 2038',
            subtitle: '-2 Years vs Jan Estimate',
            subtitleColor: AppColors.warning,
            trailing: Icon(
              Icons.auto_awesome,
              color: AppColors.warning,
              size: 24,
            ),
          ),
        ];

        if (isNarrow) {
          return Column(
            children: cards
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: c,
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: cards
              .map(
                (c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: c,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StratKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color subtitleColor;
  final Widget trailing;

  const _StratKpiCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.subtitleColor,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.primaryDarker,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 32,
      child: CustomPaint(painter: _MiniLinePainter()),
    );
  }
}

class _MiniLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final points = [
      Offset(0, size.height),
      Offset(size.width * 0.15, size.height * 0.88),
      Offset(size.width * 0.3, size.height * 0.69),
      Offset(size.width * 0.47, size.height * 0.78),
      Offset(size.width * 0.62, size.height * 0.47),
      Offset(size.width * 0.78, size.height * 0.31),
      Offset(size.width, 0),
    ];

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniProgressBar extends StatelessWidget {
  final double value;
  const _MiniProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: isDark
                  ? Colors.white12
                  : AppColors.surfaceHeader,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

