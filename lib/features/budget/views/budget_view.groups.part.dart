part of 'budget_view.dart';

class _CardsLayout extends StatelessWidget {
  final String inputVersion;
  final List<_RenderedGroup> rows;
  final void Function(_RenderedGroup row, String mode) onModeChanged;
  final void Function(_RenderedGroup row, String value) onValueChanged;
  final void Function(_RenderedGroup row) onToggleLock;

  const _CardsLayout({
    required this.inputVersion,
    required this.rows,
    required this.onModeChanged,
    required this.onValueChanged,
    required this.onToggleLock,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth > 1180 ? 2 : 1;
        const spacing = 14.0;
        final width = (c.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final row in rows)
              SizedBox(
                width: width,
                child: _GroupCard(
                  inputVersion: inputVersion,
                  row: row,
                  onModeChanged: onModeChanged,
                  onValueChanged: onValueChanged,
                  onToggleLock: onToggleLock,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ListLayout extends StatelessWidget {
  final String inputVersion;
  final List<_RenderedGroup> rows;
  final void Function(_RenderedGroup row, String mode) onModeChanged;
  final void Function(_RenderedGroup row, String value) onValueChanged;
  final void Function(_RenderedGroup row) onToggleLock;

  const _ListLayout({
    required this.inputVersion,
    required this.rows,
    required this.onModeChanged,
    required this.onValueChanged,
    required this.onToggleLock,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < rows.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 10),
            child: _GroupCard(
              inputVersion: inputVersion,
              row: rows[i],
              compact: true,
              onModeChanged: onModeChanged,
              onValueChanged: onValueChanged,
              onToggleLock: onToggleLock,
            ),
          ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String inputVersion;
  final _RenderedGroup row;
  final bool compact;
  final void Function(_RenderedGroup row, String mode) onModeChanged;
  final void Function(_RenderedGroup row, String value) onValueChanged;
  final void Function(_RenderedGroup row) onToggleLock;

  const _GroupCard({
    required this.inputVersion,
    required this.row,
    required this.onModeChanged,
    required this.onValueChanged,
    required this.onToggleLock,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final paidAmount = row.group.spentActual;
    final pendingAmount = row.group.pendingAmount;
    final committedAmount = paidAmount + pendingAmount;
    final hasEnvelope = row.plannedAmount > 0.0001 || committedAmount > 0.0001;
    final usagePct = hasEnvelope && row.plannedAmount > 0
        ? (committedAmount / row.plannedAmount) * 100
        : (committedAmount > 0 ? 100.0 : 0.0);
    final overUsage = hasEnvelope && committedAmount > row.plannedAmount;
    final overflowAmount = hasEnvelope
        ? (committedAmount > row.plannedAmount
              ? committedAmount - row.plannedAmount
              : 0.0)
        : committedAmount;
    final paidRatio = hasEnvelope && row.plannedAmount > 0
        ? (paidAmount / row.plannedAmount).clamp(0.0, 1.0)
        : (paidAmount > 0 ? 1.0 : 0.0);
    final pendingRatio = hasEnvelope && row.plannedAmount > 0
        ? (pendingAmount / row.plannedAmount).clamp(0.0, 1.0 - paidRatio)
        : (pendingAmount > 0 ? (1.0 - paidRatio).clamp(0.0, 1.0) : 0.0);
    final freeRatio = hasEnvelope && row.plannedAmount > 0
        ? (1.0 - paidRatio - pendingRatio).clamp(0.0, 1.0)
        : 0.0;
    final spentDelta = row.plannedAmount - committedAmount;
    final sliderMin = row.draft.inputMode == 'amount'
        ? row.minAllowedAmount
        : row.minAllowedPercent;
    final sliderMax = row.draft.inputMode == 'amount'
        ? row.maxAllowedAmount
        : row.maxAllowedPercent;
    final safeSliderMin = sliderMin.toDouble();
    final safeSliderMax =
        (sliderMax <= safeSliderMin ? safeSliderMin + 0.0001 : sliderMax)
            .toDouble();
    final sliderValue =
        (row.draft.inputMode == 'amount'
                ? row.plannedAmount
                : row.plannedPercent)
            .clamp(0, safeSliderMax);

    return PremiumCardBase(
      variant: PremiumCardVariant.standard,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 12 : 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            row.group.groupName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          row.draft.inputMode == 'amount'
                              ? '${row.plannedPercent.toStringAsFixed(1)}%'
                              : AppFormats.formatFromChfCompact(row.plannedAmount),
                          style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary, fontSize: 13),
                        ),
                        if (row.isLocked || overUsage) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: row.isLocked ? 'Objectif dépassé (cliquez pour déverrouiller)' : 'Verrouillé',
                            child: InkWell(
                              onTap: overUsage ? () => onToggleLock(row) : null,
                              borderRadius: BorderRadius.circular(12),
                              child: Icon(
                                row.isLocked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                                size: 16,
                                color: row.isLocked ? AppColors.danger : AppColors.textDisabled,
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.budget.categoriesInfo(row.group.categories.length, row.group.isFixedGroup),
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(AppRadius.r8),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SegmentOption(label: '%', isSelected: row.draft.inputMode == 'percent', onTap: () => onModeChanged(row, 'percent'), isDark: isDark),
                              _SegmentOption(label: AppStrings.budget.amountChipLabel, isSelected: row.draft.inputMode == 'amount', onTap: () => onModeChanged(row, 'amount'), isDark: isDark),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IgnorePointer(
                          ignoring: row.isLocked,
                          child: Container(
                            width: 110,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(AppRadius.r8),
                              border: Border.all(color: row.isLocked ? AppColors.danger : AppColors.borderSubtle),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            child: _SyncedNumericField(
                              key: ValueKey('$inputVersion-${row.group.groupId}-${row.draft.inputMode}'),
                              valueText: row.draft.inputMode == 'amount'
                                  ? _editableInputValue(row.plannedAmount, maxDecimals: 0)
                                  : _editableInputValue(row.plannedPercent, maxDecimals: 1),
                              onChanged: (v) => onValueChanged(row, v),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]'))],
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                isDense: true,
                                hintText: '0',
                                suffixText: row.draft.inputMode == 'amount' ? AppFormats.currencyCode : '%',
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: TextStyle(
                                color: row.isLocked ? AppColors.textDisabled : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (hasEnvelope) ...[
                const SizedBox(width: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (paidAmount > 0)
                          Text('Payé : ${AppFormats.formatFromChfCompact(paidAmount)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.danger)),
                        if (pendingAmount > 0)
                          Text('À payer : ${AppFormats.formatFromChfCompact(pendingAmount)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warning)),
                        const SizedBox(height: 2),
                        Text(
                          'Dispo : ${AppFormats.formatFromChfCompact(spentDelta < 0 ? 0 : spentDelta)}', 
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.w800, 
                            color: spentDelta < 0 ? AppColors.danger : AppColors.success
                          )
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 0,
                          centerSpaceRadius: 16,
                          sections: [
                            if (paidRatio > 0) PieChartSectionData(color: AppColors.danger, value: paidRatio * 100, radius: 6, showTitle: false),
                            if (pendingRatio > 0) PieChartSectionData(color: AppColors.warning, value: pendingRatio * 100, radius: 6, showTitle: false),
                            if (freeRatio > 0) PieChartSectionData(color: AppColors.success, value: freeRatio * 100, radius: 6, showTitle: false),
                            if (paidRatio == 0 && pendingRatio == 0 && freeRatio == 0) PieChartSectionData(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.surfaceInfoSoft, value: 100, radius: 6, showTitle: false),
                          ]
                        )
                      )
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          IgnorePointer(
            ignoring: row.isLocked,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: row.isLocked ? AppColors.borderSubtle : (overUsage ? AppColors.danger : AppColors.primary),
                thumbColor: row.isLocked ? AppColors.textDisabled : (overUsage ? AppColors.danger : AppColors.primary),
              ),
              child: Slider(
                value: sliderValue.toDouble(),
                min: 0,
                max: safeSliderMax,
                onChanged: (value) {
                  onValueChanged(row, row.draft.inputMode == 'amount' ? value.toStringAsFixed(0) : value.toStringAsFixed(1));
                },
              ),
            ),
          ),
          Row(
            children: [
              Text(
                row.draft.inputMode == 'amount' ? AppFormats.formatFromChfCompact(row.minAllowedAmount) : '${row.minAllowedPercent.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 11, color: AppColors.textDisabled, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                row.draft.inputMode == 'amount' ? AppFormats.formatFromChfCompact(safeSliderMax) : '${row.maxAllowedPercent.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 11, color: AppColors.textDisabled, fontWeight: FontWeight.w700),
              ),
            ],
          ),

          if (overflowAmount > 0 && hasEnvelope) ...[
            const SizedBox(height: 4),
            Text(AppStrings.budget.overflowEngaged(AppFormats.formatFromChfCompact(overflowAmount)), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}

class _SyncedNumericField extends StatefulWidget {
  final String valueText;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final InputDecoration? decoration;
  final TextStyle? style;

  const _SyncedNumericField({
    super.key,
    required this.valueText,
    required this.onChanged,
    this.keyboardType = TextInputType.number,
    this.inputFormatters,
    this.decoration,
    this.style,
  });

  @override
  State<_SyncedNumericField> createState() => _SyncedNumericFieldState();
}

class _SyncedNumericFieldState extends State<_SyncedNumericField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.valueText);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _SyncedNumericField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.valueText == _controller.text) return;
    _controller.value = TextEditingValue(
      text: widget.valueText,
      selection: TextSelection.collapsed(offset: widget.valueText.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      decoration: widget.decoration,
      style: widget.style,
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.r10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 19,
          color: isActive ? AppColors.primary : AppColors.textDisabled,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isDark ? color : color,
        ),
      ),
    );
  }
}

class _SegmentOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _SegmentOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.surfaceDark : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.r6),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? AppColors.textPrimary
                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          ),
        ),
      ),
    );
  }
}
