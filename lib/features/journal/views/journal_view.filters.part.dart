part of 'journal_view.dart';

class _JournalFilterBar extends ConsumerWidget {
  final bool isMobile;
  const _JournalFilterBar({required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(journalFiltersProvider);
    final columnFilters = ref.watch(journalColumnFiltersProvider);
    final now = DateTime.now();
    final defaultFocusMonth = filters.year == now.year ? now.month : 1;
    final monthLabel = filters.month != null
        ? AppStrings.common.monthsFull[filters.month! - 1]
        : AppStrings.journal.currentMonthLabel(AppStrings.common.monthsFull[defaultFocusMonth - 1]);
    final dateLabel = _dateFilterLabel(columnFilters);
    final textLabel = columnFilters.label.trim().isEmpty
        ? AppStrings.journal.allLabels
        : AppStrings.journal.labelFilter(columnFilters.label.trim());
    final amountLabel = _amountFilterLabel(columnFilters);
    final activeCount = _activeColumnFiltersCount(columnFilters);
    final accountsAsync = ref.watch(accountsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: const BoxDecoration(
        color: AppColors.surfaceTableHeader,
        border: Border(bottom: BorderSide(color: AppColors.borderTable)),
      ),
      child: isMobile
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    icon: Icons.calendar_today,
                    label: '${filters.year}',
                    onTap: () => _pickYear(context, ref, filters),
                  ),
                  _FilterChip(
                    icon: Icons.date_range,
                    label: monthLabel,
                    onTap: () => _pickMonth(context, ref, filters),
                  ),
                  accountsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (accounts) {
                      final selected = filters.accountId == null
                          ? null
                          : accounts
                                .where((a) => a.id == filters.accountId)
                                .firstOrNull;
                      return _FilterChip(
                        icon: Icons.account_balance_wallet,
                        label: selected?.name ?? AppStrings.journal.allAccounts,
                        onTap: () =>
                            _pickAccount(context, ref, filters, accounts),
                      );
                    },
                  ),
                  _FilterChip(
                    icon: Icons.fact_check_outlined,
                    label: _statusFilterLabel(filters.status),
                    onTap: () => _pickStatus(context, ref, filters),
                  ),
                  _FilterChip(
                    icon: Icons.event,
                    label: dateLabel,
                    onTap: () => _pickDateRange(context, ref, columnFilters),
                  ),
                  _FilterChip(
                    icon: Icons.label_outline,
                    label: textLabel,
                    onTap: () => _pickLabel(context, ref, columnFilters),
                  ),
                  _FilterChip(
                    icon: Icons.tune,
                    label: amountLabel,
                    onTap: () => _pickAmount(context, ref, columnFilters),
                  ),
                  if (columnFilters.hasActiveFilters)
                    _FilterChip(
                      icon: Icons.filter_alt_off_outlined,
                      label: AppStrings.journal.resetLabel,
                      showChevron: false,
                      onTap: () => _clearColumnFilters(ref),
                    ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  _FilterChip(
                    icon: Icons.calendar_today,
                    label: '${filters.year}',
                    onTap: () => _pickYear(context, ref, filters),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    icon: Icons.date_range,
                    label: monthLabel,
                    onTap: () => _pickMonth(context, ref, filters),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    icon: Icons.fact_check_outlined,
                    label: _statusFilterLabel(filters.status),
                    onTap: () => _pickStatus(context, ref, filters),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    icon: filters.hideVoided
                        ? Icons.visibility_off
                        : Icons.visibility_outlined,
                    label: filters.hideVoided
                        ? AppStrings.journal.showVoidedLabel
                        : AppStrings.journal.hideVoidedLabel,
                    onTap: () => ref
                        .read(journalFiltersProvider.notifier)
                        .state = filters.copyWith(hideVoided: !filters.hideVoided),
                  ),
                  const SizedBox(width: 8),
                  _FilterIconButton(
                    activeCount:
                        activeCount + (filters.accountId != null ? 1 : 0),
                    onTap: () => _openFilterDialog(
                      context,
                      ref,
                      filters,
                      columnFilters,
                      accountsAsync,
                    ),
                  ),
                  if (columnFilters.hasActiveFilters ||
                      filters.accountId != null) ...[
                    const SizedBox(width: 8),
                    _FilterChip(
                      icon: Icons.filter_alt_off_outlined,
                      label: AppStrings.journal.resetLabel,
                      showChevron: false,
                      onTap: () {
                        _clearColumnFilters(ref);
                        ref.read(journalFiltersProvider.notifier).state =
                            filters.copyWith(accountId: null);
                      },
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _pickYear(
    BuildContext context,
    WidgetRef ref,
    JournalFilters filters,
  ) async {
    final now = DateTime.now();
    final selectedYear = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          AppStrings.journal.yearPickerTitle,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        children: List.generate(6, (i) {
          final year = now.year - i;
          return SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(year),
            child: Text(
              '$year',
              style: TextStyle(
                color: year == filters.year
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
            ),
          );
        }),
      ),
    );
    if (selectedYear == null) return;
    ref.read(journalFiltersProvider.notifier).state = filters.copyWith(
      year: selectedYear,
      month: null,
    );
  }

  Future<void> _pickMonth(
    BuildContext context,
    WidgetRef ref,
    JournalFilters filters,
  ) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          AppStrings.journal.monthPickerTitle,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(0),
            child: Text(
              AppStrings.journal.currentMonth,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
          ...List.generate(12, (index) {
            final month = index + 1;
            return SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(month),
              child: Text(
                AppStrings.common.monthsFull[month - 1],
                style: TextStyle(
                  color: month == filters.month
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
            );
          }),
        ],
      ),
    );
    if (selected == null) return;
    if (selected == 0) {
      ref.read(journalFiltersProvider.notifier).state = filters.copyWith(
        month: null,
      );
      return;
    }
    ref.read(journalFiltersProvider.notifier).state = filters.copyWith(
      month: selected,
    );
  }

