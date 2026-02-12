import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/core/theme/app_text_styles.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/accounts/providers/accounts_provider.dart';
import 'package:solver/features/dashboard/providers/dashboard_provider.dart';

void showAccountFormModal(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (_) => UncontrolledProviderScope(container: ProviderScope.containerOf(context), child: const _AccountFormDialog()),
  );
}

class _AccountFormDialog extends ConsumerStatefulWidget {
  const _AccountFormDialog();

  @override
  ConsumerState<_AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends ConsumerState<_AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();
  String _type = 'expense';
  bool _isFixed = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _groupCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final client = ref.read(apiClientProvider);
      await client.post('/api/accounts', data: {
        'name': _nameCtrl.text.trim(),
        'type': _type == 'income' ? 0 : 1,
        'group': _groupCtrl.text.trim(),
        'isFixed': _isFixed,
        'budget': 0,
      });

      ref.invalidate(accountsProvider);
      ref.invalidate(dashboardDataProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _error = 'Erreur lors de la création'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceDialog,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
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
                    const Text('Nouveau compte', style: AppTextStyles.title),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Nom
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Nom du compte'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 16),

                // Groupe
                TextFormField(
                  controller: _groupCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Groupe (ex: Charges fixes)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 16),

                // Type
                const Text('Type', style: AppTextStyles.label),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _TypeChip(
                      label: 'Dépense',
                      selected: _type == 'expense',
                      color: AppColors.softRed,
                      onTap: () => setState(() => _type = 'expense'),
                    ),
                    _TypeChip(
                      label: 'Revenu',
                      selected: _type == 'income',
                      color: AppColors.neonEmerald,
                      onTap: () => setState(() => _type = 'income'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Fixe
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Montant fixe', style: TextStyle(color: AppColors.textSecondary)),
                    Switch(
                      value: _isFixed,
                      activeThumbColor: AppColors.electricBlue,
                      onChanged: (v) => setState(() => _isFixed = v),
                    ),
                  ],
                ),

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
                        : const Text('Créer le compte'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(40) : Colors.transparent,
          border: Border.all(color: selected ? color : AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: TextStyle(color: selected ? color : AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
