import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/features/portfolio/models/symbol_search_result.dart';
import 'package:solver/features/portfolio/providers/portfolio_provider.dart';
import 'package:solver/features/portfolio/services/portfolio_transaction_bridge.dart';
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
  final _investedAmountCtrl = TextEditingController();
  final _buyPriceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  SymbolSearchResult? _selectedSymbol;
  String _symbolQuery = '';
  String _manualAssetType = 'stock';
  DateTime? _buyDate;
  bool _showAdvanced = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _investedAmountCtrl.dispose();
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

    final buyPriceRaw = _buyPriceCtrl.text.trim();
    final buyPrice = _parseDouble(buyPriceRaw);

    if (buyPriceRaw.isNotEmpty && (buyPrice == null || buyPrice <= 0)) {
      setState(() => _error = 'Prix d achat invalide.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final resolvedSelection =
          selected ?? await _resolveManualSelection(manualSymbol);
      final resolvedSymbol =
          resolvedSelection?.symbol.trim().toUpperCase() ?? manualSymbol;
      final resolvedName = resolvedSelection?.name.trim().isNotEmpty == true
          ? resolvedSelection!.name.trim()
          : resolvedSymbol;
      final resolvedAssetType = resolvedSelection != null
          ? _normalizeAssetType(resolvedSelection.type)
          : _manualAssetType;
      final quantity = await _resolveQuantityFromAmount(
        symbol: resolvedSymbol,
        buyPrice: buyPrice,
        preferredMarketPrice: resolvedSelection?.lastPrice,
      );
      if (quantity == null || quantity <= 0) {
        setState(() {
          _submitting = false;
          _error ??= 'Impossible de calculer une quantite valide.';
        });
        return;
      }
      final mutation = ref.read(portfolioMutationsProvider);
      final existing = await _findExistingHoldingBySymbol(resolvedSymbol);
      final entryAverageBuyPrice = _resolveAverageBuyPrice(quantity, buyPrice);
      final incomingNotes = _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim();

      if (existing != null) {
        final previousQuantity = existing.quantity;
        final previousAvg = existing.averageBuyPrice ?? entryAverageBuyPrice;
        final mergedQuantity = previousQuantity + quantity;
        final mergedAvg = previousAvg != null && entryAverageBuyPrice != null
            ? ((previousAvg * previousQuantity) +
                      (entryAverageBuyPrice * quantity)) /
                  mergedQuantity
            : (existing.averageBuyPrice ?? entryAverageBuyPrice);

        await mutation.updateHolding(
          existing.id,
          UpdateHoldingRequest(
            name: existing.name ?? resolvedName,
            quantity: mergedQuantity,
            averageBuyPrice: mergedAvg,
            buyDate: _buyDate ?? existing.buyDate,
            notes: incomingNotes ?? existing.notes,
          ),
        );
      } else {
        await mutation.addHolding(
          AddHoldingRequest(
            symbol: resolvedSymbol,
            exchange: resolvedSelection?.exchange,
            name: resolvedName,
            assetType: resolvedAssetType,
            quantity: quantity,
            averageBuyPrice: entryAverageBuyPrice,
            buyDate: _buyDate,
            currency: 'USD',
            notes: incomingNotes,
          ),
        );
      }

      final investedAmount = _parseDouble(_investedAmountCtrl.text) ?? 0;
      try {
        await PortfolioTransactionBridge.recordTrade(
          ref: ref,
          tradeType: PortfolioTradeType.buy,
          symbol: resolvedSymbol,
          amount: investedAmount,
          tradeDate: _buyDate,
          note: incomingNotes,
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Position ajoutee, mais transaction finance non creee.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

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

  Future<double?> _resolveQuantityFromAmount({
    required String symbol,
    required double? buyPrice,
    double? preferredMarketPrice,
  }) async {
    final invested = _parseDouble(_investedAmountCtrl.text);
    if (invested == null || invested <= 0) {
      setState(() => _error = 'Montant investi invalide.');
      return null;
    }

    final entryPrice =
        buyPrice ??
        preferredMarketPrice ??
        _selectedSymbol?.lastPrice ??
        await _loadCurrentMarketPrice(symbol);
    if (entryPrice == null || entryPrice <= 0) {
      setState(() {
        _error =
            'Prix live indisponible. Ajoute un prix d entree (optionnel) pour continuer.';
      });
      return null;
    }

    return invested / entryPrice;
  }

  double? _resolveAverageBuyPrice(double quantity, double? buyPrice) {
    if (buyPrice != null && buyPrice > 0) return buyPrice;
    final invested = _parseDouble(_investedAmountCtrl.text);
    if (invested == null || invested <= 0 || quantity <= 0) return null;
    return invested / quantity;
  }

  Future<double?> _loadCurrentMarketPrice(String symbol) async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get<Map<String, dynamic>>(
        '/api/market/quote',
        queryParameters: {'symbols': symbol},
      );
      final quoteMap =
          response.data?['quotes'] as Map<String, dynamic>? ?? const {};

      Map<String, dynamic>? payload;
      for (final entry in quoteMap.entries) {
        if (entry.key.toUpperCase() != symbol.toUpperCase()) continue;
        if (entry.value is Map<String, dynamic>) {
          payload = entry.value as Map<String, dynamic>;
          break;
        }
      }
      if (payload == null && quoteMap.isNotEmpty) {
        final first = quoteMap.values.first;
        if (first is Map<String, dynamic>) {
          payload = first;
        }
      }

      final price = _parseDouble(payload?['price']);
      if (price != null && price > 0) return price;
    } catch (_) {
      // Ignore and fallback to manual buy price requirement.
    }
    return null;
  }

  Future<SymbolSearchResult?> _resolveManualSelection(String symbol) async {
    final normalized = symbol.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    try {
      final client = ref.read(apiClientProvider);
      final searchResponse = await client.get<Map<String, dynamic>>(
        '/api/market/search',
        queryParameters: {'q': normalized, 'limit': 20},
      );
      final raw = searchResponse.data?['results'] as List<dynamic>? ?? const [];
      final results = raw
          .whereType<Map<String, dynamic>>()
          .map(SymbolSearchResult.fromJson)
          .toList();
      if (results.isEmpty) return null;

      SymbolSearchResult best = results.first;
      for (final item in results) {
        if (item.symbol.trim().toUpperCase() == normalized) {
          best = item;
          break;
        }
      }

      final quote = await _loadCurrentMarketPrice(best.symbol);
      return best.copyWith(lastPrice: quote);
    } catch (_) {
      return null;
    }
  }

  Future<Holding?> _findExistingHoldingBySymbol(String symbol) async {
    Holding? pickFrom(List<Holding> holdings) {
      for (final holding in holdings) {
        if (holding.symbol.toUpperCase() == symbol.toUpperCase() &&
            !holding.isArchived &&
            holding.quantity > 0) {
          return holding;
        }
      }
      return null;
    }

    final cached = ref.read(portfolioProvider).valueOrNull;
    if (cached != null) {
      final found = pickFrom(cached.holdings);
      if (found != null) return found;
    }

    try {
      final loaded = await ref.read(portfolioProvider.future);
      return pickFrom(loaded.holdings);
    } catch (_) {
      return null;
    }
  }

  double? _parseDouble(String? raw) {
    final normalized = (raw ?? '').trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
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
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Entrez juste le montant investi. Le reste est calcule automatiquement.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              SymbolSearchField(
                label: 'Recherche symbole ou nom',
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
              if (_selectedSymbol == null &&
                  _symbolQuery.trim().isNotEmpty) ...[
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
              ],
              TextFormField(
                controller: _investedAmountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Montant investi',
                  helperText: 'Ex: 300 = 300 CHF investis',
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final parsed = _parseDouble(value);
                  if (parsed == null || parsed <= 0) {
                    return 'Montant investi requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => _showAdvanced = !_showAdvanced);
                  },
                  icon: Icon(
                    _showAdvanced
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                  ),
                  label: Text(
                    _showAdvanced
                        ? 'Masquer options avancees'
                        : 'Options avancees',
                  ),
                ),
              ),
              if (_showAdvanced) ...[
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _buyPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Prix d entree (optionnel)',
                    helperText:
                        'Laisse vide: on utilise le prix actuel automatiquement.',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if ((_selectedSymbol?.lastPrice ?? 0) > 0 &&
                    _buyPriceCtrl.text.trim().isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'Prix actuel detecte: ${_selectedSymbol!.lastPrice!.toStringAsFixed(2)} ${_selectedSymbol!.currency ?? ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                if (_parseDouble(_investedAmountCtrl.text) != null &&
                    (_parseDouble(_buyPriceCtrl.text) ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'Quantite estimee: ${(_parseDouble(_investedAmountCtrl.text)! / _parseDouble(_buyPriceCtrl.text)!).toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12),
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
              ],
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
