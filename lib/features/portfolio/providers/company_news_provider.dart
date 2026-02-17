import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/portfolio/models/analyst_recommendation.dart';
import 'package:solver/features/portfolio/models/company_news.dart';

final companyNewsProvider = FutureProvider.family
    .autoDispose<List<CompanyNews>, String>((ref, symbol) async {
      final normalized = symbol.trim().toUpperCase();
      if (normalized.isEmpty || normalized.contains('/')) return const [];

      final client = ref.read(apiClientProvider);
      final response = await client.get<Map<String, dynamic>>(
        '/api/market/news/${Uri.encodeComponent(normalized)}',
      );

      final list = response.data?['news'] as List<dynamic>? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(CompanyNews.fromJson)
          .toList();
    });

final analystRecommendationsProvider = FutureProvider.family
    .autoDispose<List<AnalystRecommendation>, String>((ref, symbol) async {
      final normalized = symbol.trim().toUpperCase();
      if (normalized.isEmpty || normalized.contains('/')) return const [];

      final client = ref.read(apiClientProvider);
      final response = await client.get<Map<String, dynamic>>(
        '/api/market/recommendations/${Uri.encodeComponent(normalized)}',
      );

      final list =
          response.data?['recommendations'] as List<dynamic>? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(AnalystRecommendation.fromJson)
          .toList();
    });
