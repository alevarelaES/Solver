import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:solver/core/config/app_config.dart';

// Single instance — token is injected dynamically via interceptor at request time
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  final Dio _dio;

  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            headers: {'Content-Type': 'application/json'},
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 60),
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Always read the freshest token right before sending
          final token =
              Supabase.instance.client.auth.currentSession?.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.get<T>(path, queryParameters: queryParameters);

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _dio.post<T>(path, data: data);

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _dio.put<T>(path, data: data);

  Future<Response<T>> patch<T>(String path, {dynamic data}) =>
      _dio.patch<T>(path, data: data);

  Future<Response<T>> delete<T>(String path) => _dio.delete<T>(path);
}
