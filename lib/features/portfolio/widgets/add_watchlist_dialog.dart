import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/features/portfolio/models/symbol_search_result.dart';
import 'package:solver/features/portfolio/providers/watchlist_provider.dart';
import 'package:solver/features/portfolio/widgets/symbol_search_field.dart';

Future<bool> showAddWatchlistDialog(BuildContext context) async {
  final created = await showDialog<bool>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 540),
        child: const AddWatchlistDialog(),
      ),
    ),
  );

  return created ?? false;
}

class AddWatchlistDialog extends ConsumerStatefulWidget {
  const AddWatchlistDialog({super.key});

  @override
  ConsumerState<AddWatchlistDialog> createState() => _AddWatchlistDialogState();
}

class _AddWatchlistDialogState extends ConsumerState<AddWatchlistDialog> {
  SymbolSearchResult? _selectedSymbol;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    final selected = _selectedSymbol;
    if (selected == null) {
      setState(() => _error = 'Selectionnez un symbole depuis la liste.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(watchlistMutationsProvider)
          .add(
            AddWatchlistRequest(
              symbol: selected.symbol,
              exchange: selected.exchange,
              name: selected.name,
              assetType: _normalizeAssetType(selected.type),
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
        _error = 'Erreur lors de l ajout dans la watchlist.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ajouter a la watchlist',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          SymbolSearchField(
            label: 'Recherche symbole',
            onSelected: (symbol) {
              setState(() {
                _selectedSymbol = symbol;
                _error = null;
              });
            },
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
    return 'Erreur lors de l ajout dans la watchlist.';
  }
}
