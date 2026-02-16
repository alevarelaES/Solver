import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/portfolio/models/company_profile.dart';

final companyProfileProvider = FutureProvider.family
    .autoDispose<CompanyProfile?, String>((ref, symbol) async {
      final normalized = symbol.trim().toUpperCase();
      if (normalized.isEmpty) return null;

      final client = ref.read(apiClientProvider);
      try {
        final response = await client.get<Map<String, dynamic>>(
          '/api/market/profile/$normalized',
        );
        final payload = response.data;
        if (payload == null) return null;
        return CompanyProfile.fromJson(payload);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) return null;
        rethrow;
      }
    });
