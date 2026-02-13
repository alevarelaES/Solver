import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Data model ──────────────────────────────────────────────────────────────

enum SectionType { income, fixed, variable, savings }

class SpreadsheetRow {
  final String id;
  final String label;
  final SectionType section;
  final List<double> months; // 12 values, one per month

  const SpreadsheetRow({
    required this.id,
    required this.label,
    required this.section,
    required this.months,
  });

  double get total => months.fold(0.0, (a, b) => a + b);

  SpreadsheetRow copyWithMonth(int monthIndex, double value) {
    final updated = List<double>.from(months);
    updated[monthIndex] = value;
    return SpreadsheetRow(id: id, label: label, section: section, months: updated);
  }
}

class SpreadsheetData {
  final int year;
  final List<SpreadsheetRow> rows;

  const SpreadsheetData({required this.year, required this.rows});

  List<SpreadsheetRow> rowsForSection(SectionType section) =>
      rows.where((r) => r.section == section).toList();

  List<double> sectionTotals(SectionType section) {
    final sectionRows = rowsForSection(section);
    return List.generate(12, (m) =>
        sectionRows.fold(0.0, (sum, r) => sum + r.months[m]));
  }

  double sectionGrandTotal(SectionType section) =>
      sectionTotals(section).fold(0.0, (a, b) => a + b);

  /// NET CASH FLOW = Income - Fixed - Variable - Savings
  List<double> get netCashFlowMonths {
    final inc = sectionTotals(SectionType.income);
    final fix = sectionTotals(SectionType.fixed);
    final vari = sectionTotals(SectionType.variable);
    final sav = sectionTotals(SectionType.savings);
    return List.generate(12, (m) => inc[m] - fix[m] - vari[m] - sav[m]);
  }

  double get netCashFlowTotal => netCashFlowMonths.fold(0.0, (a, b) => a + b);

  SpreadsheetData updateCell(String rowId, int monthIndex, double value) {
    final updated = rows.map((r) {
      if (r.id == rowId) return r.copyWithMonth(monthIndex, value);
      return r;
    }).toList();
    return SpreadsheetData(year: year, rows: updated);
  }
}

// ─── Default mock data ───────────────────────────────────────────────────────

SpreadsheetData _defaultData(int year) => SpreadsheetData(
      year: year,
      rows: [
        // Income
        const SpreadsheetRow(
          id: 'salary',
          label: 'Salaire Net',
          section: SectionType.income,
          months: [4500, 4500, 4500, 4500, 5200, 4500, 4500, 4500, 4500, 4500, 4500, 6500],
        ),
        // Fixed
        const SpreadsheetRow(
          id: 'rent',
          label: 'Loyer / Hypothèque',
          section: SectionType.fixed,
          months: [1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200],
        ),
        const SpreadsheetRow(
          id: 'utilities',
          label: 'Electricité / Eau',
          section: SectionType.fixed,
          months: [145, 160, 130, 110, 90, 85, 85, 90, 100, 120, 150, 180],
        ),
        const SpreadsheetRow(
          id: 'insurance',
          label: 'Assurances',
          section: SectionType.fixed,
          months: [45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45],
        ),
        // Variable
        const SpreadsheetRow(
          id: 'groceries',
          label: 'Courses',
          section: SectionType.variable,
          months: [400, 380, 420, 400, 450, 410, 390, 400, 420, 400, 460, 600],
        ),
        const SpreadsheetRow(
          id: 'transport',
          label: 'Transport',
          section: SectionType.variable,
          months: [120, 120, 120, 120, 150, 180, 180, 120, 120, 120, 120, 150],
        ),
        // Savings
        const SpreadsheetRow(
          id: 'etf',
          label: 'ETF / Actions',
          section: SectionType.savings,
          months: [500, 500, 500, 500, 500, 1000, 500, 500, 500, 500, 500, 1500],
        ),
      ],
    );

// ─── Provider ────────────────────────────────────────────────────────────────

final spreadsheetYearProvider = StateProvider<int>((ref) => DateTime.now().year);

final spreadsheetDataProvider =
    StateNotifierProvider<SpreadsheetNotifier, SpreadsheetData>((ref) {
  final year = ref.watch(spreadsheetYearProvider);
  return SpreadsheetNotifier(_defaultData(year));
});

class SpreadsheetNotifier extends StateNotifier<SpreadsheetData> {
  SpreadsheetNotifier(super.data);

  void updateCell(String rowId, int monthIndex, double value) {
    state = state.updateCell(rowId, monthIndex, value);
  }
}
