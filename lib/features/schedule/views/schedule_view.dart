import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/core/theme/app_text_styles.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/dashboard/providers/dashboard_provider.dart';
import 'package:solver/features/schedule/providers/schedule_provider.dart';
import 'package:solver/features/transactions/models/transaction.dart';

class ScheduleView extends ConsumerWidget {
  const ScheduleView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingTransactionsProvider);

    return upcomingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Erreur: $e', style: const TextStyle(color: AppColors.softRed)),
      ),
      data: (data) => Column(
        children: [
          _ScheduleHeader(data: data),
          Expanded(
            child: data.auto.isEmpty && data.manual.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune échéance dans les 30 prochains jours',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _UpcomingSection(
                                title: 'Prélèvements Auto',
                                icon: Icons.bolt,
                                color: AppColors.electricBlue,
                                transactions: data.auto,
                                total: data.totalAuto,
                                onChanged: () => ref.invalidate(upcomingTransactionsProvider),
                              ),
                            ),
                            const VerticalDivider(color: AppColors.borderSubtle, width: 1),
                            Expanded(
                              child: _UpcomingSection(
                                title: 'Factures Manuelles',
                                icon: Icons.notifications_outlined,
                                color: AppColors.warmAmber,
                                transactions: data.manual,
                                total: data.totalManual,
                                showValidate: true,
                                onChanged: () => ref.invalidate(upcomingTransactionsProvider),
                              ),
                            ),
                          ],
                        );
                      }
                      return DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            TabBar(
                              tabs: const [
                                Tab(text: 'Auto'),
                                Tab(text: 'Manuelles'),
                              ],
                              labelColor: AppColors.electricBlue,
                              unselectedLabelColor: AppColors.textSecondary,
                              indicatorColor: AppColors.electricBlue,
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _UpcomingSection(
                                    title: 'Prélèvements Auto',
                                    icon: Icons.bolt,
                                    color: AppColors.electricBlue,
                                    transactions: data.auto,
                                    total: data.totalAuto,
                                    onChanged: () => ref.invalidate(upcomingTransactionsProvider),
                                  ),
                                  _UpcomingSection(
                                    title: 'Factures Manuelles',
                                    icon: Icons.notifications_outlined,
                                    color: AppColors.warmAmber,
                                    transactions: data.manual,
                                    total: data.totalManual,
                                    showValidate: true,
                                    onChanged: () => ref.invalidate(upcomingTransactionsProvider),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _ScheduleHeader extends StatelessWidget {
  final UpcomingData data;
  const _ScheduleHeader({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Column(
        children: [
          const Text('Total à payer',
              style: AppTextStyles.bodySmall),
          const SizedBox(height: 4),
          Text(
            AppFormats.currencyCompact.format(data.grandTotal),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SubTotal(
                label: 'Auto',
                amount: data.totalAuto,
                color: AppColors.electricBlue,
              ),
              const SizedBox(width: 32),
              _SubTotal(
                label: 'Manuel',
                amount: data.totalManual,
                color: AppColors.warmAmber,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubTotal extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _SubTotal({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.label),
        Text(
          AppFormats.currency.format(amount),
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ─── Section (auto or manual) ─────────────────────────────────────────────────
class _UpcomingSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Transaction> transactions;
  final double total;
  final bool showValidate;
  final VoidCallback onChanged;

  const _UpcomingSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.transactions,
    required this.total,
    this.showValidate = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              Text(AppFormats.currency.format(total),
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Aucune échéance',
                style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          ...transactions
              .map((t) => _UpcomingCard(
                    transaction: t,
                    color: color,
                    showValidate: showValidate,
                    onChanged: onChanged,
                  )),
      ],
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────
class _UpcomingCard extends ConsumerStatefulWidget {
  final Transaction transaction;
  final Color color;
  final bool showValidate;
  final VoidCallback onChanged;

  const _UpcomingCard({
    required this.transaction,
    required this.color,
    required this.showValidate,
    required this.onChanged,
  });

  @override
  ConsumerState<_UpcomingCard> createState() => _UpcomingCardState();
}

class _UpcomingCardState extends ConsumerState<_UpcomingCard> {
  bool _loading = false;

  bool get _isSoon {
    final diff = widget.transaction.date
        .difference(DateTime.now())
        .inDays;
    return diff <= 7;
  }

  Future<void> _validate() async {
    setState(() => _loading = true);
    try {
      final t = widget.transaction;
      final client = ref.read(apiClientProvider);
      await client.put('/api/transactions/${t.id}', data: {
        'accountId': t.accountId,
        'date': DateFormat('yyyy-MM-dd').format(t.date),
        'amount': t.amount,
        'note': t.note,
        'status': 'completed',
        'isAuto': t.isAuto,
      });
      ref.invalidate(dashboardDataProvider);
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isSoon ? AppColors.warmAmber : AppColors.borderSubtle,
          width: _isSoon ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.accountName ?? t.accountId,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy', 'fr_FR').format(t.date),
                      style: TextStyle(
                        color:
                            _isSoon ? AppColors.warmAmber : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            _isSoon ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (_isSoon) ...[
                      const SizedBox(width: 4),
                      const Text('· Bientôt',
                          style: TextStyle(
                              color: AppColors.warmAmber, fontSize: 11)),
                    ],
                  ],
                ),
                if (t.note != null && t.note!.isNotEmpty)
                  Text(t.note!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormats.currency.format(t.amount),
                style: TextStyle(
                  color: widget.color,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              if (widget.showValidate) ...[
                const SizedBox(height: 6),
                if (_loading)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  TextButton(
                    onPressed: _validate,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.neonEmerald,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(48, 36),
                    ),
                    child: const Text('Valider', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
