class Account {
  final String id;
  final String name;
  final String type; // 'income' or 'expense'
  final String group;
  final bool isFixed;
  final double budget;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.group,
    required this.isFixed,
    required this.budget,
  });

  bool get isIncome => type == 'income';

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        name: json['name'] as String,
        type: (json['type'] as String).toLowerCase(),
        group: json['group'] as String,
        isFixed: json['isFixed'] as bool,
        budget: (json['budget'] as num).toDouble(),
      );
}
