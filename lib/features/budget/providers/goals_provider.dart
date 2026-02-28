import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';

class SavingGoal {
  final String id;
  final String name;
  final String goalType;
  final double targetAmount;
  final DateTime targetDate;
  final double initialAmount;
  final double monthlyContribution;
  final bool autoContributionEnabled;
  final DateTime? autoContributionStartDate;
  final int priority;
  final bool isArchived;
  final double currentAmount;
  final double remainingAmount;
  final double recommendedMonthly;
  final double progressPercent;
  final int monthsRemaining;
  final DateTime? projectedDate;
  final String status;

  const SavingGoal({
    required this.id,
    required this.name,
    required this.goalType,
    required this.targetAmount,
    required this.targetDate,
    required this.initialAmount,
    required this.monthlyContribution,
    required this.autoContributionEnabled,
    required this.autoContributionStartDate,
    required this.priority,
    required this.isArchived,
    required this.currentAmount,
    required this.remainingAmount,
    required this.recommendedMonthly,
    required this.progressPercent,
    required this.monthsRemaining,
    required this.projectedDate,
    required this.status,
  });

  factory SavingGoal.fromJson(Map<String, dynamic> json) => SavingGoal(
    id: json['id'] as String,
    name: json['name'] as String,
    goalType: (json['goalType'] as String?) ?? 'savings',
    targetAmount: (json['targetAmount'] as num).toDouble(),
    targetDate: DateTime.parse(json['targetDate'] as String),
    initialAmount: (json['initialAmount'] as num).toDouble(),
    monthlyContribution: (json['monthlyContribution'] as num).toDouble(),
    autoContributionEnabled:
        (json['autoContributionEnabled'] as bool?) ?? false,
    autoContributionStartDate: json['autoContributionStartDate'] == null
        ? null
        : DateTime.parse(json['autoContributionStartDate'] as String),
    priority: (json['priority'] as num).toInt(),
    isArchived: json['isArchived'] as bool,
    currentAmount: (json['currentAmount'] as num).toDouble(),
    remainingAmount: (json['remainingAmount'] as num).toDouble(),
    recommendedMonthly: (json['recommendedMonthly'] as num).toDouble(),
    progressPercent: (json['progressPercent'] as num).toDouble(),
    monthsRemaining: (json['monthsRemaining'] as num).toInt(),
    projectedDate: json['projectedDate'] == null
        ? null
        : DateTime.parse(json['projectedDate'] as String),
    status: json['status'] as String,
  );
}

class SavingGoalEntry {
  final String id;
  final String goalId;
  final DateTime entryDate;
  final double amount;
  final String? note;
  final bool isAuto;
  final DateTime createdAt;

  const SavingGoalEntry({
    required this.id,
    required this.goalId,
    required this.entryDate,
    required this.amount,
    required this.note,
    required this.isAuto,
    required this.createdAt,
  });

  factory SavingGoalEntry.fromJson(Map<String, dynamic> json) =>
      SavingGoalEntry(
        id: json['id'] as String,
        goalId: json['goalId'] as String,
        entryDate: DateTime.parse(json['entryDate'] as String),
        amount: (json['amount'] as num).toDouble(),
        note: json['note'] as String?,
        isAuto: json['isAuto'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

String _formatDateOnly(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

class GoalsApi {
  final ApiClient _client;

  const GoalsApi(this._client);

  Future<List<SavingGoal>> fetchGoals({bool includeArchived = false}) async {
    final response = await _client.get<List<dynamic>>(
      '/api/goals',
      queryParameters: {'includeArchived': includeArchived},
    );
    return (response.data as List)
        .map((g) => SavingGoal.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  Future<void> createGoal({
    required String name,
    required String goalType,
    required double targetAmount,
    required DateTime targetDate,
    required double initialAmount,
    required double monthlyContribution,
    bool autoContributionEnabled = false,
    DateTime? autoContributionStartDate,
    int? priority,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/goals',
      data: {
        'name': name,
        'goalType': goalType,
        'targetAmount': targetAmount,
        'targetDate': _formatDateOnly(targetDate),
        'initialAmount': initialAmount,
        'monthlyContribution': monthlyContribution,
        'autoContributionEnabled': autoContributionEnabled,
        'autoContributionStartDate': autoContributionStartDate == null
            ? null
            : _formatDateOnly(autoContributionStartDate),
        'priority': priority,
      },
    );
  }

  Future<void> updateGoal({
    required String id,
    required String name,
    required String goalType,
    required double targetAmount,
    required DateTime targetDate,
    required double initialAmount,
    required double monthlyContribution,
    bool autoContributionEnabled = false,
    DateTime? autoContributionStartDate,
    required int priority,
  }) async {
    await _client.put<Map<String, dynamic>>(
      '/api/goals/$id',
      data: {
        'name': name,
        'goalType': goalType,
        'targetAmount': targetAmount,
        'targetDate': _formatDateOnly(targetDate),
        'initialAmount': initialAmount,
        'monthlyContribution': monthlyContribution,
        'autoContributionEnabled': autoContributionEnabled,
        'autoContributionStartDate': autoContributionStartDate == null
            ? null
            : _formatDateOnly(autoContributionStartDate),
        'priority': priority,
      },
    );
  }

  Future<void> archiveGoal({
    required String id,
    required bool isArchived,
  }) async {
    await _client.patch<Map<String, dynamic>>(
      '/api/goals/$id/archive',
      data: {'isArchived': isArchived},
    );
  }

  Future<void> deleteGoal(String id) async {
    await _client.delete<Map<String, dynamic>>('/api/goals/$id');
  }

  Future<List<SavingGoalEntry>> fetchEntries(String goalId) async {
    final response = await _client.get<List<dynamic>>(
      '/api/goals/$goalId/entries',
    );
    return (response.data as List)
        .map((e) => SavingGoalEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addEntry({
    required String goalId,
    required double amount,
    DateTime? entryDate,
    String? note,
    bool isAuto = false,
  }) async {
    final effectiveDate = entryDate ?? DateTime.now();
    await _client.post<Map<String, dynamic>>(
      '/api/goals/$goalId/entries',
      data: {
        'amount': amount,
        'entryDate': _formatDateOnly(effectiveDate),
        'note': note,
        'isAuto': isAuto,
      },
    );
  }
}

final goalsApiProvider = Provider<GoalsApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return GoalsApi(client);
});

final goalsProvider = FutureProvider<List<SavingGoal>>((ref) async {
  final api = ref.watch(goalsApiProvider);
  return api.fetchGoals(includeArchived: true);
});

final goalEntriesProvider =
    FutureProvider.family<List<SavingGoalEntry>, String>((ref, goalId) async {
      final api = ref.watch(goalsApiProvider);
      return api.fetchEntries(goalId);
    });
