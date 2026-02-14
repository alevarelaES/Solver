import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/categories/models/category.dart';
import 'package:solver/features/categories/models/category_group.dart';

final categoriesProvider = FutureProvider.family<List<Category>, bool>((
  ref,
  includeArchived,
) async {
  ref.keepAlive();
  final client = ref.watch(apiClientProvider);
  final response = await client.get<List<dynamic>>(
    '/api/categories',
    queryParameters: {'includeArchived': includeArchived},
  );
  return (response.data as List)
      .map((a) => Category.fromJson(a as Map<String, dynamic>))
      .toList();
});

final categoryGroupsProvider = FutureProvider.family<List<CategoryGroup>, bool>(
  (ref, includeArchived) async {
    ref.keepAlive();
    final client = ref.watch(apiClientProvider);
    try {
      final response = await client.get<List<dynamic>>(
        '/api/category-groups',
        queryParameters: {'includeArchived': includeArchived},
      );
      return (response.data as List)
          .map((a) => CategoryGroup.fromJson(a as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      // Backward compatibility: if backend route is not deployed yet,
      // derive virtual groups from existing categories.
      if (e.response?.statusCode != 404) rethrow;
      final categories = await ref.watch(
        categoriesProvider(includeArchived).future,
      );
      final byKey = <String, CategoryGroup>{};
      var i = 0;
      for (final c in categories) {
        final key = '${c.type.toLowerCase()}|${c.group.toLowerCase()}';
        byKey.putIfAbsent(
          key,
          () => CategoryGroup(
            id: 'legacy-$key',
            name: c.group,
            type: c.type,
            sortOrder: i++,
            isArchived: false,
          ),
        );
      }
      return byKey.values.toList()..sort((a, b) {
        final byType = a.type.compareTo(b.type);
        if (byType != 0) return byType;
        final bySort = a.sortOrder.compareTo(b.sortOrder);
        if (bySort != 0) return bySort;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }
  },
);

final categoryApiProvider = Provider<CategoryApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return CategoryApi(client);
});

final categoryGroupApiProvider = Provider<CategoryGroupApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return CategoryGroupApi(client);
});

class CategoryApi {
  final ApiClient _client;
  CategoryApi(this._client);

  Future<Category> create({
    required String name,
    required String type,
    String? groupId,
    String? group,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/categories',
      data: {
        'name': name,
        'type': type == 'income' ? 0 : 1,
        'groupId': groupId,
        'group': group,
      },
    );
    return Category.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> update({
    required String id,
    required String name,
    required String type,
    String? groupId,
    String? group,
  }) async {
    await _client.put<Map<String, dynamic>>(
      '/api/categories/$id',
      data: {
        'name': name,
        'type': type == 'income' ? 0 : 1,
        'groupId': groupId,
        'group': group,
      },
    );
  }

  Future<void> archive(String id, bool isArchived) async {
    await _client.patch<Map<String, dynamic>>(
      '/api/categories/$id/archive',
      data: {'isArchived': isArchived},
    );
  }

  Future<void> reorder(List<Category> categories) async {
    await _client.patch<Map<String, dynamic>>(
      '/api/categories/reorder',
      data: {
        'items': List.generate(categories.length, (i) {
          return {'categoryId': categories[i].id, 'sortOrder': i};
        }),
      },
    );
  }
}

class CategoryGroupApi {
  final ApiClient _client;
  CategoryGroupApi(this._client);

  Future<CategoryGroup> create({
    required String name,
    required String type,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/category-groups',
      data: {'name': name, 'type': type == 'income' ? 0 : 1},
    );
    return CategoryGroup.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> rename({required String id, required String name}) async {
    await _client.put<Map<String, dynamic>>(
      '/api/category-groups/$id',
      data: {'name': name},
    );
  }

  Future<void> archive(String id, bool isArchived) async {
    await _client.patch<Map<String, dynamic>>(
      '/api/category-groups/$id/archive',
      data: {'isArchived': isArchived},
    );
  }

  Future<void> reorder(List<CategoryGroup> groups) async {
    await _client.patch<Map<String, dynamic>>(
      '/api/category-groups/reorder',
      data: {
        'items': List.generate(groups.length, (i) {
          return {'groupId': groups[i].id, 'sortOrder': i};
        }),
      },
    );
  }
}
