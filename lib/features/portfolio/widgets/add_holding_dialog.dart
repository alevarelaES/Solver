import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solver/features/portfolio/models/symbol_search_result.dart';
import 'package:solver/features/portfolio/providers/portfolio_provider.dart';
import 'package:solver/features/portfolio/widgets/symbol_search_field.dart';

Future<bool> showAddHoldingDialog(BuildContext context) async {
  final created = await showDialog<bool>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560),
        child: const AddHoldingDialog(),
      ),
    ),
  );

  return created ?? false;
}

class AddHoldingDialog extends ConsumerStatefulWidget {
  const AddHoldingDialog({super.key});

  @override
  ConsumerState<AddHoldingDialog> createState() => _AddHoldingDialogState();
}

class _AddHoldingDialogState extends ConsumerState<AddHoldingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityCtrl = TextEditingController();
  final _buyPriceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  SymbolSearchResult? _selectedSymbol;
  String _symbolQuery = '';
  String _manualAssetType = 'stock';
  DateTime? _buyDate;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _buyPriceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final selected = _selectedSymbol;
    final manualSymbol = _symbolQuery.trim().toUpperCase();
    if (selected == null && manualSymbol.isEmpty) {
      setState(
        () => _error =
            'Saisissez un symbole ou selectionnez-en un dans la liste.',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final quantity = double.tryParse(_quantityCtrl.text.replaceAll(',', '.'));
    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'Quantite invalide.');
      return;
    }

    final buyPriceRaw = _buyPriceCtrl.text.trim();
    final buyPrice = buyPriceRaw.isEmpty
        ? null
        : double.tryParse(buyPriceRaw.replaceAll(',', '.'));

    if (buyPriceRaw.isNotEmpty && (buyPrice == null || buyPrice <= 0)) {
      setState(() => _error = 'Prix moyen invalide.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final resolvedSymbol =
          selected?.symbol.trim().toUpperCase() ?? manualSymbol;
      final resolvedName = selected?.name.trim().isNotEmpty == true
          ? selected!.name.trim()
          : resolvedSymbol;
      final resolvedAssetType = selected != null
          ? _normalizeAssetType(selected.type)
          : _manualAssetType;
      await ref
          .read(portfolioMutationsProvider)
          .addHolding(
            AddHoldingRequest(
              symbol: resolvedSymbol,
              exchange: selected?.exchange,
              name: resolvedName,
              assetType: resolvedAssetType,
              quantity: quantity,
              averageBuyPrice: buyPrice,
              buyDate: _buyDate,
              currency: 'USD',
              notes: _notesCtrl.text.trim().isEmpty
                  ? null
                  : _notesCtrl.text.trim(),
            ),
          );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() {
        _submitting = false;
        _error = _extractApiError(e.response?.data);
      });
    } catch (_) {
      setState(() {
        _submitting = false;
        _error = 'Erreur lors de la creation de la position.';
      });
    }
  }

  Future<void> _pickBuyDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _buyDate ?? now,
      firstDate: DateTime(1980, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );

    if (picked != null) {
      setState(() => _buyDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ajouter une position',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              SymbolSearchField(
                label: 'Recherche symbole',
                onSelected: (symbol) {
                  setState(() {
                    _selectedSymbol = symbol;
                    _symbolQuery = symbol.symbol;
                    _error = null;
                  });
                },
                onQueryChanged: (value) {
                  final normalized = value.trim().toUpperCase();
                  setState(() {
                    _symbolQuery = value;
                    if (_selectedSymbol != null &&
                        normalized != _selectedSymbol!.symbol.toUpperCase()) {
                      _selectedSymbol = null;
                    }
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _manualAssetType,
                decoration: const InputDecoration(
                  labelText: 'Type actif (si saisie manuelle)',
                ),
                items: const [
                  DropdownMenuItem(value: 'stock', child: Text('Action')),
                  DropdownMenuItem(value: 'etf', child: Text('ETF')),
                  DropdownMenuItem(value: 'crypto', child: Text('Crypto')),
                  DropdownMenuItem(value: 'forex', child: Text('Forex')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _manualAssetType = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(labelText: 'Quantite'),
                validator: (value) {
                  final parsed = double.tryParse(
                    (value ?? '').trim().replaceAll(',', '.'),
                  );
                  if (parsed == null || parsed <= 0) return 'Quantite requise';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _buyPriceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Prix achat moyen (optionnel)',
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickBuyDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date achat (optionnel)',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _buyDate == null
                        ? 'Non renseignee'
                        : DateFormat('dd/MM/yyyy').format(_buyDate!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes (optionnel)',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Ajouter'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _normalizeAssetType(String rawType) {
    final type = rawType.trim().toLowerCase();
    if (type.contains('etf')) return 'etf';
    if (type.contains('crypto') ||
        type.contains('digital') ||
        type.contains('coin') ||
        type.contains('token')) {
      return 'crypto';
    }
    if (type.contains('forex')) return 'forex';
    return 'stock';
  }

  String _extractApiError(dynamic payload) {
    if (payload is String && payload.trim().isNotEmpty) return payload;
    if (payload is Map<String, dynamic>) {
      final error = payload['error'];
      if (error is String && error.trim().isNotEmpty) return error;
      final detail = payload['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail;
    }
    return 'Erreur lors de la creation de la position.';
  }
}
