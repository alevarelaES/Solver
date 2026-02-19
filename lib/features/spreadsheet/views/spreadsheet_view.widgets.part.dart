part of 'spreadsheet_view.dart';

class _SpreadsheetHeaderControls extends StatelessWidget {
  final SpreadsheetProjectionMode mode;
  final int year;
  final int currentYear;
  final ValueChanged<SpreadsheetProjectionMode> onModeChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _SpreadsheetHeaderControls({
    required this.mode,
    required this.year,
    required this.currentYear,
    required this.onModeChanged,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceElevated;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _ProjectionModeSwitch(mode: mode, onChanged: onModeChanged),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                iconSize: 18,
                splashRadius: 16,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '$year',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: year == currentYear ? AppColors.primary : textColor,
                ),
              ),
              IconButton(
                iconSize: 18,
                splashRadius: 16,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProjectionModeSwitch extends StatelessWidget {
  final SpreadsheetProjectionMode mode;
  final ValueChanged<SpreadsheetProjectionMode> onChanged;

  const _ProjectionModeSwitch({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : AppColors.surfaceTablePanel;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    Widget chip(String label, SpreadsheetProjectionMode value) {
      final selected = mode == value;
      return InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(AppRadius.r10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? (isDark
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.r10),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected
                  ? AppColors.primary
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chip(AppStrings.spreadsheet.modePrudent, SpreadsheetProjectionMode.prudent),
          chip(AppStrings.spreadsheet.modePrevision, SpreadsheetProjectionMode.prevision),
        ],
      ),
    );
  }
}

class _ProjectionHint extends StatelessWidget {
  final SpreadsheetProjectionMode mode;
  final bool isDark;
  final Color borderColor;

  const _ProjectionHint({
    required this.mode,
    required this.isDark,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final text = mode == SpreadsheetProjectionMode.prudent
        ? AppStrings.spreadsheet.hintPrudent
        : AppStrings.spreadsheet.hintPrevision;

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : AppColors.surfaceMuted,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textMutedStrong,
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  final Alignment alignment;
  final bool isDark;
  final Color borderColor;
  final bool isPrimary;
  final bool isActive;
  final bool ascending;
  final VoidCallback? onTap;
  final Color? cellColor;

  const _HeaderCell({
    required this.text,
    required this.width,
    required this.isDark,
    required this.borderColor,
    this.alignment = Alignment.centerRight,
    this.isPrimary = false,
    this.isActive = false,
    this.ascending = true,
    this.onTap,
    this.cellColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isPrimary
        ? AppColors.primary
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: alignment,
        decoration: BoxDecoration(
          color:
              cellColor ??
              (isPrimary
                  ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.05)
                  : null),
          border: Border(
            right: BorderSide(color: borderColor.withValues(alpha: 0.6)),
          ),
        ),
        child: Row(
          mainAxisAlignment: _resolveMainAxisAlignment(alignment),
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
                color: fg,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 4),
            if (isActive)
              Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: fg,
              )
            else
              Icon(
                Icons.unfold_more,
                size: 12,
                color: fg.withValues(alpha: 0.55),
              ),
          ],
        ),
      ),
    );
  }

  MainAxisAlignment _resolveMainAxisAlignment(Alignment alignment) {
    if (alignment == Alignment.centerLeft) return MainAxisAlignment.start;
    if (alignment == Alignment.center) return MainAxisAlignment.center;
    return MainAxisAlignment.end;
  }
}

class _SectionHeaderRow extends StatelessWidget {
  final String label;
  final Color color;
  final double catWidth;
  final Color borderColor;
  final Color bgColor;

