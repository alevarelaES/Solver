class Transaction {
  final String id;
  final String accountId;
  final String? accountName;
  final String? accountType; // 'income' or 'expense'
  final String userId;
  final DateTime date;
  final double amount;
  final String? note;
  final String status; // 'completed' or 'pending'
  final bool isAuto;

  const Transaction({
    required this.id,
    required this.accountId,
    this.accountName,
    this.accountType,
    required this.userId,
    required this.date,
    required this.amount,
    required this.note,
    required this.status,
    required this.isAuto,
  });

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isIncome => accountType == 'income';

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        accountId: json['accountId'] as String,
        accountName: json['accountName'] as String?,
        accountType: json['accountType'] as String?,
        userId: json['userId'] as String,
        date: DateTime.parse(json['date'] as String),
        amount: (json['amount'] as num).toDouble(),
        note: json['note'] as String?,
        status: (json['status'] as String).toLowerCase(),
        isAuto: json['isAuto'] as bool,
      );

  Transaction copyWith({String? status, double? amount}) => Transaction(
        id: id,
        accountId: accountId,
        accountName: accountName,
        accountType: accountType,
        userId: userId,
        date: date,
        amount: amount ?? this.amount,
        note: note,
        status: status ?? this.status,
        isAuto: isAuto,
      );
}
