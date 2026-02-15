import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/spreadsheet/providers/spreadsheet_provider.dart';

const _monthHeaders = [
  'Jan',
  'Fev',
  'Mar',
  'Avr',
  'Mai',
  'Jun',
  'Jul',
  'Aou',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

final _numFmt = NumberFormat('#,##0', 'fr_CH');

String _formatSignedAmount(
  double value, {
  required bool isIncome,
  bool isEstimated = false,
}) {
  if (value == 0) return '0';
  final signed = '${isIncome ? '+' : '-'}${_numFmt.format(value.abs())}';
  return isEstimated ? '~$signed' : signed;
}

String _formatSignedNet(double value) {
  if (value == 0) return '0';
  return '${value > 0 ? '+' : '-'}${_numFmt.format(value.abs())}';
}

class SpreadsheetView extends ConsumerStatefulWidget {
  const SpreadsheetView({super.key});

  @override
  ConsumerState<SpreadsheetView> createState() => _SpreadsheetViewState();
}

enum _SortColumnType { category, month, total }

class _SpreadsheetViewState extends ConsumerState<SpreadsheetView> {
  _SortColumnType _sortType = _SortColumnType.category;
  int _sortMonth = 0;
  bool _ascending = true;
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _pinnedVerticalController = ScrollController();
  bool _syncingPinned = false;

  @override
  void initState() {
    super.initState();
    _verticalController.addListener(_syncPinnedColumn);
  }

  void _syncPinnedColumn() {
    if (_syncingPinned) return;
    if (!_verticalController.hasClients ||
        !_pinnedVerticalController.hasClients) {
      return;
    }
    final max = _pinnedVerticalController.position.maxScrollExtent;
    final target = _verticalController.offset.clamp(0.0, max);
    if ((_pinnedVerticalController.offset - target).abs() < 0.5) return;

    _syncingPinned = true;
    _pinnedVerticalController.jumpTo(target);
    _syncingPinned = false;
  }

  @override
  void dispose() {
    _verticalController.removeListener(_syncPinnedColumn);
    _horizontalController.dispose();
    _verticalController.dispose();
    _pinnedVerticalController.dispose();
    super.dispose();
  }

  void _toggleSort(_SortColumnType type, {int month = 0}) {
    setState(() {
      final sameColumn =
          _sortType == type &&
          (type != _SortColumnType.month || _sortMonth == month);
      if (sameColumn) {
        _ascending = !_ascending;
        return;
      }
      _sortType = type;
      _sortMonth = month;
      _ascending = true;
    });
  }

  List<SpreadsheetRow> _sortedRows(
    List<SpreadsheetRow> rows,
    SpreadsheetProjectionMode mode,
  ) {
    final sorted = [...rows];
    sorted.sort((a, b) {
      late int result;
      switch (_sortType) {
        case _SortColumnType.category:
          result = a.label.toLowerCase().compareTo(b.label.toLowerCase());
          break;
        case _SortColumnType.month:
          result = a
              .monthValue(_sortMonth, mode)
              .compareTo(b.monthValue(_sortMonth, mode));
          break;
        case _SortColumnType.total:
          result = a.totalFor(mode).compareTo(b.totalFor(mode));
          break;
      }
      if (!_ascending) result = -result;
      if (result != 0) return result;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return sorted;
  }

  bool _isActiveColumn(_SortColumnType type, {int month = 0}) {
    if (_sortType != type) return false;
    if (type == _SortColumnType.month) return _sortMonth == month;
    return true;
  }

  Color _monthShade({
    required bool isDark,
    required int year,
    required int monthIndex,
  }) {
    final now = DateTime.now();
    final month = monthIndex + 1;

    if (year == now.year && month == now.month) {
      return AppColors.primary.withValues(alpha: isDark ? 0.24 : 0.14);
    }

    final isPast = year < now.year || (year == now.year && month < now.month);
    final isFuture = year > now.year || (year == now.year && month > now.month);

    if (isPast) {
      return isDark
          ? Colors.white.withValues(alpha: 0.025)
          : const Color(0xFFF4F6F8);
    }

    if (isFuture) {
      return isDark
          ? Colors.white.withValues(alpha: 0.04)
          : const Color(0xFFFAFBFC);
    }

    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final year = ref.watch(spreadsheetYearProvider);
    final mode = ref.watch(spreadsheetProjectionModeProvider);
    final dataAsync = ref.watch(spreadsheetDataProvider);

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
              Text(
                'Plan strategique',
                style: TextStyle(color: mutedColor, fontSize: 14),
              ),
              Text(
                '  /  ',
                style: TextStyle(color: mutedColor.withValues(alpha: 0.5)),
              ),
              Text(
                '$year Prevision annuelle',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const Spacer(),
              _ProjectionModeSwitch(
                mode: mode,
                onChanged: (next) {
                  ref.read(spreadsheetProjectionModeProvider.notifier).state =
                      next;
                },
              ),
              const SizedBox(width: 12),
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
            ],
          ),
        ),
        Expanded(
          child: dataAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Erreur lors du chargement du tableau',
                    style: TextStyle(color: mutedColor),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => ref.invalidate(spreadsheetDataProvider),
                    child: const Text('Reessayer'),
                  ),
                ],
              ),
            ),
            data: (data) => Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: surfaceColor,
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
              child: Column(
                children: [
                  _ProjectionHint(
                    mode: mode,
                    isDark: isDark,
                    borderColor: borderColor,
                  ),
                  Expanded(
                    child: _buildTable(
                      data,
                      mode,
                      isDark,
                      borderColor,
                      textColor,
                      mutedColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(
    SpreadsheetData data,
    SpreadsheetProjectionMode mode,
    bool isDark,
    Color borderColor,
    Color textColor,
    Color mutedColor,
  ) {
    const catWidth = 230.0;
    const cellWidth = 96.0;
    const totalWidth = 112.0;
    const headerHeight = 42.0;

    final headerBg = isDark
        ? AppColors.primaryDarker.withValues(alpha: 0.35)
        : const Color(0xFFF6F8FB);
    final tableWidth = catWidth + (cellWidth * 12) + totalWidth;

    return Stack(
      children: [
        Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  Container(
                    height: headerHeight,
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
                          isActive: _isActiveColumn(_SortColumnType.category),
                          ascending: _ascending,
                          onTap: () => _toggleSort(_SortColumnType.category),
                        ),
                        ...List.generate(12, (i) {
                          return _HeaderCell(
                            text: _monthHeaders[i],
                            width: cellWidth,
                            alignment: Alignment.center,
                            isDark: isDark,
                            borderColor: borderColor,
                            cellColor: _monthShade(
                              isDark: isDark,
                              year: data.year,
                              monthIndex: i,
                            ),
                            isActive: _isActiveColumn(
                              _SortColumnType.month,
                              month: i,
                            ),
                            ascending: _ascending,
                            onTap: () =>
                                _toggleSort(_SortColumnType.month, month: i),
                          );
                        }),
                        _HeaderCell(
                          text: 'Total',
                          width: totalWidth,
                          isDark: isDark,
                          borderColor: borderColor,
                          isPrimary: true,
                          isActive: _isActiveColumn(_SortColumnType.total),
                          ascending: _ascending,
                          onTap: () => _toggleSort(_SortColumnType.total),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: _verticalController,
                      children: [
                        for (final section in data.sections) ...[
                          ...() {
                            final rows = _sortedRows(section.rows, mode);
                            return [
                              _SectionHeaderRow(
                                label: section.label,
                                color: section.isIncome
                                    ? AppColors.primary
                                    : AppColors.danger,
                                catWidth: catWidth,
                                borderColor: borderColor,
                                bgColor: section.isIncome
                                    ? AppColors.primary.withValues(
                                        alpha: isDark ? 0.2 : 0.08,
                                      )
                                    : AppColors.danger.withValues(
                                        alpha: isDark ? 0.18 : 0.08,
                                      ),
                              ),
                              for (final entry in rows.asMap().entries)
                                _DataRow(
                                  row: entry.value,
                                  mode: mode,
                                  rowIndex: entry.key,
                                  isDark: isDark,
                                  catWidth: catWidth,
                                  cellWidth: cellWidth,
                                  totalWidth: totalWidth,
                                  borderColor: borderColor,
                                  textColor: textColor,
                                  mutedColor: mutedColor,
                                  totalColBg: section.isIncome
                                      ? AppColors.primary.withValues(
                                          alpha: isDark ? 0.2 : 0.06,
                                        )
                                      : AppColors.danger.withValues(
                                          alpha: isDark ? 0.16 : 0.07,
                                        ),
                                  monthCellColor: (m) => _monthShade(
                                    isDark: isDark,
                                    year: data.year,
                                    monthIndex: m,
                                  ),
                                ),
                              _TotalRow(
                                label: 'TOTAL ${section.label.toUpperCase()}',
                                totals: data.sectionTotals(section.id, mode),
                                grandTotal: data.sectionGrandTotal(
                                  section.id,
                                  mode,
                                ),
                                catWidth: catWidth,
                                cellWidth: cellWidth,
                                totalWidth: totalWidth,
                                borderColor: borderColor,
                                isDark: isDark,
                                isIncome: section.isIncome,
                                monthCellColor: (m) => _monthShade(
                                  isDark: isDark,
                                  year: data.year,
                                  monthIndex: m,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ];
                          }(),
                        ],
                        _NetCashFlowRow(
                          monthValues: data.netCashFlowMonths(mode),
                          grandTotal: data.netCashFlowTotal(mode),
                          catWidth: catWidth,
                          cellWidth: cellWidth,
                          totalWidth: totalWidth,
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: catWidth,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border(
                  right: BorderSide(color: borderColor.withValues(alpha: 0.95)),
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(2, 0),
                        ),
                      ],
              ),
              child: Column(
                children: [
                  Container(
                    height: headerHeight,
                    color: headerBg,
                    child: _HeaderCell(
                      text: 'Category',
                      width: catWidth,
                      alignment: Alignment.centerLeft,
                      isDark: isDark,
                      borderColor: borderColor,
                      isActive: _isActiveColumn(_SortColumnType.category),
                      ascending: _ascending,
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: _pinnedVerticalController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final section in data.sections) ...[
                          ...() {
                            final rows = _sortedRows(section.rows, mode);
                            return [
                              _PinnedSectionCell(
                                label: section.label,
                                color: section.isIncome
                                    ? AppColors.primary
                                    : AppColors.danger,
                                borderColor: borderColor,
                                bgColor: section.isIncome
                                    ? AppColors.primary.withValues(
                                        alpha: isDark ? 0.2 : 0.08,
                                      )
                                    : AppColors.danger.withValues(
                                        alpha: isDark ? 0.18 : 0.08,
                                      ),
                              ),
                              for (final entry in rows.asMap().entries)
                                _PinnedDataCell(
                                  label: entry.value.label,
                                  rowIndex: entry.key,
                                  isDark: isDark,
                                  borderColor: borderColor,
                                  textColor: textColor,
                                ),
                              _PinnedTotalCell(
                                label: 'TOTAL ${section.label.toUpperCase()}',
                                borderColor: borderColor,
                                isDark: isDark,
                                isIncome: section.isIncome,
                              ),
                              const SizedBox(height: 12),
                            ];
                          }(),
                        ],
                        const _PinnedNetCell(),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
        : const Color(0xFFF3F5F8);
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    Widget chip(String label, SpreadsheetProjectionMode value) {
      final selected = mode == value;
      return InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? (isDark
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
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
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chip('Prudent', SpreadsheetProjectionMode.prudent),
          chip('Prevision', SpreadsheetProjectionMode.prevision),
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
        ? 'Mode prudent: revenus non confirmes exclus.'
        : 'Mode prevision: les revenus estimes sont inclus (prefixe ~).';

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF4B5563),
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
              : const Color(0xFFFBFCFD));
    final categoryCellColor = rowIndex.isEven
        ? (isDark
              ? Colors.white.withValues(alpha: 0.035)
              : const Color(0xFFF8FAFC))
        : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFF4F7FA));

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
                      ? const Color(0xFFB45309)
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
                    ? const Color(0xFFB45309)
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
              'NET CASH FLOW',
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
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFFBBF7D0),
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
                    ? const Color(0xFFFCA5A5)
                    : const Color(0xFFDCFCE7),
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
              : const Color(0xFFFBFCFD));
    final categoryCellColor = rowIndex.isEven
        ? (isDark
              ? Colors.white.withValues(alpha: 0.035)
              : const Color(0xFFF8FAFC))
        : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFF4F7FA));

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
