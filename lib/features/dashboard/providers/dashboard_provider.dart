import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/dashboard/models/dashboard_data.dart';

final selectedYearProvider = StateProvider<int>((ref) => DateTime.now().year);

final dashboardDataProvider =
    FutureProvider.family<DashboardData, int>((ref, year) async {
  ref.keepAlive();
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>(
    '/api/dashboard',
    queryParameters: {'year': year},
  );
  return DashboardData.fromJson(response.data!);
});
