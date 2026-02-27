import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/providers/navigation_providers.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/dashboard/providers/recent_transactions_provider.dart';
import 'package:solver/features/transactions/models/transaction.dart';
import 'package:solver/shared/widgets/premium_card_base.dart';

class RecentActivities extends ConsumerStatefulWidget {
  const RecentActivities({super.key});

  @override
  ConsumerState<RecentActivities> createState() => _RecentActivitiesState();
}

class _RecentActivitiesState extends ConsumerState<RecentActivities> {
  String _searchQuery = '';
  bool _sortDateAsc = false; // false = most recent first
  String _filterType = 'all'; // 'all', 'income', 'expense'

  @override
  Widget build(BuildContext context) {
    ref.watch(appCurrencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recentAsync = ref.watch(recentTransactionsProvider);

    return PremiumCardBase(
      variant: PremiumCardVariant.standard,
      padding: AppSpacing.paddingCardCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          LayoutBuilder(
            builder: (context, constraints) {
              final compactHeader = constraints.maxWidth < 560;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    AppStrings.dashboard.recentActivities,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: compactHeader ? 120 : 140,
                        height: 30,
                        child: TextField(
                          style: const TextStyle(fontSize: 12),
                          onChanged: (v) =>
                              setState(() => _searchQuery = v.toLowerCase()),
                          decoration: InputDecoration(
                            hintText: AppStrings.dashboard.search,
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textDisabledDark
                                  : AppColors.textDisabledLight,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              size: 16,
                              color: isDark
                                  ? AppColors.textDisabledDark
                                  : AppColors.textDisabledLight,
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 32,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight,
                              ),
                            ),
                            filled: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.tune,
                          size: 18,
                          color: _filterType != 'all'
                              ? AppColors.primary
                              : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: AppStrings.dashboard.filter,
                        onSelected: (v) => setState(() => _filterType = v),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'all',
                            child: Row(
                              children: [
                                if (_filterType == 'all')
                                  const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: AppColors.primary,
                                  )
                                else
                                  const SizedBox(width: 16),
                                const SizedBox(width: 8),
                                Text(AppStrings.dashboard.filterAll),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'income',
                            child: Row(
                              children: [
                                if (_filterType == 'income')
                                  const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: AppColors.primary,
                                  )
                                else
                                  const SizedBox(width: 16),
                                const SizedBox(width: 8),
                                Text(AppStrings.dashboard.filterIncome),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'expense',
                            child: Row(
                              children: [
                                if (_filterType == 'expense')
                                  const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: AppColors.primary,
                                  )
                                else
                                  const SizedBox(width: 16),
                                const SizedBox(width: 8),
                                Text(AppStrings.dashboard.filterExpense),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          // Column headers
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  AppStrings.dashboard.description,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textDisabledDark
                        : AppColors.textDisabledLight,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () => setState(() => _sortDateAsc = !_sortDateAsc),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.dashboard.date,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textDisabledDark
                              : AppColors.textDisabledLight,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _sortDateAsc
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 12,
                        color: isDark
                            ? AppColors.textDisabledDark
                            : AppColors.textDisabledLight,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  AppStrings.dashboard.amount,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textDisabledDark
                        : AppColors.textDisabledLight,
                  ),
                ),
              ),
            ],
          ),
          Divider(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            height: 16,
          ),
          // Rows
          recentAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: Text(
                  AppStrings.dashboard.loadingError,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textDisabledDark
                        : AppColors.textDisabledLight,
                  ),
                ),
              ),
            ),
            data: (transactions) {
              var filtered = transactions.where((tx) {
                // Filter by type
                if (_filterType == 'income' && !tx.isIncome) return false;
                if (_filterType == 'expense' && tx.isIncome) return false;
                // Filter by search
                if (_searchQuery.isNotEmpty) {
                  final text = '${tx.displayNote ?? ''} ${tx.accountName ?? ''}'
                      .toLowerCase();
                  if (!text.contains(_searchQuery)) return false;
                }
                return true;
              }).toList();

              // Sort by date
              filtered.sort(
                (a, b) => _sortDateAsc
                    ? a.date.compareTo(b.date)
                    : b.date.compareTo(a.date),
              );

              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: Text(
                      AppStrings.dashboard.noTransactions,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textDisabledDark
                            : AppColors.textDisabledLight,
                      ),
                    ),
                  ),
                );
              }
              // Limit to 4 transactions max on dashboard
              final display = filtered.take(4).toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: display
                    .map(
                      (tx) => _TransactionRow(
                        transaction: tx,
                        onTap: () {
                          ref.read(pendingJournalTxIdProvider.notifier).state =
                              tx.id;
                          context.go('/journal');
                        },
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatefulWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const _TransactionRow({
    required this.transaction,
    this.onTap,
  });

  @override
  State<_TransactionRow> createState() => _TransactionRowState();
}

class _TransactionRowState extends State<_TransactionRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tx = widget.transaction;
    final isVoided = tx.isVoided;
    final signedAmount = tx.signedAmount;
    final amountPrefix = signedAmount >= 0 ? '+' : '-';
    final amountColor = signedAmount >= 0
        ? AppColors.success
        : AppColors.danger;
    final dateFormat = DateFormat('dd MMM yyyy', 'fr_CH');

    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.05) // frosted white hover for dark
                      : Colors.white.withValues(alpha: 0.60)) // frosted white hover for light
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              // Icon + description
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    Container(
                      width: AppSizes.iconBoxSizeSm,
                      height: AppSizes.iconBoxSizeSm,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.surfaceHeader,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _getIcon(tx),
                        size: AppSizes.iconSizeSm,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        tx.displayNote ?? (tx.accountName ?? '-'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                          decoration: isVoided
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Date
              Expanded(
                flex: 3,
                child: Text(
                  dateFormat.format(tx.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    decoration: isVoided
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ),
              // Amount
              Expanded(
                flex: 3,
                child: Text(
                  '$amountPrefix${AppFormats.formatFromChf(signedAmount.abs())}',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.robotoMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                    decoration: isVoided
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(Transaction tx) {
    final name = (tx.accountName ?? '').toLowerCase();
    final note = (tx.displayNote ?? '').toLowerCase();
    final combined = '$name $note';

    if (combined.contains('loyer') ||
        combined.contains('logement') ||
        combined.contains('rent')) {
      return Icons.home_outlined;
    }
    if (combined.contains('transport') ||
        combined.contains('essence') ||
        combined.contains('gas')) {
      return Icons.local_gas_station;
    }
    if (combined.contains('electr') ||
        combined.contains('energie') ||
        combined.contains('eau')) {
      return Icons.bolt;
    }
    if (combined.contains('epicerie') ||
        combined.contains('alimentation') ||
        combined.contains('grocery')) {
      return Icons.shopping_cart_outlined;
    }
    if (combined.contains('abonnement') || combined.contains('subscription')) {
      return Icons.subscriptions_outlined;
    }
    if (combined.contains('salaire') ||
        combined.contains('salary') ||
        combined.contains('revenu')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (tx.isIncome) return Icons.trending_up;
    return Icons.receipt_long_outlined;
  }
}
