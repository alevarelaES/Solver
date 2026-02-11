import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/accounts/models/account.dart';

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<List<dynamic>>('/api/accounts');
  return (response.data as List)
      .map((a) => Account.fromJson(a as Map<String, dynamic>))
      .toList();
});
