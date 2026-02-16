import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/portfolio/models/company_news.dart';
import 'package:solver/features/portfolio/models/trending_stock.dart';

final trendingProvider = FutureProvider.autoDispose<List<TrendingStock>>((
  ref,
) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>(
    '/api/market/trending',
  );
  final data = response.data;
  if (data == null) return [];
  final stocks = data['stocks'] as List<dynamic>? ?? [];
  return stocks
      .map((e) => TrendingStock.fromJson(e as Map<String, dynamic>))
      .toList();
});

final marketNewsProvider = FutureProvider.autoDispose<List<CompanyNews>>((
  ref,
) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>(
    '/api/market/news-general',
  );
  final data = response.data;
  if (data == null) return [];
  final news = data['news'] as List<dynamic>? ?? [];
  return news
      .map((e) => CompanyNews.fromJson(e as Map<String, dynamic>))
      .toList();
});
