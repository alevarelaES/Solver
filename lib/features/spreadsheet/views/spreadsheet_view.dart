import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/spreadsheet/providers/spreadsheet_provider.dart';
import 'package:solver/shared/widgets/page_header.dart';
import 'package:solver/shared/widgets/page_scaffold.dart';

part 'spreadsheet_view.widgets.part.dart';

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
          : AppColors.surfaceSoft;
    }

    if (isFuture) {
      return isDark
          ? Colors.white.withValues(alpha: 0.04)
          : AppColors.surfaceSoftAlt;
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

    return AppPageScaffold(
      scrollable: false,
      maxWidth: 1480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPageHeader(
            title: 'Plan strategique',
            subtitle: '$year prevision annuelle',
            trailing: _SpreadsheetHeaderControls(
              mode: mode,
              year: year,
              currentYear: currentYear,
              onModeChanged: (next) {
                ref.read(spreadsheetProjectionModeProvider.notifier).state =
                    next;
              },
              onPrevious: year > currentYear - 5
                  ? () => ref.read(spreadsheetYearProvider.notifier).state =
                        year - 1
                  : null,
              onNext: year < currentYear + 1
                  ? () => ref.read(spreadsheetYearProvider.notifier).state =
                        year + 1
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
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
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
          ),
        ],
      ),
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
        : AppColors.surfaceTableHeader;
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
