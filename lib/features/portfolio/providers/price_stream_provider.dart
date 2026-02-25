import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PriceUpdate {
  final String symbol;
  final double price;
  final DateTime timestampUtc;

  const PriceUpdate({
    required this.symbol,
    required this.price,
    required this.timestampUtc,
  });

  factory PriceUpdate.fromJson(Map<String, dynamic> json) {
    return PriceUpdate(
      symbol: (json['symbol'] ?? '').toString().toUpperCase(),
      price: _toDouble(json['price']) ?? 0,
      timestampUtc: _toDate(json['timestampUtc']) ?? DateTime.now().toUtc(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _toDate(dynamic value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}

final priceStreamProvider = StreamProvider.autoDispose.family<PriceUpdate, String>((
  ref,
  symbol,
) async* {
  final normalized = symbol.trim().toUpperCase();
  if (normalized.isEmpty) return;

  final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/market/stream')
      .replace(queryParameters: {'symbol': normalized});
  final token = Supabase.instance.client.auth.currentSession?.accessToken;

  final client = HttpClient();
  ref.onDispose(() {
    client.close(force: true);
  });

  final request = await client.getUrl(uri);
  request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
  if (token != null && token.isNotEmpty) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }

  final response = await request.close();
  if (response.statusCode >= 400) {
    final body = await utf8.decoder.bind(response).join();
    throw HttpException(
      'SSE stream failed (${response.statusCode}): $body',
      uri: uri,
    );
  }

  await for (final line
      in response.transform(utf8.decoder).transform(const LineSplitter())) {
    if (!line.startsWith('data:')) continue;

    final payload = line.substring(5).trim();
    if (payload.isEmpty) continue;

    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) continue;
    if (!decoded.containsKey('price')) continue;

    yield PriceUpdate.fromJson(decoded);
  }
});
