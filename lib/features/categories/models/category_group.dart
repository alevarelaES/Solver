class CategoryGroup {
  final String id;
  final String name;
  final String type; // income|expense
  final int sortOrder;
  final bool isArchived;

  const CategoryGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.sortOrder,
    required this.isArchived,
  });

  bool get isIncome => type == 'income';

  factory CategoryGroup.fromJson(Map<String, dynamic> json) => CategoryGroup(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Groupe',
    type: (json['type'] as String? ?? 'expense').toLowerCase(),
    sortOrder: json['sortOrder'] as int? ?? 0,
    isArchived: json['isArchived'] as bool? ?? false,
  );
}
