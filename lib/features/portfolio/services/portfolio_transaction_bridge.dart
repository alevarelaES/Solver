import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/categories/models/category.dart';
import 'package:solver/features/categories/providers/categories_provider.dart';
import 'package:solver/features/transactions/providers/transaction_refresh.dart';

enum PortfolioTradeType { buy, sell }

class PortfolioTransactionBridge {
  static const String _investmentGroupName = 'Investissements';

  static Future<void> recordTrade({
    required WidgetRef ref,
    required PortfolioTradeType tradeType,
    required String symbol,
    required double amount,
    DateTime? tradeDate,
    String? note,
  }) async {
    if (amount <= 0) return;

    final categoryId = await _ensureInvestmentCategoryId(
      ref: ref,
      tradeType: tradeType,
      symbol: symbol,
    );
    final client = ref.read(apiClientProvider);
    await client.post(
      '/api/transactions',
      data: {
        'accountId': categoryId,
        'date': DateFormat(
          'yyyy-MM-dd',
        ).format((tradeDate ?? DateTime.now()).toLocal()),
        'amount': amount,
        'note':
            note ??
            (tradeType == PortfolioTradeType.buy
                ? 'Achat $symbol (Portfolio)'
                : 'Vente $symbol (Portfolio)'),
        'status': 0,
        'isAuto': false,
      },
    );

    invalidateAfterTransactionMutation(ref);
  }

  static Future<String> _ensureInvestmentCategoryId({
    required WidgetRef ref,
    required PortfolioTradeType tradeType,
    required String symbol,
  }) async {
    final normalizedSymbol = _normalize(symbol);
    final expectedType = tradeType == PortfolioTradeType.sell
        ? 'income'
        : 'expense';

    Future<Category?> resolveExisting() async {
      final categories = await _readCategories(ref);
      for (final category in categories) {
        if (category.isArchived) continue;
        if (category.type != expectedType) continue;
        if (_normalize(category.name) != normalizedSymbol) continue;
        if (_isInvestmentGroup(category.group)) return category;
      }
      return null;
    }

    final existing = await resolveExisting();
    if (existing != null) return existing.id;

    final categoryApi = ref.read(categoryApiProvider);
    try {
      final created = await categoryApi.create(
        name: symbol.trim().toUpperCase(),
        type: expectedType,
        group: _investmentGroupName,
      );
      ref.invalidate(categoriesProvider(false));
      ref.invalidate(categoriesProvider(true));
      return created.id;
    } on DioException {
      ref.invalidate(categoriesProvider(false));
      final resolvedAfterError = await resolveExisting();
      if (resolvedAfterError != null) return resolvedAfterError.id;
      rethrow;
    }
  }

  static Future<List<Category>> _readCategories(WidgetRef ref) async {
    final cached = ref.read(categoriesProvider(false)).valueOrNull;
    if (cached != null) return cached;
    return ref.read(categoriesProvider(false).future);
  }

  static bool _isInvestmentGroup(String group) {
    final normalized = _normalize(group);
    return normalized.contains('invest');
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
