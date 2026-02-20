import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solver/core/constants/currency_catalog.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/providers/exchange_rate_provider.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';

class CurrencyConverterSheet extends ConsumerStatefulWidget {
  final String initialSourceCode;
  final double initialAmount;

  const CurrencyConverterSheet({
    super.key,
    required this.initialSourceCode,
    this.initialAmount = 1,
  });

  @override
  ConsumerState<CurrencyConverterSheet> createState() =>
      _CurrencyConverterSheetState();
}

class _CurrencyConverterSheetState
    extends ConsumerState<CurrencyConverterSheet> {
  static const _quickAmounts = <double>[1, 10, 100, 1000];
  static const _favoritesStorageKey = 'currency_converter_favorites';

  late final TextEditingController _amountController;
  late final TextEditingController _searchController;
  late String _sourceCode;
  final Set<String> _favoriteCodes = <String>{};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount.toStringAsFixed(0),
    )..addListener(_onAmountChanged);
    _searchController = TextEditingController()
      ..addListener(() {
        setState(() {
          _searchQuery = _searchController.text.trim().toUpperCase();
        });
      });
    _sourceCode = widget.initialSourceCode.trim().toUpperCase();
    _loadFavorites();
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_favoritesStorageKey) ?? const [];
    if (!mounted) return;
    setState(() {
      _favoriteCodes
        ..clear()
        ..addAll(stored.map((code) => code.trim().toUpperCase()));
    });
  }

  Future<void> _toggleFavorite(String code) async {
    final normalized = code.trim().toUpperCase();
    setState(() {
      if (_favoriteCodes.contains(normalized)) {
        _favoriteCodes.remove(normalized);
      } else {
        _favoriteCodes.add(normalized);
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favoritesStorageKey,
      _favoriteCodes.toList(growable: false)..sort(),
    );
  }

  void _onAmountChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(rawExchangeRateSnapshotProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          math.max(
            AppSpacing.lg,
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
        ),
        child: snapshotAsync.when(
          loading: _buildLoading,
          error: (_, _) => _buildError(),
          data: (snapshot) => _buildContent(
            rates: snapshot.rates,
            source: snapshot.source,
            updatedAtUtc: snapshot.updatedAtUtc,
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const SizedBox(
      height: 260,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildError() {
    return SizedBox(
      height: 280,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_outlined,
            size: 32,
            color: AppColors.danger,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.ui.currencyConverterOffline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(rawExchangeRateSnapshotProvider),
            icon: const Icon(Icons.refresh),
            label: Text(AppStrings.ui.currencyConverterRefresh),
          ),
        ],
      ),
    );
  }

  Widget _buildContent({
    required Map<String, double> rates,
    required String source,
    required DateTime? updatedAtUtc,
  }) {
    final allCodes = rates.keys.toSet();
    final sourceCode = _resolveSourceCode(allCodes);
    final sourceRate = rates[sourceCode] ?? 0;
    final amount = _parseAmount(_amountController.text);

    final favoriteTargets = _sortedCodes(_favoriteCodes)
        .where((code) => allCodes.contains(code) && code != sourceCode)
        .toList(growable: false);

    final popularCodes = CurrencyCatalog.popularCodes
        .where((code) => allCodes.contains(code) && code != sourceCode)
        .toList(growable: false);

    final allTargets = _sortedCodes(
      allCodes,
    ).where((code) => code != sourceCode).toList(growable: false);
    final filteredAllTargets = allTargets
        .where(
          (code) =>
              _searchQuery.isEmpty ||
              code.contains(_searchQuery) ||
              CurrencyCatalog.descriptionFr(
                code,
              ).toUpperCase().contains(_searchQuery),
        )
        .toList(growable: false);

    final favoritesTab = _ConverterTab(
      label: AppStrings.ui.currencyConverterFavoritesLabel,
      child: _ratesList(
        codes: favoriteTargets,
        sourceCode: sourceCode,
        sourceRate: sourceRate,
        amount: amount,
        rates: rates,
        emptyLabel: AppStrings.ui.currencyConverterFavoritesEmpty,
      ),
    );

    final popularTab = _ConverterTab(
      label: AppStrings.ui.currencyConverterPopularLabel,
      child: _ratesList(
        codes: popularCodes,
        sourceCode: sourceCode,
        sourceRate: sourceRate,
        amount: amount,
        rates: rates,
        emptyLabel: AppStrings.ui.currencyConverterNoSearchResult,
      ),
    );

    final allTab = _ConverterTab(
      label: AppStrings.ui.currencyConverterAllLabel,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: AppStrings.ui.currencyConverterSearchLabel,
              hintText: AppStrings.ui.currencyConverterSearchHint,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _ratesList(
              codes: filteredAllTargets,
              sourceCode: sourceCode,
              sourceRate: sourceRate,
              amount: amount,
              rates: rates,
              emptyLabel: AppStrings.ui.currencyConverterNoSearchResult,
            ),
          ),
        ],
      ),
    );

    final tabs = <_ConverterTab>[
      if (favoriteTargets.isNotEmpty) favoritesTab,
      popularTab,
      allTab,
      if (favoriteTargets.isEmpty) favoritesTab,
    ];

    final maxHeight = math.min(820.0, MediaQuery.of(context).size.height * 0.9);

    return DefaultTabController(
      length: tabs.length,
      child: SizedBox(
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heroHeader(source: source, updatedAtUtc: updatedAtUtc),
            const SizedBox(height: AppSpacing.md),
            _inputControls(
              allCodes: allCodes,
              sourceCode: sourceCode,
              amount: amount,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: TabBar(
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: tabs.map((tab) => Tab(text: tab.label)).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: TabBarView(
                children: tabs.map((tab) => tab.child).toList(growable: false),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.ui.currencyConverterIndicative,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroHeader({
    required String source,
    required DateTime? updatedAtUtc,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.16),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.ui.currencyConverterTitle,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.s6),
          Text(
            AppStrings.ui.currencyConverterSubtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          Text(
            AppStrings.ui.currencyConverterSource(source),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            updatedAtUtc == null
                ? AppStrings.ui.currencyConverterUpdatedUnknown
                : AppStrings.ui.currencyConverterUpdatedAt(
                    _formatUpdatedDate(updatedAtUtc),
                  ),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputControls({
    required Set<String> allCodes,
    required String sourceCode,
    required double amount,
  }) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 520;
            final dropdown = DropdownButtonFormField<String>(
              key: ValueKey(sourceCode),
              initialValue: sourceCode,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: AppStrings.ui.currencyConverterFromLabel,
                prefixIcon: const Icon(Icons.currency_exchange),
              ),
              items: _sortedCodes(allCodes)
                  .map(
                    (code) => DropdownMenuItem<String>(
                      value: code,
                      child: Text(
                        _codeLabel(code),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              selectedItemBuilder: (context) => _sortedCodes(allCodes)
                  .map(
                    (code) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _codeLabel(code),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _sourceCode = value;
                });
              },
            );

            if (isCompact) {
              return Column(
                children: [
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: AppStrings.ui.currencyConverterAmountLabel,
                      prefixIcon: const Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  dropdown,
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: AppStrings.ui.currencyConverterAmountLabel,
                      prefixIcon: const Icon(Icons.payments_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: dropdown),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: _quickAmounts
                .map((value) {
                  final selected = amount == value;
                  return ChoiceChip(
                    label: Text(value.toStringAsFixed(0)),
                    selected: selected,
                    onSelected: (_) {
                      _amountController.text = value.toStringAsFixed(0);
                    },
                  );
                })
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _ratesList({
    required List<String> codes,
    required String sourceCode,
    required double sourceRate,
    required double amount,
    required Map<String, double> rates,
    required String emptyLabel,
  }) {
    if (codes.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      itemCount: codes.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (_, index) {
        final code = codes[index];
        final targetRate = rates[code] ?? 0;
        final hasRate = sourceRate > 0 && targetRate > 0;
        final converted = hasRate ? amount * (targetRate / sourceRate) : null;
        final unitRate = hasRate ? (targetRate / sourceRate) : null;
        final isFavorite = _favoriteCodes.contains(code);

        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _codeLabel(code),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      unitRate == null
                          ? AppStrings.ui.currencyConverterNoRate
                          : '1 $sourceCode = ${_formatAmount(code, unitRate)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isFavorite
                    ? AppStrings.ui.currencyConverterRemoveFavorite
                    : AppStrings.ui.currencyConverterAddFavorite,
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFavorite
                      ? AppColors.warning
                      : AppColors.textSecondary,
                ),
                onPressed: () => _toggleFavorite(code),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    converted == null
                        ? AppStrings.ui.currencyConverterNoRate
                        : _formatAmount(code, converted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: converted == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _resolveSourceCode(Set<String> allCodes) {
    if (allCodes.contains(_sourceCode)) return _sourceCode;
    if (allCodes.contains('CHF')) return 'CHF';
    final sorted = _sortedCodes(allCodes);
    return sorted.isEmpty ? 'CHF' : sorted.first;
  }

  List<String> _sortedCodes(Iterable<String> codes) {
    final normalized = codes.map((code) => code.toUpperCase()).toList();
    normalized.sort();
    return normalized;
  }

  static double _parseAmount(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  static String _formatAmount(String code, double amount) {
    try {
      final locale = CurrencyCatalog.locale(code);
      final value = NumberFormat.decimalPattern(locale).format(amount);
      return '$value $code';
    } catch (_) {
      return '${amount.toStringAsFixed(2)} $code';
    }
  }

  static String _formatUpdatedDate(DateTime updatedAtUtc) {
    return DateFormat('dd/MM/yyyy HH:mm').format(updatedAtUtc.toUtc());
  }

  static String _codeLabel(String code) {
    return CurrencyCatalog.labelFr(code);
  }
}

class _ConverterTab {
  final String label;
  final Widget child;

  const _ConverterTab({required this.label, required this.child});
}

Future<void> showCurrencyConverterSheet(
  BuildContext context, {
  required String initialSourceCode,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final size = MediaQuery.sizeOf(dialogContext);
      final width = math.min(920.0, size.width - 20);
      final height = math.min(860.0, size.height - 20);

      return Dialog(
        insetPadding: const EdgeInsets.all(10),
        backgroundColor: Theme.of(dialogContext).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: SizedBox(
          width: width,
          height: height,
          child: CurrencyConverterSheet(initialSourceCode: initialSourceCode),
        ),
      );
    },
  );
}
