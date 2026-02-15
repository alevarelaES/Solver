class Category {
  final String id;
  final String name;
  final String type; // income|expense
  final String group;
  final String? groupId;
  final int sortOrder;
  final bool isArchived;

  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.group,
    required this.groupId,
    required this.sortOrder,
    required this.isArchived,
  });

  bool get isIncome => type == 'income';

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
      name: json['name'] as String? ?? 'Catégorie',
    type: (json['type'] as String? ?? 'expense').toLowerCase(),
    group: json['group'] as String? ?? 'Autres',
    groupId: json['groupId'] as String?,
    sortOrder: json['sortOrder'] as int? ?? 0,
    isArchived: json['isArchived'] as bool? ?? false,
  );
}