  const _SectionHeaderRow({
    required this.label,
    required this.color,
    required this.catWidth,
    required this.borderColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Container(
            width: catWidth,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final SpreadsheetRow row;
  final SpreadsheetProjectionMode mode;
  final int rowIndex;
  final bool isDark;
  final double catWidth;
  final double cellWidth;
  final double totalWidth;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final Color totalColBg;
  final Color Function(int monthIndex) monthCellColor;

  const _DataRow({
    required this.row,
    required this.mode,
    required this.rowIndex,
    required this.isDark,
    required this.catWidth,
    required this.cellWidth,
    required this.totalWidth,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
    required this.totalColBg,
    required this.monthCellColor,
  });

  @override
  Widget build(BuildContext context) {
    final baseRowColor = rowIndex.isEven
        ? (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white)
        : (isDark
              ? Colors.white.withValues(alpha: 0.045)
              : AppColors.surfaceTableRowAlt);
    final categoryCellColor = rowIndex.isEven
        ? (isDark
              ? Colors.white.withValues(alpha: 0.035)
              : AppColors.surfaceMuted)
        : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.surfaceTableRowAccent);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: baseRowColor,
        border: Border(
          bottom: BorderSide(color: borderColor.withValues(alpha: 0.8)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: catWidth,
            padding: const EdgeInsets.only(left: 36, right: 12),
            decoration: BoxDecoration(
              color: categoryCellColor,
              border: Border(
                right: BorderSide(color: borderColor.withValues(alpha: 0.95)),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              row.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          ...List.generate(12, (monthIndex) {
            final value = row.monthValue(monthIndex, mode);
            final isEstimated = row.monthUsesEstimate(monthIndex, mode);
            final display = _formatSignedAmount(
              value,
              isIncome: row.isIncome,
              isEstimated: isEstimated,
            );
            final cellColor = value == 0
                ? mutedColor.withValues(alpha: 0.9)
                : (isEstimated
                      ? AppColors.warningStrong
                      : (row.isIncome
                            ? (isDark
                                  ? AppColors.primary
                                  : AppColors.primaryDarker)
                            : AppColors.danger));
            return Container(
              width: cellWidth,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  monthCellColor(monthIndex),
                  baseRowColor,
                ),
                border: Border(
                  right: BorderSide(color: borderColor.withValues(alpha: 0.65)),
                ),
              ),
              child: Text(
                display,
                style: GoogleFonts.robotoMono(
                  fontSize: 13,
                  color: cellColor,
                  fontWeight: value == 0 ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
            );
          }),
          Container(
            width: totalWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: totalColBg,
            alignment: Alignment.centerRight,
            child: Text(
              _formatSignedAmount(
                row.totalFor(mode),
                isIncome: row.isIncome,
                isEstimated: row.totalUsesEstimate(mode),
              ),
              style: GoogleFonts.robotoMono(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: row.totalUsesEstimate(mode)
                    ? AppColors.warningStrong
                    : (row.isIncome
                          ? (isDark
                                ? AppColors.primary
                                : AppColors.primaryDarker)
                          : AppColors.danger),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final List<double> totals;
  final double grandTotal;
  final double catWidth;
  final double cellWidth;
  final double totalWidth;
  final Color borderColor;
  final bool isDark;
  final bool isIncome;
  final Color Function(int monthIndex) monthCellColor;

  const _TotalRow({
    required this.label,
    required this.totals,
    required this.grandTotal,
    required this.catWidth,
    required this.cellWidth,
    required this.totalWidth,
    required this.borderColor,
    required this.isDark,
    required this.isIncome,
    required this.monthCellColor,
  });

  @override
  Widget build(BuildContext context) {
    final base = isIncome ? AppColors.primary : AppColors.danger;
    final bg = base.withValues(alpha: isDark ? 0.28 : 0.18);
    final textColor = isDark
        ? Colors.white
        : (isIncome ? AppColors.primaryDarker : AppColors.danger);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: base.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Container(
            width: catWidth,
            padding: const EdgeInsets.only(left: 36, right: 12),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: base.withValues(alpha: 0.35)),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
          ...List.generate(12, (monthIndex) {
            return Container(
              width: cellWidth,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  monthCellColor(monthIndex).withValues(alpha: 0.5),
                  bg,
                ),
                border: Border(
                  right: BorderSide(color: base.withValues(alpha: 0.25)),
                ),
              ),
              child: Text(
                _formatSignedAmount(totals[monthIndex], isIncome: isIncome),
                style: GoogleFonts.robotoMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            );
          }),
          Container(
            width: totalWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerRight,
            color: base.withValues(alpha: isDark ? 0.42 : 0.26),
            child: Text(
              _formatSignedAmount(grandTotal, isIncome: isIncome),
              style: GoogleFonts.robotoMono(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetCashFlowRow extends StatelessWidget {
  final List<double> monthValues;
  final double grandTotal;
  final double catWidth;
  final double cellWidth;
  final double totalWidth;

  const _NetCashFlowRow({
    required this.monthValues,
    required this.grandTotal,
    required this.catWidth,
    required this.cellWidth,
    required this.totalWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(color: AppColors.primaryDarker),
      child: Row(
        children: [
          Container(
            width: catWidth,
            padding: const EdgeInsets.only(left: 16, right: 12),
            alignment: Alignment.centerLeft,
            child: Text(
              AppStrings.spreadsheet.netCashFlow,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          ...List.generate(12, (m) {
            return Container(
              width: cellWidth,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: Text(
                _formatSignedNet(monthValues[m]),
                style: GoogleFonts.robotoMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: monthValues[m] < 0
                      ? AppColors.dangerTint
                      : AppColors.successTint,
                ),
              ),
            );
          }),
          Container(
            width: totalWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerRight,
            color: AppColors.primary,
            child: Text(
              _formatSignedNet(grandTotal),
              style: GoogleFonts.robotoMono(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: grandTotal < 0
                    ? AppColors.dangerTint
                    : AppColors.successTintSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedSectionCell extends StatelessWidget {
  final String label;
  final Color color;
  final Color borderColor;
  final Color bgColor;

  const _PinnedSectionCell({
    required this.label,
    required this.color,
    required this.borderColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedDataCell extends StatelessWidget {
  final String label;
  final int rowIndex;
  final bool isDark;
  final Color borderColor;
  final Color textColor;

  const _PinnedDataCell({
    required this.label,
    required this.rowIndex,
    required this.isDark,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final baseRowColor = rowIndex.isEven
        ? (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white)
        : (isDark
              ? Colors.white.withValues(alpha: 0.045)
              : AppColors.surfaceTableRowAlt);
    final categoryCellColor = rowIndex.isEven
        ? (isDark
              ? Colors.white.withValues(alpha: 0.035)
              : AppColors.surfaceMuted)
        : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.surfaceTableRowAccent);

    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 36, right: 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(categoryCellColor, baseRowColor),
        border: Border(
          bottom: BorderSide(color: borderColor.withValues(alpha: 0.8)),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _PinnedTotalCell extends StatelessWidget {
  final String label;
  final Color borderColor;
  final bool isDark;
  final bool isIncome;

  const _PinnedTotalCell({
    required this.label,
    required this.borderColor,
    required this.isDark,
    required this.isIncome,
  });

  @override
  Widget build(BuildContext context) {
    final base = isIncome ? AppColors.primary : AppColors.danger;
    final bg = base.withValues(alpha: isDark ? 0.26 : 0.16);
    final textColor = isDark ? Colors.white : base;

    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 36, right: 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: base.withValues(alpha: 0.3))),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _PinnedNetCell extends StatelessWidget {
  const _PinnedNetCell();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 16, right: 12),
      color: AppColors.primaryDarker,
      alignment: Alignment.centerLeft,
      child: Text(
        'NET CASH FLOW',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
