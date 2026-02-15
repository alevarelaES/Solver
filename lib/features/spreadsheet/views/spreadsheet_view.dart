import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/spreadsheet/providers/spreadsheet_provider.dart';

const _monthHeaders = [
  'Jan',
  'Fév',
  'Mar',
  'Avr',
  'Mai',
  'Jun',
  'Jul',
  'Aoû',
  'Sep',
  'Oct',
  'Nov',
  'Déc',
];
final _numFmt = NumberFormat('#,##0', 'fr_CH');

class SpreadsheetView extends ConsumerStatefulWidget {
  const SpreadsheetView({super.key});

  @override
  ConsumerState<SpreadsheetView> createState() => _SpreadsheetViewState();
}

class _SpreadsheetViewState extends ConsumerState<SpreadsheetView> {
  String? _selectedCellId;
  int? _selectedMonth;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(spreadsheetDataProvider);
    final year = ref.watch(spreadsheetYearProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentYear = DateTime.now().year;

    final surfaceColor = isDark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final mutedColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Column(
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              // Title
              Text(
                'Strategic Plan',
                style: TextStyle(color: mutedColor, fontSize: 14),
              ),
              Text(
                '  /  ',
                style: TextStyle(color: mutedColor.withValues(alpha: 0.5)),
              ),
              Text(
                '$year Annual Forecast',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  'v1.0 Draft',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              // Year nav
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: year > currentYear - 5
                    ? () => ref.read(spreadsheetYearProvider.notifier).state =
                          year - 1
                    : null,
                splashRadius: 18,
              ),
              Text(
                '$year',
                style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: year < currentYear + 1
                    ? () => ref.read(spreadsheetYearProvider.notifier).state =
                          year + 1
                    : null,
                splashRadius: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Last autosave: 2 min ago',
                style: TextStyle(fontSize: 11, color: mutedColor),
              ),
            ],
          ),
        ),

        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : const Color(0xFFF9FAFB),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              _ToolbarButton(icon: Icons.undo, onTap: () {}),
              _ToolbarButton(icon: Icons.redo, onTap: () {}),
              _ToolbarDivider(color: borderColor),
              Text(
                '100%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: mutedColor,
                ),
              ),
              _ToolbarDivider(color: borderColor),
              Text(
                AppFormats.currencyCode,
                style: GoogleFonts.robotoMono(fontSize: 11, color: mutedColor),
              ),
              _ToolbarDivider(color: borderColor),
              Text(
                'Formula: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(AppRadius.r3),
                ),
                child: Text(
                  _selectedCellId != null && _selectedMonth != null
                      ? 'Cell(${_selectedCellId!}, ${_monthHeaders[_selectedMonth!]})'
                      : 'SUM(row)',
                  style: GoogleFonts.robotoMono(
                    fontSize: 11,
                    color: mutedColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: borderColor),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                      ),
                    ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Expanded(
                  child: _buildTable(
                    data,
                    isDark,
                    surfaceColor,
                    borderColor,
                    textColor,
                    mutedColor,
                  ),
                ),
                _StatusBar(
                  data: data,
                  borderColor: borderColor,
                  mutedColor: mutedColor,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(
    SpreadsheetData data,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color mutedColor,
  ) {
    const catWidth = 220.0;
    const cellWidth = 100.0;
    const totalWidth = 110.0;

    final headerBg = isDark
        ? AppColors.primaryDarker.withValues(alpha: 0.3)
        : const Color(0xFFF9FAFB);
    final sectionBg = isDark
        ? AppColors.primaryDarker.withValues(alpha: 0.2)
        : const Color(0xFFF9FAFB);
    final totalRowBg = AppColors.primary.withValues(
      alpha: isDark ? 0.25 : 0.15,
    );
    final totalColBg = AppColors.primary.withValues(
      alpha: isDark ? 0.15 : 0.05,
    );

    // Sections in display order
    final sections = [
      (SectionType.income, 'REVENUS (Income)', AppColors.primary),
      (SectionType.fixed, 'OBLIGATOIRE (Fixed)', AppColors.primary),
      (SectionType.variable, 'SORTIE (Variable)', AppColors.primaryDark),
      (SectionType.savings, 'ÉPARGNE (Savings)', AppColors.primaryDarker),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: catWidth + (cellWidth * 12) + totalWidth,
            child: Column(
              children: [
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: headerBg,
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      _HeaderCell(
                        text: 'Category',
                        width: catWidth,
                        alignment: Alignment.centerLeft,
                        isDark: isDark,
                        borderColor: borderColor,
                      ),
                      ...List.generate(
                        12,
                        (i) => _HeaderCell(
                          text: _monthHeaders[i],
                          width: cellWidth,
                          isDark: isDark,
                          borderColor: borderColor,
                        ),
                      ),
                      _HeaderCell(
                        text: 'Total',
                        width: totalWidth,
                        isDark: isDark,
                        borderColor: borderColor,
                        isPrimary: true,
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    children: [
                      for (final (sectionType, sectionLabel, sectionColor)
                          in sections) ...[
                        // Section header
                        _SectionHeaderRow(
                          label: sectionLabel,
                          color: sectionColor,
                          catWidth: catWidth,
                          totalCols: 13,
                          cellWidth: cellWidth,
                          totalWidth: totalWidth,
                          bgColor: sectionBg,
                          borderColor: borderColor,
                          isDark: isDark,
                        ),
                        // Data rows
                        for (final row in data.rowsForSection(sectionType))
                          _DataRow(
                            row: row,
                            catWidth: catWidth,
                            cellWidth: cellWidth,
                            totalWidth: totalWidth,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                            totalColBg: totalColBg,
                            textColor: textColor,
                            mutedColor: mutedColor,
                            isDark: isDark,
                            selectedCellId: _selectedCellId,
                            selectedMonth: _selectedMonth,
                            onCellTap: (rowId, month) => setState(() {
                              _selectedCellId = rowId;
                              _selectedMonth = month;
                            }),
                            onCellEdit: (rowId, month, value) {
                              ref
                                  .read(spreadsheetDataProvider.notifier)
                                  .updateCell(rowId, month, value);
                            },
                          ),
                        // Section total row
                        _TotalRow(
                          label: 'TOTAL ${sectionLabel.split(' ').first}',
                          totals: data.sectionTotals(sectionType),
                          grandTotal: data.sectionGrandTotal(sectionType),
                          catWidth: catWidth,
                          cellWidth: cellWidth,
                          totalWidth: totalWidth,
                          bgColor: totalRowBg,
                          borderColor: borderColor,
                          isDark: isDark,
                        ),
                        // Spacer
                        SizedBox(height: 12),
                      ],
                      _NetCashFlowRow(
                        monthValues: data.netCashFlowMonths,
                        grandTotal: data.netCashFlowTotal,
                        catWidth: catWidth,
                        cellWidth: cellWidth,
                        totalWidth: totalWidth,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  const _HeaderCell({
    required this.text,
    required this.width,
    this.alignment = Alignment.centerRight,
    required this.isDark,
    required this.borderColor,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.05)
            : null,
        border: Border(
          right: BorderSide(color: borderColor.withValues(alpha: 0.5)),
        ),
      ),
      alignment: alignment,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
          color: isPrimary
              ? AppColors.primary
              : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SectionHeaderRow extends StatelessWidget {
  final String label;
  final Color color;
  final double catWidth;
  final int totalCols;
  final double cellWidth;
  final double totalWidth;
  final Color bgColor;
  final Color borderColor;
  final bool isDark;

  const _SectionHeaderRow({
    required this.label,
    required this.color,
    required this.catWidth,
    required this.totalCols,
    required this.cellWidth,
    required this.totalWidth,
    required this.bgColor,
    required this.borderColor,
    required this.isDark,
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
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: const SizedBox()),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final SpreadsheetRow row;
  final double catWidth;
  final double cellWidth;
  final double totalWidth;
  final Color surfaceColor;
  final Color borderColor;
  final Color totalColBg;
  final Color textColor;
  final Color mutedColor;
  final bool isDark;
  final String? selectedCellId;
  final int? selectedMonth;
  final void Function(String rowId, int month) onCellTap;
  final void Function(String rowId, int month, double value) onCellEdit;

  const _DataRow({
    required this.row,
    required this.catWidth,
    required this.cellWidth,
    required this.totalWidth,
    required this.surfaceColor,
    required this.borderColor,
    required this.totalColBg,
    required this.textColor,
    required this.mutedColor,
    required this.isDark,
    required this.selectedCellId,
    required this.selectedMonth,
    required this.onCellTap,
    required this.onCellEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          bottom: BorderSide(color: borderColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          // Category label
          Container(
            width: catWidth,
            padding: const EdgeInsets.only(left: 36, right: 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(right: BorderSide(color: borderColor)),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              row.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : const Color(0xFF4B5563),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Month cells
          ...List.generate(12, (m) {
            final isSelected = selectedCellId == row.id && selectedMonth == m;
            return _EditableCell(
              value: row.months[m],
              width: cellWidth,
              borderColor: borderColor,
              textColor: textColor,
              isDark: isDark,
              isSelected: isSelected,
              onTap: () => onCellTap(row.id, m),
              onSubmit: (val) => onCellEdit(row.id, m, val),
            );
          }),
          // Total
          Container(
            width: totalWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: totalColBg,
            alignment: Alignment.centerRight,
            child: Text(
              _numFmt.format(row.total),
              style: GoogleFonts.robotoMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableCell extends StatefulWidget {
  final double value;
  final double width;
  final Color borderColor;
  final Color textColor;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<double> onSubmit;

  const _EditableCell({
    required this.value,
    required this.width,
    required this.borderColor,
    required this.textColor,
    required this.isDark,
    required this.isSelected,
    required this.onTap,
    required this.onSubmit,
  });

  @override
  State<_EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<_EditableCell> {
  bool _editing = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _numFmt.format(widget.value));
  }

  @override
  void didUpdateWidget(_EditableCell old) {
    super.didUpdateWidget(old);
    if (!_editing && old.value != widget.value) {
      _ctrl.text = _numFmt.format(widget.value);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _ctrl.text
        .replaceAll(RegExp(r"[^0-9.,\-]"), '')
        .replaceAll("'", '');
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    if (parsed != null) {
      widget.onSubmit(parsed);
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onTap();
        setState(() => _editing = true);
      },
      child: Container(
        width: widget.width,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: widget.borderColor.withValues(alpha: 0.3)),
          ),
          color: widget.isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : null,
        ),
        alignment: Alignment.centerRight,
        child: _editing
            ? TextField(
                controller: _ctrl,
                autofocus: true,
                textAlign: TextAlign.right,
                style: GoogleFonts.robotoMono(
                  fontSize: 12,
                  color: widget.textColor,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                ],
                onSubmitted: (_) => _submit(),
                onTapOutside: (_) => _submit(),
              )
            : Text(
                _numFmt.format(widget.value),
                style: GoogleFonts.robotoMono(
                  fontSize: 12,
                  color: widget.textColor,
                ),
              ),
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
  final Color bgColor;
  final Color borderColor;
  final bool isDark;

  const _TotalRow({
    required this.label,
    required this.totals,
    required this.grandTotal,
    required this.catWidth,
    required this.cellWidth,
    required this.totalWidth,
    required this.bgColor,
    required this.borderColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.primaryDarker;
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: catWidth,
            padding: const EdgeInsets.only(left: 36, right: 12),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(
                right: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
          ...List.generate(
            12,
            (m) => Container(
              width: cellWidth,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
              ),
              alignment: Alignment.centerRight,
              child: Text(
                _numFmt.format(totals[m]),
                style: GoogleFonts.robotoMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ),
          Container(
            width: totalWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.25),
            alignment: Alignment.centerRight,
            child: Text(
              _numFmt.format(grandTotal),
              style: GoogleFonts.robotoMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: AppColors.primaryDarker.withValues(alpha: 0.5),
                ),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              'NET CASH FLOW',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          ...List.generate(
            12,
            (m) => Container(
              width: cellWidth,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              alignment: Alignment.centerRight,
              child: Text(
                _numFmt.format(monthValues[m]),
                style: GoogleFonts.robotoMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Container(
            width: totalWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.primary,
            alignment: Alignment.centerRight,
            child: Text(
              _numFmt.format(grandTotal),
              style: GoogleFonts.robotoMono(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ToolbarButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.r4),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 16,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  final Color color;
  const _ToolbarDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: color,
    );
  }
}

class _StatusBar extends StatelessWidget {
  final SpreadsheetData data;
  final Color borderColor;
  final Color mutedColor;
  final bool isDark;

  const _StatusBar({
    required this.data,
    required this.borderColor,
    required this.mutedColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cashFlow = data.netCashFlowTotal;
    final count = data.rows.length;
    final avg = count > 0 ? cashFlow / 12 : 0.0;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primaryDarker.withValues(alpha: 0.2)
            : const Color(0xFFF9FAFB),
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          // Left side
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text('Online', style: TextStyle(fontSize: 11, color: mutedColor)),
              const SizedBox(width: 20),
              Text(
                'Sheet: Annual${data.year}',
                style: TextStyle(fontSize: 11, color: mutedColor),
              ),
            ],
          ),
          const Spacer(),
          // Right side
          Row(
            children: [
              Text(
                'Sum: ${_numFmt.format(cashFlow)}',
                style: TextStyle(fontSize: 11, color: mutedColor),
              ),
              const SizedBox(width: 20),
              Text(
                'Count: $count',
                style: TextStyle(fontSize: 11, color: mutedColor),
              ),
              const SizedBox(width: 20),
              Text(
                'Avg: ${_numFmt.format(avg)}',
                style: TextStyle(fontSize: 11, color: mutedColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

