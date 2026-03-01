part of 'budget_view.dart';

class _GroupDraft {
  final String inputMode; // percent | amount
  final double percent;
  final double amount;
  final int priority;

  const _GroupDraft({
    required this.inputMode,
    required this.percent,
    required this.amount,
    required this.priority,
  });

  _GroupDraft copyWith({
    String? inputMode,
    double? percent,
    double? amount,
    int? priority,
  }) {
    return _GroupDraft(
      inputMode: inputMode ?? this.inputMode,
      percent: percent ?? this.percent,
      amount: amount ?? this.amount,
      priority: priority ?? this.priority,
    );
  }
}

class _RenderedGroup {
  final BudgetPlanGroup group;
  final _GroupDraft draft;
  final double plannedPercent;
  final double plannedAmount;
  final double minAllowedPercent;
  final double minAllowedAmount;
  final double maxAllowedPercent;
  final double maxAllowedAmount;
  final bool isLocked;

  const _RenderedGroup({
    required this.group,
    required this.draft,
    required this.plannedPercent,
    required this.plannedAmount,
    required this.minAllowedPercent,
    required this.minAllowedAmount,
    required this.maxAllowedPercent,
    required this.maxAllowedAmount,
    required this.isLocked,
  });
}

class _PlanTotals {
  final double manualPercent;
  final double manualAmount;
  final double manualCapacityPercent;
  final double manualCapacityAmount;
  final double autoPercent;
  final double autoAmount;
  final double totalPercent;
  final double totalAmount;
  final double remainingPercent;
  final double remainingAmount;

  const _PlanTotals({
    required this.manualPercent,
    required this.manualAmount,
    required this.manualCapacityPercent,
    required this.manualCapacityAmount,
    required this.autoPercent,
    required this.autoAmount,
    required this.totalPercent,
    required this.totalAmount,
    required this.remainingPercent,
    required this.remainingAmount,
  });

  bool get overLimit => manualPercent > manualCapacityPercent + 0.0001;
}

DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
DateTime _shiftMonth(DateTime d, int delta) =>
    DateTime(d.year, d.month + delta, 1);

double _parseNumber(String raw) =>
    double.tryParse(raw.replaceAll(' ', '').replaceAll(',', '.')) ?? 0.0;

String _editableInputValue(double value, {int maxDecimals = 1}) {
  if (value.abs() < 0.000001) return '';
  if (maxDecimals <= 0) {
    return value.toStringAsFixed(0);
  }
  final text = value.toStringAsFixed(maxDecimals);
  if (!text.contains('.')) return text;
  return text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

bool _isFixedLikeGroup(BudgetPlanGroup g) {
  final n = g.groupName.toLowerCase();
  return g.isFixedGroup || (n.contains('charge') && n.contains('fix'));
}
