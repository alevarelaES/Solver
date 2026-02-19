import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/portfolio/models/symbol_search_result.dart';

final symbolSearchQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final symbolSearchProvider =
    FutureProvider.autoDispose<List<SymbolSearchResult>>((ref) async {
      final query = ref.watch(symbolSearchQueryProvider).trim();
      if (query.length < 2) return const [];

      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (ref.read(symbolSearchQueryProvider).trim() != query) {
        return const [];
      }

      final client = ref.read(apiClientProvider);
      final response = await client.get<Map<String, dynamic>>(
        '/api/market/search',
        queryParameters: {'q': query, 'limit': 100},
      );

      final list = response.data?['results'] as List<dynamic>? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(SymbolSearchResult.fromJson)
          .toList();
    });