  Future<void> _pickAccount(
    BuildContext context,
    WidgetRef ref,
    JournalFilters filters,
    List accounts,
  ) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          AppStrings.journal.accountPickerTitle,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('__all__'),
            child: Text(
              AppStrings.journal.all,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
          ...accounts.map((a) {
            return SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(a.id as String),
              child: Text(
                a.name,
                style: TextStyle(
                  color: a.id == filters.accountId
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
            );
          }),
        ],
      ),
    );
    if (selected == null) return;
    ref.read(journalFiltersProvider.notifier).state = filters.copyWith(
      accountId: selected == '__all__' ? null : selected,
    );
  }

  Future<void> _pickStatus(
    BuildContext context,
    WidgetRef ref,
    JournalFilters filters,
  ) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          AppStrings.journal.statusPickerTitle,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('__all__'),
            child: Text(
              AppStrings.journal.allStatuses,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('pending'),
            child: Text(
              AppStrings.journal.filterToPay,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('completed'),
            child: Text(
              AppStrings.journal.filterPaidPlural,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
    if (selected == null) return;
    ref.read(journalFiltersProvider.notifier).state = filters.copyWith(
      status: selected == '__all__' ? null : selected,
    );
  }

  String _statusFilterLabel(String? status) {
    if (status == 'pending') return AppStrings.journal.filterToPay;
    if (status == 'completed') return AppStrings.journal.filterPaidPlural;
    return AppStrings.journal.allStatuses;
  }

  String _dateFilterLabel(JournalColumnFilters filters) {
    final fmt = DateFormat('dd/MM/yyyy');
    final from = filters.fromDate;
    final to = filters.toDate;
    if (from == null && to == null) return AppStrings.journal.allDates;
    if (from != null && to != null) {
      if (_sameDay(from, to)) return AppStrings.journal.dateExact(fmt.format(from));
      return AppStrings.journal.dateRange(fmt.format(from), fmt.format(to));
    }
    if (from != null) return AppStrings.journal.dateFrom(fmt.format(from));
    return AppStrings.journal.dateTo(fmt.format(to!));
  }

  String _amountFilterLabel(JournalColumnFilters filters) {
    final min = filters.minAmount;
    final max = filters.maxAmount;
    if (min == null && max == null) return AppStrings.journal.allAmounts;
    if (min != null && max != null) {
      return '${AppFormats.formatFromChf(min)} - ${AppFormats.formatFromChf(max)}';
    }
    if (min != null) return AppStrings.journal.amountMin(AppFormats.formatFromChf(min));
    return AppStrings.journal.amountMax(AppFormats.formatFromChf(max!));
  }

  int _activeColumnFiltersCount(JournalColumnFilters filters) {
    var count = 0;
    if (filters.fromDate != null || filters.toDate != null) count++;
    if (filters.label.trim().isNotEmpty) count++;
    if (filters.minAmount != null || filters.maxAmount != null) count++;
    return count;
  }

  Future<void> _pickDateRange(
    BuildContext context,
    WidgetRef ref,
    JournalColumnFilters filters,
  ) async {
    final picked = await showDialog<List<DateTime?>>(
      context: context,
      builder: (dialogContext) {
        var from = filters.fromDate;
        var to = filters.toDate;
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            title: Text(
              AppStrings.journal.filterByDate,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DateFilterInput(
                    label: AppStrings.journal.dateMin,
                    date: from,
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: from ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (selected == null) return;
                      setLocalState(() => from = selected);
                    },
                    onClear: () => setLocalState(() => from = null),
                  ),
                  const SizedBox(height: 10),
                  _DateFilterInput(
                    label: AppStrings.journal.dateMax,
                    date: to,
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: to ?? (from ?? DateTime.now()),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (selected == null) return;
                      setLocalState(() => to = selected);
                    },
                    onClear: () => setLocalState(() => to = null),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  AppStrings.common.cancel,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(<DateTime?>[]),
                child: Text(
                  AppStrings.journal.clearFilter,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(<DateTime?>[from, to]),
                child: Text(AppStrings.journal.applyFilter),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    DateTime? from;
    DateTime? to;
    if (picked.isNotEmpty) {
      from = picked[0];
      to = picked.length > 1 ? picked[1] : null;
    }
    if (from != null && to != null && to.isBefore(from)) {
      final temp = from;
      from = to;
      to = temp;
    }
    ref.read(journalColumnFiltersProvider.notifier).state = filters.copyWith(
      fromDate: from,
      toDate: to,
    );
  }

  Future<void> _pickLabel(
    BuildContext context,
    WidgetRef ref,
    JournalColumnFilters filters,
  ) async {
    final controller = TextEditingController(text: filters.label);
    final next = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          AppStrings.journal.filterByLabel,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(labelText: AppStrings.journal.labelContains),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              AppStrings.common.cancel,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(''),
            child: Text(
              AppStrings.journal.clearFilter,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(AppStrings.journal.applyFilter),
          ),
        ],
      ),
    );
    controller.dispose();
    if (next == null) return;
    ref.read(journalColumnFiltersProvider.notifier).state = filters.copyWith(
      label: next,
    );
  }

  Future<void> _pickAmount(
    BuildContext context,
    WidgetRef ref,
    JournalColumnFilters filters,
  ) async {
    final minCtrl = TextEditingController(
      text: filters.minAmount?.toStringAsFixed(2) ?? '',
    );
    final maxCtrl = TextEditingController(
      text: filters.maxAmount?.toStringAsFixed(2) ?? '',
    );
    final picked = await showDialog<List<double?>>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            title: Text(
              AppStrings.journal.filterByAmount,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: minCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(labelText: AppStrings.journal.amountMinLabel),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: maxCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(labelText: AppStrings.journal.amountMaxLabel),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  AppStrings.common.cancel,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(<double?>[]),
                child: Text(
                  AppStrings.journal.clearFilter,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final min = _parseAmount(minCtrl.text);
                  final max = _parseAmount(maxCtrl.text);
                  final minInvalid =
                      minCtrl.text.trim().isNotEmpty && min == null;
                  final maxInvalid =
                      maxCtrl.text.trim().isNotEmpty && max == null;
                  if (minInvalid || maxInvalid) {
                    setLocalState(() => error = AppStrings.journal.invalidAmount);
                    return;
                  }
                  if (min != null && max != null && max < min) {
                    setLocalState(() => error = AppStrings.journal.amountMaxLtMin);
                    return;
                  }
                  Navigator.of(dialogContext).pop(<double?>[min, max]);
                },
                child: Text(AppStrings.journal.applyFilter),
              ),
            ],
          ),
        );
      },
    );
    minCtrl.dispose();
    maxCtrl.dispose();
    if (picked == null) return;
    final min = picked.isNotEmpty ? picked[0] : null;
    final max = picked.length > 1 ? picked[1] : null;
    ref.read(journalColumnFiltersProvider.notifier).state = filters.copyWith(
      minAmount: picked.isEmpty ? null : min,
      maxAmount: picked.isEmpty ? null : max,
    );
  }

  void _clearColumnFilters(WidgetRef ref) {
    ref.read(journalColumnFiltersProvider.notifier).state =
        const JournalColumnFilters();
  }

  Future<void> _openFilterDialog(
    BuildContext context,
    WidgetRef ref,
    JournalFilters filters,
    JournalColumnFilters columnFilters,
    AsyncValue<List<dynamic>> accountsAsync,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _FilterDialog(
          filters: filters,
          columnFilters: columnFilters,
          accountsAsync: accountsAsync,
          onApply:
              ({
                String? accountId,
                bool clearAccount = false,
                DateTime? fromDate,
                DateTime? toDate,
                bool clearDates = false,
                String? label,
                double? minAmount,
                double? maxAmount,
                bool clearAmounts = false,
              }) {
                // Update account filter
                if (clearAccount) {
                  ref.read(journalFiltersProvider.notifier).state = filters
                      .copyWith(accountId: null);
                } else if (accountId != null) {
                  ref.read(journalFiltersProvider.notifier).state = filters
                      .copyWith(accountId: accountId);
                }

                // Update column filters
                var newCol = columnFilters;
                if (clearDates) {
                  newCol = newCol.copyWith(fromDate: null, toDate: null);
                } else {
                  if (fromDate != null || toDate != null) {
                    newCol = newCol.copyWith(
                      fromDate: fromDate ?? columnFilters.fromDate,
                      toDate: toDate ?? columnFilters.toDate,
                    );
                  }
                }
                if (label != null) {
                  newCol = newCol.copyWith(label: label);
                }
                if (clearAmounts) {
                  newCol = newCol.copyWith(minAmount: null, maxAmount: null);
                } else {
                  if (minAmount != null || maxAmount != null) {
                    newCol = newCol.copyWith(
                      minAmount: minAmount ?? columnFilters.minAmount,
                      maxAmount: maxAmount ?? columnFilters.maxAmount,
                    );
                  }
                }
                ref.read(journalColumnFiltersProvider.notifier).state = newCol;
              },
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double? _parseAmount(String input) {
    final raw = input.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }
}

class _DateFilterInput extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateFilterInput({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.r10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.r10),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date == null ? label : '$label: ${fmt.format(date!)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (date != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.clear, size: 16),
                color: AppColors.textDisabled,
                splashRadius: 16,
                tooltip: AppStrings.journal.clearFilterTooltip,
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showChevron;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark ? const Color(0xFF1E2A1A) : Colors.white;
    final labelColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: chipBg,
          border: Border.all(color: AppColors.borderInputStrong),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (showChevron) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.expand_more,
                size: 14,
                color: AppColors.textDisabled,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;

  const _FilterIconButton({required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveBg = isDark ? const Color(0xFF1E2A1A) : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: activeCount > 0 ? AppColors.primary.withAlpha(18) : inactiveBg,
          border: Border.all(
            color: activeCount > 0
                ? AppColors.primary.withAlpha(80)
                : AppColors.borderInputStrong,
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune,
              size: 16,
              color: activeCount > 0
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            if (activeCount > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$activeCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterDialog extends StatefulWidget {
  final JournalFilters filters;
  final JournalColumnFilters columnFilters;
  final AsyncValue<List<dynamic>> accountsAsync;
  final void Function({
    String? accountId,
    bool clearAccount,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearDates,
    String? label,
    double? minAmount,
    double? maxAmount,
    bool clearAmounts,
  })
  onApply;

  const _FilterDialog({
    required this.filters,
    required this.columnFilters,
    required this.accountsAsync,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late String? _accountId;
  late DateTime? _fromDate;
  late DateTime? _toDate;
  late TextEditingController _labelCtrl;
  late TextEditingController _minCtrl;
  late TextEditingController _maxCtrl;

  @override
  void initState() {
    super.initState();
    _accountId = widget.filters.accountId;
    _fromDate = widget.columnFilters.fromDate;
    _toDate = widget.columnFilters.toDate;
    _labelCtrl = TextEditingController(text: widget.columnFilters.label);
    _minCtrl = TextEditingController(
      text: widget.columnFilters.minAmount?.toStringAsFixed(2) ?? '',
    );
    _maxCtrl = TextEditingController(
      text: widget.columnFilters.maxAmount?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  double? _parseAmount(String input) {
    final raw = input.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.accountsAsync.valueOrNull ?? [];

    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(
        AppStrings.journal.advancedFilters,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Account
              Text(
                AppStrings.journal.accountPickerTitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
                hint: Text(
                  AppStrings.journal.allAccounts,
                  style: const TextStyle(fontSize: 13),
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(AppStrings.journal.allAccounts),
                  ),
                  ...accounts.map(
                    (a) => DropdownMenuItem<String>(
                      value: a.id as String,
                      child: Text(a.name as String),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 16),

              // Date range
              Text(
                AppStrings.journal.dateRangeLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _DateFilterInput(
                      label: AppStrings.journal.dateMin,
                      date: _fromDate,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _fromDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (d != null) setState(() => _fromDate = d);
                      },
                      onClear: () => setState(() => _fromDate = null),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateFilterInput(
                      label: AppStrings.journal.dateMax,
                      date: _toDate,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _toDate ?? (_fromDate ?? DateTime.now()),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (d != null) setState(() => _toDate = d);
                      },
                      onClear: () => setState(() => _toDate = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Label
              Text(
                AppStrings.journal.labelFieldLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _labelCtrl,
                maxLength: 80,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: AppStrings.journal.labelContains,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Amount range
              Text(
                AppStrings.journal.amountFieldLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: AppStrings.journal.amountMinHint,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: const BorderSide(
                            color: AppColors.borderSubtle,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: const BorderSide(
                            color: AppColors.borderSubtle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '-',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _maxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: AppStrings.journal.amountMaxHint,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: const BorderSide(
                            color: AppColors.borderSubtle,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: const BorderSide(
                            color: AppColors.borderSubtle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            AppStrings.common.cancel,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            // Clear all
            widget.onApply(
              clearAccount: true,
              clearDates: true,
              label: '',
              clearAmounts: true,
            );
            Navigator.of(context).pop();
          },
          child: Text(
            AppStrings.journal.clearAll,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(
              accountId: _accountId,
              clearAccount:
                  _accountId == null && widget.filters.accountId != null,
              fromDate: _fromDate,
              toDate: _toDate,
              clearDates: _fromDate == null && _toDate == null,
              label: _labelCtrl.text.trim(),
              minAmount: _parseAmount(_minCtrl.text),
              maxAmount: _parseAmount(_maxCtrl.text),
              clearAmounts:
                  _minCtrl.text.trim().isEmpty && _maxCtrl.text.trim().isEmpty,
            );
            Navigator.of(context).pop();
          },
          child: Text(AppStrings.journal.applyFilter),
        ),
      ],
    );
  }
}

