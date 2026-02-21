class Transaction {
  static const String _voidedTag = '[ANNULEE]';
  static const String _reimbursementTag = '[REMBOURSEMENT]';

  final String id;
  final String accountId;
  final String? accountName;
  final String? accountGroup;
  final String? accountType; // 'income' or 'expense'
  final String? categoryName;
  final String? categoryGroup;
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
    this.accountGroup,
    this.accountType,
    this.categoryName,
    this.categoryGroup,
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
  bool get isVoided => _hasTag(note, _voidedTag);
  bool get isReimbursement => _hasTag(note, _reimbursementTag);
  double get signedAmount => isIncome ? amount : -amount;

  String? get displayNote {
    final raw = (note ?? '').trim();
    if (raw.isEmpty) return null;
    var cleaned = raw;
    if (_hasTag(cleaned, _voidedTag)) {
      cleaned = cleaned.substring(_voidedTag.length).trimLeft();
    }
    if (_hasTag(cleaned, _reimbursementTag)) {
      cleaned = cleaned.substring(_reimbursementTag.length).trimLeft();
    }
    return cleaned.isEmpty ? null : cleaned;
  }

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    accountId: json['accountId'] as String,
    accountName: json['accountName'] as String?,
    accountGroup:
        (json['accountGroup'] ?? json['account_group'] ?? json['groupName'])
            as String?,
    accountType: json['accountType'] as String?,
    categoryName: (json['categoryName'] ?? json['category']) as String?,
    categoryGroup:
        (json['categoryGroup'] ?? json['groupName'] ?? json['group'])
            as String?,
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
    accountGroup: accountGroup,
    accountType: accountType,
    categoryName: categoryName,
    categoryGroup: categoryGroup,
    userId: userId,
    date: date,
    amount: amount ?? this.amount,
    note: note,
    status: status ?? this.status,
    isAuto: isAuto,
  );

  static bool _hasTag(String? value, String tag) {
    if (value == null) return false;
    return value.trimLeft().toUpperCase().startsWith(tag);
  }
}
