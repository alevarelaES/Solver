part of 'budget_view.dart';

class _CardsLayout extends StatelessWidget {
  final String inputVersion;
  final List<_RenderedGroup> rows;
  final void Function(_RenderedGroup row, String mode) onModeChanged;
  final void Function(_RenderedGroup row, String value) onValueChanged;

  const _CardsLayout({
    required this.inputVersion,
    required this.rows,
    required this.onModeChanged,
    required this.onValueChanged,
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

  const _ListLayout({
    required this.inputVersion,
    required this.rows,
    required this.onModeChanged,
    required this.onValueChanged,
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

  const _GroupCard({
    required this.inputVersion,
    required this.row,
    required this.onModeChanged,
    required this.onValueChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasEnvelope = row.plannedAmount > 0.0001;
    final paidAmount = row.group.spentActual;
    final pendingAmount = row.group.pendingAmount;
    final committedAmount = paidAmount + pendingAmount;
    final usagePct = hasEnvelope
        ? (committedAmount / row.plannedAmount) * 100
        : 0.0;
    final overUsage = hasEnvelope && committedAmount > row.plannedAmount;
    final overflowAmount = hasEnvelope
        ? (committedAmount > row.plannedAmount
              ? committedAmount - row.plannedAmount
              : 0.0)
        : committedAmount;
    final lockedByCommitted =
        row.minAllowedAmount > 0 &&
        row.plannedAmount <= row.minAllowedAmount + 0.0001;
    final paidRatio = hasEnvelope
        ? (paidAmount / row.plannedAmount).clamp(0.0, 1.0)
        : 0.0;
    final pendingRatio = hasEnvelope
        ? (pendingAmount / row.plannedAmount).clamp(0.0, 1.0 - paidRatio)
        : 0.0;
    final freeRatio = hasEnvelope
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

    return AppPanel(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 12 : 14,
      ),
      radius: AppRadius.r16,
      borderColor: AppColors.borderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.group.groupName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppStrings.budget.paidLabel(
                      AppFormats.formatFromChfCompact(paidAmount),
                    ),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  if (pendingAmount > 0)
                    Text(
                      AppStrings.budget.pendingLabel(
                        AppFormats.formatFromChfCompact(pendingAmount),
                      ),
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            AppStrings.budget.categoriesInfo(
              row.group.categories.length,
              row.group.isFixedGroup,
            ),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ChoiceChip(
                label: const Text('%'),
                selected: row.draft.inputMode == 'percent',
                onSelected: (_) => onModeChanged(row, 'percent'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(AppStrings.budget.amountChipLabel),
                selected: row.draft.inputMode == 'amount',
                onSelected: (_) => onModeChanged(row, 'amount'),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                child: _SyncedNumericField(
                  key: ValueKey(
                    '$inputVersion-${row.group.groupId}-${row.draft.inputMode}',
                  ),
                  valueText: row.draft.inputMode == 'amount'
                      ? _editableInputValue(row.plannedAmount, maxDecimals: 0)
                      : _editableInputValue(row.plannedPercent, maxDecimals: 1),
                  onChanged: (v) => onValueChanged(row, v),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '0',
                    suffixText: row.draft.inputMode == 'amount'
                        ? AppFormats.currencyCode
                        : '%',
                  ),
                ),
              ),
              const Spacer(),
              Text(
                row.draft.inputMode == 'amount'
                    ? '${row.plannedPercent.toStringAsFixed(1)}%'
                    : AppFormats.formatFromChfCompact(row.plannedAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Slider(
            value: sliderValue.toDouble(),
            min: 0,
            max: safeSliderMax,
            onChanged: (value) {
              onValueChanged(
                row,
                row.draft.inputMode == 'amount'
                    ? value.toStringAsFixed(0)
                    : value.toStringAsFixed(1),
              );
            },
          ),
          Row(
            children: [
              Text(
                row.draft.inputMode == 'amount'
                    ? AppFormats.formatFromChfCompact(row.minAllowedAmount)
                    : '${row.minAllowedPercent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textDisabled,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                row.draft.inputMode == 'amount'
                    ? AppFormats.formatFromChfCompact(safeSliderMax)
                    : '${row.maxAllowedPercent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textDisabled,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                !hasEnvelope && committedAmount > 0
                    ? AppStrings.budget.committedThisMonth(
                        AppFormats.formatFromChfCompact(committedAmount),
                      )
                    : !hasEnvelope
                    ? AppStrings.budget.noExpenses
                    : AppStrings.budget.committedPct(
                        usagePct.toStringAsFixed(0),
                      ),
                style: TextStyle(
                  color: overUsage && hasEnvelope
                      ? AppColors.danger
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                !hasEnvelope
                    ? AppStrings.budget.noBudgetPlanned
                    : spentDelta >= 0
                    ? AppStrings.budget.freeRemaining(
                        AppFormats.formatFromChfCompact(spentDelta),
                      )
                    : AppStrings.budget.overdraftEngaged(
                        AppFormats.formatFromChfCompact(-spentDelta),
                      ),
                style: TextStyle(
                  color: hasEnvelope && spentDelta < 0
                      ? AppColors.danger
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (hasEnvelope) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.r8),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (paidRatio > 0)
                      Expanded(
                        flex: ((paidRatio * 1000).round())
                            .clamp(1, 1000)
                            .toInt(),
                        child: const ColoredBox(color: AppColors.danger),
                      ),
                    if (pendingRatio > 0)
                      Expanded(
                        flex: ((pendingRatio * 1000).round())
                            .clamp(1, 1000)
                            .toInt(),
                        child: const ColoredBox(color: AppColors.warning),
                      ),
                    if (freeRatio > 0)
                      Expanded(
                        flex: ((freeRatio * 1000).round())
                            .clamp(1, 1000)
                            .toInt(),
                        child: const ColoredBox(color: AppColors.primary),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                Text(
                  AppStrings.budget.redLabel(
                    AppFormats.formatFromChfCompact(paidAmount),
                  ),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
                Text(
                  AppStrings.budget.yellowLabel(
                    AppFormats.formatFromChfCompact(pendingAmount),
                  ),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
                Text(
                  AppStrings.budget.greenLabel(
                    AppFormats.formatFromChfCompact(
                      spentDelta > 0 ? spentDelta : 0,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
          if (lockedByCommitted) ...[
            const SizedBox(height: 6),
            Text(
              AppStrings.budget.lockedByCommittedMin(
                AppFormats.formatFromChfCompact(row.minAllowedAmount),
              ),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (overflowAmount > 0 && hasEnvelope) ...[
            const SizedBox(height: 4),
            Text(
              AppStrings.budget.overflowEngaged(
                AppFormats.formatFromChfCompact(overflowAmount),
              ),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
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

  const _SyncedNumericField({
    super.key,
    required this.valueText,
    required this.onChanged,
    this.keyboardType = TextInputType.number,
    this.inputFormatters,
    this.decoration,
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

