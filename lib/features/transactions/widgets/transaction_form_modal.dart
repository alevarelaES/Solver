import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/core/theme/app_text_styles.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/accounts/models/account.dart';
import 'package:solver/features/accounts/providers/accounts_provider.dart';
import 'package:solver/features/dashboard/providers/dashboard_provider.dart';

void showTransactionFormModal(BuildContext context, WidgetRef ref, {String? preselectedAccountId}) {
  final isDesktop = MediaQuery.of(context).size.width > 768;

  if (isDesktop) {
    showDialog(
      context: context,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: _TransactionFormDialog(preselectedAccountId: preselectedAccountId),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: _TransactionFormSheet(preselectedAccountId: preselectedAccountId),
      ),
    );
  }
}

// ─── Desktop Dialog ───────────────────────────────────────────────────────────
class _TransactionFormDialog extends StatelessWidget {
  final String? preselectedAccountId;
  const _TransactionFormDialog({this.preselectedAccountId});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceDialog,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: _TransactionForm(preselectedAccountId: preselectedAccountId),
      ),
    );
  }
}

// ─── Mobile BottomSheet ───────────────────────────────────────────────────────
class _TransactionFormSheet extends StatelessWidget {
  final String? preselectedAccountId;
  const _TransactionFormSheet({this.preselectedAccountId});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceDialog,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        child: _TransactionForm(
          preselectedAccountId: preselectedAccountId,
          scrollController: controller,
        ),
      ),
    );
  }
}

// ─── Form content ─────────────────────────────────────────────────────────────
class _TransactionForm extends ConsumerStatefulWidget {
  final String? preselectedAccountId;
  final ScrollController? scrollController;

  const _TransactionForm({this.preselectedAccountId, this.scrollController});

  @override
  ConsumerState<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<_TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _dayCtrl = TextEditingController();

  String? _selectedAccountId;
  DateTime _date = DateTime.now();
  bool _isPaid = false;
  bool _isAuto = false;
  bool _recurrence = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedAccountId = widget.preselectedAccountId;
    _dayCtrl.text = DateTime.now().day.toString();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  int get _occurrences {
    if (!_recurrence) return 1;
    return 13 - _date.month;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.electricBlue),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        if (!_recurrence) _dayCtrl.text = picked.day.toString();
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      setState(() => _error = 'Sélectionnez un compte');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final client = ref.read(apiClientProvider);
      final amount = double.parse(_amountCtrl.text.replaceAll(',', '.'));
      final dateStr = DateFormat('yyyy-MM-dd').format(_date);
      final status = _isPaid ? 'completed' : 'pending';

      if (_recurrence) {
        final dayOfMonth = int.tryParse(_dayCtrl.text) ?? _date.day;
        await client.post('/api/transactions/batch', data: {
          'transaction': {
            'accountId': _selectedAccountId,
            'date': dateStr,
            'amount': amount,
            'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            'status': status,
            'isAuto': _isAuto,
          },
          'recurrence': {'dayOfMonth': dayOfMonth},
        });
      } else {
        await client.post('/api/transactions', data: {
          'accountId': _selectedAccountId,
          'date': dateStr,
          'amount': amount,
          'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          'status': status,
          'isAuto': _isAuto,
        });
      }

      ref.invalidate(dashboardDataProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_recurrence
                ? '$_occurrences transaction(s) créée(s)'
                : 'Transaction créée'),
            backgroundColor: AppColors.neonEmerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() { _error = 'Erreur lors de la création'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: EdgeInsets.all(MediaQuery.of(context).size.width < 500 ? 20 : 28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nouvelle transaction', style: AppTextStyles.title),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Compte
              accountsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Erreur de chargement des comptes',
                    style: TextStyle(color: AppColors.softRed)),
                data: (accounts) {
                  final grouped = _groupAccounts(accounts);
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedAccountId,
                    dropdownColor: AppColors.surfaceElevated,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Compte'),
                    items: grouped,
                    onChanged: (v) => setState(() => _selectedAccountId = v),
                    validator: (v) => v == null ? 'Requis' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              // Date
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSecondary),
                  ),
                  child: Text(
                    DateFormat('dd MMMM yyyy', 'fr_FR').format(_date),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Montant
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Montant (CHF)',
                  prefixText: 'CHF ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requis';
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  if (n == null || n <= 0) return 'Montant invalide';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Note
              TextFormField(
                controller: _noteCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Note (optionnel)'),
                maxLength: 500,
              ),
              const SizedBox(height: 8),

              // Switches
              _SwitchRow(
                label: 'Prélèvement automatique',
                value: _isAuto,
                onChanged: (v) => setState(() => _isAuto = v),
              ),
              _SwitchRow(
                label: 'Déjà payé',
                value: _isPaid,
                onChanged: (v) => setState(() => _isPaid = v),
              ),
              _SwitchRow(
                label: 'Répéter jusqu\'en Décembre',
                value: _recurrence,
                onChanged: (v) => setState(() => _recurrence = v),
                color: AppColors.coolPurple,
              ),

              // Jour du mois (si récurrence)
              if (_recurrence) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dayCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Jour du mois (1–31)'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1 || n > 31) return 'Entre 1 et 31';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '$_occurrences transaction(s) seront créées',
                  style: const TextStyle(color: AppColors.coolPurple, fontSize: 13),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.softRed, fontSize: 13)),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_recurrence
                          ? 'Créer $_occurrences transaction(s)'
                          : 'Créer la transaction'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _groupAccounts(List<Account> accounts) {
    final items = <DropdownMenuItem<String>>[];
    final groups = <String>{};
    for (final a in accounts) {
      groups.add(a.group);
    }
    for (final group in groups) {
      items.add(DropdownMenuItem(
        enabled: false,
        value: '_header_$group',
        child: Text(group.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textDisabled,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            )),
      ));
      for (final a in accounts.where((a) => a.group == group)) {
        items.add(DropdownMenuItem(
          value: a.id,
          child: Row(
            children: [
              Icon(
                a.isIncome ? Icons.trending_up : Icons.trending_down,
                size: 16,
                color: a.isIncome ? AppColors.neonEmerald : AppColors.softRed,
              ),
              const SizedBox(width: 8),
              Text(a.name, style: const TextStyle(color: AppColors.textPrimary)),
            ],
          ),
        ));
      }
    }
    return items;
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.color = AppColors.electricBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        Switch(
          value: value,
          activeThumbColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
