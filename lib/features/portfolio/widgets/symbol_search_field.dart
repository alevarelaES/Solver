import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/data/portfolio_symbol_catalog.dart';
import 'package:solver/features/portfolio/models/symbol_search_result.dart';
import 'package:solver/features/portfolio/providers/market_search_provider.dart';
import 'package:solver/shared/widgets/app_panel.dart';

class SymbolSearchField extends ConsumerStatefulWidget {
  final String label;
  final ValueChanged<SymbolSearchResult> onSelected;
  final ValueChanged<String>? onQueryChanged;

  const SymbolSearchField({
    super.key,
    required this.label,
    required this.onSelected,
    this.onQueryChanged,
  });

  @override
  ConsumerState<SymbolSearchField> createState() => _SymbolSearchFieldState();
}

class _SymbolSearchFieldState extends ConsumerState<SymbolSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    // Do NOT use ref here — Riverpod unbinds it before dispose() runs.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(symbolSearchProvider);
    final query = _controller.text.trim();
    final activeQuery = ref.watch(symbolSearchQueryProvider).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'Ex: ${symbolSearchHintSymbols.join(', ')}',
            suffixIcon: query.isEmpty
                ? const Icon(Icons.search)
                : IconButton(
                    onPressed: () {
                      _controller.clear();
                      ref.read(symbolSearchQueryProvider.notifier).state = '';
                      widget.onQueryChanged?.call('');
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
          onChanged: (value) {
            ref.read(symbolSearchQueryProvider.notifier).state = value;
            widget.onQueryChanged?.call(value);
            setState(() {});
          },
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Symbole ou nom requis';
            }
            return null;
          },
        ),
        if (activeQuery.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          resultsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, _) => Text(
              'Erreur de recherche: $error',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
            data: (results) {
              if (results.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: Text(
                    'Aucun actif trouve. Essayez un symbole ou un nom.',
                  ),
                );
              }

              return AppPanel(
                padding: EdgeInsets.zero,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final result = results[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          '${result.symbol} - ${result.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            result.exchange,
                            result.type,
                            result.country,
                          ].where((v) => (v ?? '').isNotEmpty).join(' | '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing:
                            result.lastPrice != null && result.lastPrice! > 0
                            ? Text(
                                result.lastPrice!.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                        onTap: () {
                          _controller.text = result.symbol;
                          ref.read(symbolSearchQueryProvider.notifier).state =
                              '';
                          widget.onQueryChanged?.call(result.symbol);
                          setState(() {});
                          widget.onSelected(result);
                        },
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
