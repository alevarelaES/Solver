import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/portfolio/models/portfolio_summary.dart';

const _portfolioRefreshInterval = Duration(minutes: 5);

final portfolioProvider = FutureProvider.autoDispose<PortfolioData>((
  ref,
) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>('/api/portfolio/');

  // Re-fetch automatically while the portfolio page is open.
  final timer = Timer(_portfolioRefreshInterval, () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);

  return PortfolioData.fromJson(response.data ?? const {});
});

final portfolioMutationsProvider = Provider<PortfolioMutations>(
  (ref) => PortfolioMutations(ref),
);

class PortfolioMutations {
  final Ref _ref;

  const PortfolioMutations(this._ref);

  Future<void> addHolding(AddHoldingRequest request) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/api/portfolio/', data: request.toJson());
    _ref.invalidate(portfolioProvider);
  }

  Future<void> updateHolding(String id, UpdateHoldingRequest request) async {
    final client = _ref.read(apiClientProvider);
    await client.put('/api/portfolio/$id', data: request.toJson());
    _ref.invalidate(portfolioProvider);
  }

  Future<void> deleteHolding(String id) async {
    final client = _ref.read(apiClientProvider);
    await client.delete('/api/portfolio/$id');
    _ref.invalidate(portfolioProvider);
  }

  Future<void> setHoldingArchived(String id, bool isArchived) async {
    final client = _ref.read(apiClientProvider);
    await client.patch(
      '/api/portfolio/$id/archive',
      data: {'isArchived': isArchived},
    );
    _ref.invalidate(portfolioProvider);
  }
}

class AddHoldingRequest {
  final String symbol;
  final String? exchange;
  final String? name;
  final String assetType;
  final double quantity;
  final double? averageBuyPrice;
  final DateTime? buyDate;
  final String? currency;
  final String? notes;

  const AddHoldingRequest({
    required this.symbol,
    required this.exchange,
    required this.name,
    required this.assetType,
    required this.quantity,
    required this.averageBuyPrice,
    required this.buyDate,
    required this.currency,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'exchange': exchange,
    'name': name,
    'assetType': assetType,
    'quantity': quantity,
    'averageBuyPrice': averageBuyPrice,
    'buyDate': buyDate == null ? null : _formatDateOnly(buyDate!),
    'currency': currency,
    'notes': notes,
  };
}

class UpdateHoldingRequest {
  final String? name;
  final double quantity;
  final double? averageBuyPrice;
  final DateTime? buyDate;
  final String? notes;

  const UpdateHoldingRequest({
    required this.name,
    required this.quantity,
    required this.averageBuyPrice,
    required this.buyDate,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'averageBuyPrice': averageBuyPrice,
    'buyDate': buyDate == null ? null : _formatDateOnly(buyDate!),
    'notes': notes,
  };
}

String _formatDateOnly(DateTime value) =>
    value.toIso8601String().split('T').first;
