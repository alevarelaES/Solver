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

  factory Account.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'];
    final parsedType = switch (rawType) {
      'income' || 'Income' || 0 => 'income',
      'expense' || 'Expense' || 1 => 'expense',
      _ => 'expense',
    };

    return Account(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Compte',
      type: parsedType,
      group: json['group'] as String? ?? 'Autres',
      isFixed: json['isFixed'] as bool? ?? false,
      budget: (json['budget'] as num?)?.toDouble() ?? 0,
    );
  }
}
