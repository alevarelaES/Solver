import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/core/theme/app_text_styles.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/dashboard/providers/recent_transactions_provider.dart';
import 'package:solver/features/categories/models/category.dart';
import 'package:solver/features/categories/models/category_group.dart';
import 'package:solver/features/categories/providers/categories_provider.dart';
import 'package:solver/features/categories/widgets/categories_manager_modal.dart';
import 'package:solver/features/transactions/providers/transaction_refresh.dart';

void showTransactionFormModal(
  BuildContext context,
  WidgetRef ref, {
  String? preselectedAccountId,
}) {
  final isDesktop = MediaQuery.of(context).size.width > 768;

  if (isDesktop) {
    showDialog(
      context: context,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: _TransactionFormDialog(
          preselectedAccountId: preselectedAccountId,
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: _TransactionFormSheet(
          preselectedAccountId: preselectedAccountId,
        ),
      ),
    );
  }
}

class _TransactionFormDialog extends StatelessWidget {
  final String? preselectedAccountId;
  const _TransactionFormDialog({this.preselectedAccountId});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceDialog,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: _TransactionForm(preselectedAccountId: preselectedAccountId),
      ),
    );
  }
}

class _TransactionFormSheet extends StatelessWidget {
  final String? preselectedAccountId;
  const _TransactionFormSheet({this.preselectedAccountId});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceDialog,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
        child: _TransactionForm(
          preselectedAccountId: preselectedAccountId,
          scrollController: controller,
        ),
      ),
    );
  }
}

class _TransactionForm extends ConsumerStatefulWidget {
  final String? preselectedAccountId;
  final ScrollController? scrollController;

  const _TransactionForm({this.preselectedAccountId, this.scrollController});

  @override
  ConsumerState<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<_TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _repaymentTotalCtrl = TextEditingController();

  String? _selectedAccountId;
  DateTime _date = DateTime.now();
  DateTime _recurrenceEndDate = DateTime(DateTime.now().year, 12, 31);
  bool _isPaid = true;
  bool _isAuto = false;
  bool _recurrence = false;
  bool _repaymentPlan = false;
  bool _loading = false;
  String? _error;
  _CategoryIdentity? _selectedCategoryIdentity;

  @override
  void initState() {
    super.initState();
    _selectedAccountId = widget.preselectedAccountId;
    _recurrenceEndDate = DateTime(_date.year, 12, 31);
    _repaymentTotalCtrl.text = '1000';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _repaymentTotalCtrl.dispose();
    super.dispose();
  }

  int get _occurrences {
    if (!_recurrence) return 1;
    final start = DateUtils.dateOnly(_date);
    final end = DateUtils.dateOnly(_effectiveRecurrenceEndDate);
    if (end.isBefore(start)) return 0;

    var count = 0;
    var cursor = DateTime(start.year, start.month, 1);
    while (!cursor.isAfter(DateTime(end.year, end.month, 1))) {
      final maxDay = DateUtils.getDaysInMonth(cursor.year, cursor.month);
      final day = math.min(start.day, maxDay);
      final candidate = DateTime(cursor.year, cursor.month, day);
      if (!candidate.isBefore(start) && !candidate.isAfter(end)) {
        count++;
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return count;
  }

  double? get _monthlyRepaymentAmount => _tryParseAmount(_amountCtrl.text);
  double? get _repaymentTotalAmount =>
      _tryParseAmount(_repaymentTotalCtrl.text);

  int get _repaymentInstallments {
    if (!_repaymentPlan) return 0;
    final monthly = _monthlyRepaymentAmount;
    final total = _repaymentTotalAmount;
    if (monthly == null || total == null || monthly <= 0 || total <= 0) {
      return 0;
    }
    return (total / monthly).ceil();
  }

  double get _repaymentLastInstallment {
    final installments = _repaymentInstallments;
    final monthly = _monthlyRepaymentAmount;
    final total = _repaymentTotalAmount;
    if (installments <= 0 || monthly == null || total == null) return 0;
    if (installments == 1) return total;
    final consumed = monthly * (installments - 1);
    final remaining = total - consumed;
    return remaining > 0 ? remaining : monthly;
  }

  DateTime? get _repaymentEndDate {
    final installments = _repaymentInstallments;
    if (installments <= 0) return null;
    return _shiftMonthKeepingDay(_date, installments - 1);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.electricBlue),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        if (_recurrence && _recurrenceEndDate.isBefore(_date)) {
          _recurrenceEndDate = _date;
        }
      });
    }
  }

  DateTime get _effectiveRecurrenceEndDate =>
      _recurrenceEndDate.isBefore(_date) ? _date : _recurrenceEndDate;

  Future<void> _pickRecurrenceEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveRecurrenceEndDate,
      firstDate: _date,
      lastDate: DateTime(2035, 12, 31),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.electricBlue),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _recurrenceEndDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_recurrence && _occurrences <= 0) {
      setState(() => _error = 'Date de fin invalide pour la repetition');
      return;
    }
    if (_repaymentPlan) {
      final total = _repaymentTotalAmount;
      final monthly = _monthlyRepaymentAmount;
      if (total == null || total <= 0) {
        setState(() => _error = 'Montant total a rembourser invalide');
        return;
      }
      if (monthly == null || monthly <= 0) {
        setState(() => _error = 'Mensualite invalide');
        return;
      }
    }
    final selectedAccountId = _selectedAccountId;
    if (selectedAccountId == null) {
      setState(() => _error = 'Selectionnez un compte');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final amount = double.parse(_amountCtrl.text.replaceAll(',', '.'));
      final dateStr = DateFormat('yyyy-MM-dd').format(_date);
      final status = _isPaid ? 0 : 1;
      var accountIdToUse = selectedAccountId;
      var createdCount = 1;

      try {
        createdCount = await _createTransactionRequest(
          client,
          accountId: accountIdToUse,
          amount: amount,
          dateStr: dateStr,
          status: status,
        );
      } on DioException catch (e) {
        if (!_isAccountNotFoundError(e) || _selectedCategoryIdentity == null) {
          rethrow;
        }

        ref.invalidate(categoriesProvider(false));
        final refreshed = await ref.read(categoriesProvider(false).future);
        final remappedAccountId = _findMatchingCategoryId(
          refreshed,
          _selectedCategoryIdentity!,
        );
        if (remappedAccountId == null) {
          rethrow;
        }

        accountIdToUse = remappedAccountId;
        if (mounted) {
          setState(() => _selectedAccountId = remappedAccountId);
        }
        createdCount = await _createTransactionRequest(
          client,
          accountId: accountIdToUse,
          amount: amount,
          dateStr: dateStr,
          status: status,
        );
      }

      invalidateAfterTransactionMutation(ref);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              createdCount > 1
                  ? '$createdCount transaction(s) creee(s)'
                  : 'Transaction creee',
            ),
            backgroundColor: AppColors.neonEmerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on DioException catch (e) {
      setState(() {
        _error = _extractApiMessage(e.response?.data);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Erreur lors de la creation';
        _loading = false;
      });
    }
  }

  Future<void> _openAccountPicker(
    List<Category> categories, {
    required List<String> recentIds,
    required List<String> favoriteIds,
    required String noteHint,
  }) async {
    final deduped = _dedupeCategories(categories);
    var query = '';
    var typeFilter = 'all';

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) {
          final filtered = deduped.where((c) {
            if (typeFilter == 'income' && !c.isIncome) return false;
            if (typeFilter == 'expense' && c.isIncome) return false;
            if (query.isNotEmpty) {
              final hay = '${c.name} ${c.group}'.toLowerCase();
              if (!hay.contains(query.toLowerCase())) return false;
            }
            return true;
          }).toList()..sort(_compareCategories);

          final expenses = filtered.where((c) => !c.isIncome).toList();
          final incomes = filtered.where((c) => c.isIncome).toList();

          List<Category> resolveByIds(List<String> ids) {
            final byId = <String, Category>{for (final c in filtered) c.id: c};
            return ids.map((id) => byId[id]).whereType<Category>().toList();
          }

          List<Category> buildSuggestions() {
            final tokens = <String>{
              ...noteHint
                  .toLowerCase()
                  .split(RegExp(r'[^a-zA-Z0-9]+'))
                  .where((t) => t.length >= 2),
              ...query
                  .toLowerCase()
                  .split(RegExp(r'[^a-zA-Z0-9]+'))
                  .where((t) => t.length >= 2),
            };
            if (tokens.isEmpty) return const [];

            final scored = <({Category category, int score})>[];
            for (final c in filtered) {
              var score = 0;
              final name = c.name.toLowerCase();
              final group = c.group.toLowerCase();
              for (final token in tokens) {
                if (name.contains(token)) score += 4;
                if (group.contains(token)) score += 2;
              }
              if (favoriteIds.contains(c.id)) score += 1;
              if (recentIds.contains(c.id)) score += 1;
              if (score > 0) scored.add((category: c, score: score));
            }

            scored.sort((a, b) {
              final byScore = b.score.compareTo(a.score);
              if (byScore != 0) return byScore;
              return a.category.name.toLowerCase().compareTo(
                b.category.name.toLowerCase(),
              );
            });
            return scored.map((s) => s.category).take(6).toList();
          }

          final suggested = buildSuggestions();
          final favorites = resolveByIds(favoriteIds);
          final favoriteSet = favorites.map((c) => c.id).toSet();
          final recents = resolveByIds(
            recentIds.where((id) => !favoriteSet.contains(id)).toList(),
          );
          final showQuickRows = query.trim().isEmpty;

          Widget buildQuickChips(
            String title,
            List<Category> items, {
            required IconData icon,
            required Color accent,
            int maxItems = 3,
          }) {
            if (items.isEmpty) return const SizedBox.shrink();
            final limited = items.take(maxItems).toList();
            final hiddenCount = items.length - limited.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 14, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ...limited.map((c) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text('${c.name} - ${c.group}'),
                              onPressed: () => Navigator.pop(ctx, c.id),
                            ),
                          );
                        }),
                        if (hiddenCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Chip(label: Text('+$hiddenCount')),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          Widget buildSection(String title, List<Category> entries) {
            if (entries.isEmpty) return const SizedBox.shrink();
            final byGroup = <String, List<Category>>{};
            for (final c in entries) {
              byGroup.putIfAbsent(c.group, () => <Category>[]).add(c);
            }

            final groupNames = byGroup.keys.toList()..sort();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                ...groupNames.map((groupName) {
                  final items = byGroup[groupName]!..sort(_compareCategories);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderSubtle),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          child: Text(
                            groupName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ...items.map((c) {
                          final isSelected = c.id == _selectedAccountId;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              c.isIncome
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              size: 18,
                              color: c.isIncome
                                  ? AppColors.neonEmerald
                                  : AppColors.softRed,
                            ),
                            title: Text(c.name),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle,
                                    color: AppColors.primary,
                                    size: 18,
                                  )
                                : null,
                            onTap: () => Navigator.pop(ctx, c.id),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            );
          }

          return Dialog(
            backgroundColor: AppColors.surfaceDialog,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Selectionner un compte',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (v) => setLocalState(() => query = v),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher une categorie ou un groupe',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('Tout'),
                          selected: typeFilter == 'all',
                          onSelected: (_) =>
                              setLocalState(() => typeFilter = 'all'),
                        ),
                        ChoiceChip(
                          label: const Text('Depenses'),
                          selected: typeFilter == 'expense',
                          onSelected: (_) =>
                              setLocalState(() => typeFilter = 'expense'),
                        ),
                        ChoiceChip(
                          label: const Text('Revenus'),
                          selected: typeFilter == 'income',
                          onSelected: (_) =>
                              setLocalState(() => typeFilter = 'income'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (showQuickRows) ...[
                      buildQuickChips(
                        'Suggestions',
                        suggested,
                        icon: Icons.auto_awesome_outlined,
                        accent: AppColors.primary,
                      ),
                      buildQuickChips(
                        'Favoris',
                        favorites,
                        icon: Icons.star_border,
                        accent: AppColors.warning,
                      ),
                      buildQuickChips(
                        'Recents',
                        recents,
                        icon: Icons.history,
                        accent: AppColors.info,
                      ),
                    ],
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'Aucun resultat. Cree une categorie rapide.',
                              ),
                            )
                          : ListView(
                              children: [
                                buildSection('DEPENSES', expenses),
                                buildSection('REVENUS', incomes),
                              ],
                            ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final created = await _quickCreateCategory(
                                preferredType: typeFilter == 'income'
                                    ? 'income'
                                    : 'expense',
                              );
                              if (created != null && ctx.mounted) {
                                Navigator.pop(ctx, created.id);
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Categorie rapide'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton(
                            onPressed: () =>
                                showCategoriesManagerModal(context, ref),
                            child: const Text('Gerer groupes/cat.'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (selected != null) {
      Category? selectedCategory;
      for (final c in deduped) {
        if (c.id == selected) {
          selectedCategory = c;
          break;
        }
      }
      setState(() {
        _selectedAccountId = selected;
        if (selectedCategory != null) {
          _selectedCategoryIdentity = _CategoryIdentity.fromCategory(
            selectedCategory,
          );
        }
        _error = null;
      });
    }
  }

  Future<Category?> _quickCreateCategory({
    required String preferredType,
  }) async {
    final groups = await ref.read(categoryGroupsProvider(false).future);
    final draft = await _openQuickCreateDialog(
      groups: groups,
      preferredType: preferredType,
    );
    if (draft == null) return null;

    try {
      String? groupId = draft.groupId;
      var groupName = draft.groupName;
      if (groupId != null && groupId.startsWith('legacy-')) {
        groupId = null;
      }

      if (draft.newGroupName != null) {
        try {
          final createdGroup = await ref
              .read(categoryGroupApiProvider)
              .create(name: draft.newGroupName!, type: draft.type);
          groupId = createdGroup.id;
          groupName = createdGroup.name;
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow;
          // Backend without group endpoints: fallback to plain group name.
          groupId = null;
          groupName = draft.newGroupName;
        }
      }

      final created = await ref
          .read(categoryApiProvider)
          .create(
            name: draft.name,
            type: draft.type,
            groupId: groupId,
            group: groupName,
          );

      _invalidateCategoryCaches();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Categorie "${created.name}" creee'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return created;
    } on DioException catch (e) {
      final payload = e.response?.data;
      String? apiMessage;
      if (payload is Map<String, dynamic>) {
        apiMessage = payload['error'] as String?;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiMessage ?? 'Erreur creation categorie'),
            backgroundColor: AppColors.softRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
  }

  Future<_QuickCategoryDraft?> _openQuickCreateDialog({
    required List<CategoryGroup> groups,
    required String preferredType,
  }) async {
    final nameCtrl = TextEditingController();
    final newGroupCtrl = TextEditingController();
    var type = preferredType;
    var createNewGroup = false;
    String? selectedGroupId;

    List<CategoryGroup> groupsForType() =>
        groups.where((g) => !g.isArchived && g.type == type).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    void ensureSelection() {
      final options = groupsForType();
      if (options.isEmpty) {
        createNewGroup = true;
        selectedGroupId = null;
        return;
      }
      if (!options.any((g) => g.id == selectedGroupId)) {
        selectedGroupId = options.first.id;
      }
    }

    ensureSelection();

    final result = await showDialog<_QuickCategoryDraft>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) {
          final options = groupsForType();
          return AlertDialog(
            title: const Text('Creation rapide categorie'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom categorie'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'expense', child: Text('Depense')),
                    DropdownMenuItem(value: 'income', child: Text('Revenu')),
                  ],
                  onChanged: (v) {
                    setLocalState(() {
                      type = v ?? 'expense';
                      createNewGroup = false;
                      ensureSelection();
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (!createNewGroup && options.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedGroupId,
                    decoration: const InputDecoration(labelText: 'Groupe'),
                    items: options
                        .map(
                          (g) => DropdownMenuItem(
                            value: g.id,
                            child: Text(g.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocalState(() => selectedGroupId = v),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setLocalState(() {
                        createNewGroup = !createNewGroup;
                        if (!createNewGroup) ensureSelection();
                      });
                    },
                    icon: Icon(
                      createNewGroup ? Icons.list_alt_outlined : Icons.add,
                    ),
                    label: Text(
                      createNewGroup
                          ? 'Utiliser un groupe existant'
                          : 'Creer un nouveau groupe',
                    ),
                  ),
                ),
                if (createNewGroup)
                  TextField(
                    controller: newGroupCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom nouveau groupe',
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;

                  if (createNewGroup) {
                    final groupName = newGroupCtrl.text.trim();
                    if (groupName.isEmpty) return;
                    Navigator.pop(
                      ctx,
                      _QuickCategoryDraft(
                        name: name,
                        type: type,
                        groupId: null,
                        groupName: groupName,
                        newGroupName: groupName,
                      ),
                    );
                    return;
                  }

                  if (selectedGroupId == null) return;
                  CategoryGroup? selectedGroup;
                  for (final g in options) {
                    if (g.id == selectedGroupId) {
                      selectedGroup = g;
                      break;
                    }
                  }
                  Navigator.pop(
                    ctx,
                    _QuickCategoryDraft(
                      name: name,
                      type: type,
                      groupId: selectedGroupId,
                      groupName: selectedGroup?.name,
                      newGroupName: null,
                    ),
                  );
                },
                child: const Text('Creer'),
              ),
            ],
          );
        },
      ),
    );

    nameCtrl.dispose();
    newGroupCtrl.dispose();
    return result;
  }

  void _invalidateCategoryCaches() {
    ref.invalidate(categoriesProvider(true));
    ref.invalidate(categoriesProvider(false));
    ref.invalidate(categoryGroupsProvider(true));
    ref.invalidate(categoryGroupsProvider(false));
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider(false));
    final recentAsync = ref.watch(recentTransactionsProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: EdgeInsets.all(
          MediaQuery.of(context).size.width < 500 ? 20 : 28,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nouvelle transaction',
                    style: AppTextStyles.title,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Selectionne une categorie existante ou cree-la directement ici.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text(
                  'Erreur de chargement des comptes',
                  style: TextStyle(color: AppColors.softRed),
                ),
                data: (categories) {
                  final deduped = _dedupeCategories(categories);
                  final recentIds = recentAsync.maybeWhen(
                    data: (items) {
                      final ids = <String>[];
                      final seen = <String>{};
                      for (final tx in items) {
                        if (seen.add(tx.accountId)) ids.add(tx.accountId);
                        if (ids.length >= 8) break;
                      }
                      return ids;
                    },
                    orElse: () => <String>[],
                  );
                  final favoriteIds = recentAsync.maybeWhen(
                    data: (items) {
                      final counts = <String, int>{};
                      for (final tx in items) {
                        counts.update(
                          tx.accountId,
                          (value) => value + 1,
                          ifAbsent: () => 1,
                        );
                      }
                      final sorted = counts.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));
                      return sorted.take(6).map((e) => e.key).toList();
                    },
                    orElse: () => <String>[],
                  );
                  Category? selected;
                  for (final c in deduped) {
                    if (c.id == _selectedAccountId) {
                      selected = c;
                      break;
                    }
                  }
                  if (selected != null) {
                    _selectedCategoryIdentity = _CategoryIdentity.fromCategory(
                      selected,
                    );
                  }

                  return Column(
                    children: [
                      InkWell(
                        onTap: () => _openAccountPicker(
                          deduped,
                          recentIds: recentIds,
                          favoriteIds: favoriteIds,
                          noteHint: _noteCtrl.text,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Compte',
                            suffixIcon: Icon(Icons.expand_more),
                          ),
                          child: selected == null
                              ? const Text(
                                  'Choisir une categorie',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                )
                              : Row(
                                  children: [
                                    Icon(
                                      selected.isIncome
                                          ? Icons.trending_up
                                          : Icons.trending_down,
                                      size: 16,
                                      color: selected.isIncome
                                          ? AppColors.neonEmerald
                                          : AppColors.softRed,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            selected.name,
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            selected.group,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              final created = await _quickCreateCategory(
                                preferredType: 'expense',
                              );
                              if (created != null) {
                                setState(() {
                                  _selectedAccountId = created.id;
                                  _selectedCategoryIdentity =
                                      _CategoryIdentity.fromCategory(created);
                                });
                              }
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Creation rapide'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () =>
                                showCategoriesManagerModal(context, ref),
                            child: const Text('Gerer groupes/cat.'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    suffixIcon: Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  child: Text(
                    DateFormat('dd MMMM yyyy', 'fr_FR').format(_date),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: _repaymentPlan
                      ? 'Mensualite (${AppFormats.currencyCode})'
                      : 'Montant (${AppFormats.currencyCode})',
                  prefixText: '${AppFormats.currencySymbol} ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requis';
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  if (n == null || n <= 0) return 'Montant invalide';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Note (optionnel)',
                ),
                maxLength: 500,
              ),
              const SizedBox(height: 8),
              _SwitchRow(
                label: 'Prelevement automatique',
                value: _isAuto,
                onChanged: (v) => setState(() => _isAuto = v),
              ),
              _SwitchRow(
                label: 'Deja paye',
                value: _isPaid,
                onChanged: (v) => setState(() => _isPaid = v),
                color: AppColors.neonEmerald,
                helperText: _isPaid
                    ? 'Coche par defaut pour les operations deja reglees.'
                    : 'Non paye: apparaitra dans les factures a traiter.',
                helperColor: _isPaid
                    ? AppColors.neonEmerald
                    : AppColors.warning,
              ),
              _SwitchRow(
                label: 'Repeter chaque mois',
                value: _recurrence,
                onChanged: (v) => setState(() {
                  _recurrence = v;
                  if (v) _repaymentPlan = false;
                  if (v && _recurrenceEndDate.isBefore(_date)) {
                    _recurrenceEndDate = _date;
                  }
                }),
                color: AppColors.coolPurple,
              ),
              _SwitchRow(
                label: 'Plan de remboursement',
                value: _repaymentPlan,
                onChanged: (v) => setState(() {
                  _repaymentPlan = v;
                  if (v) _recurrence = false;
                }),
                color: AppColors.info,
                helperText: _repaymentPlan
                    ? 'Cree automatiquement des mensualites jusqu au solde.'
                    : 'Active si tu rembourses un montant total sur plusieurs mois.',
              ),
              if (_recurrence) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickRecurrenceEndDate,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Jusqu au',
                      suffixIcon: Icon(
                        Icons.event_repeat,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    child: Text(
                      DateFormat(
                        'dd MMMM yyyy',
                        'fr_FR',
                      ).format(_effectiveRecurrenceEndDate),
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _occurrences <= 0
                      ? 'Choisis une date de fin valide'
                      : '$_occurrences transaction(s) seront creees',
                  style: const TextStyle(
                    color: AppColors.coolPurple,
                    fontSize: 13,
                  ),
                ),
              ],
              if (_repaymentPlan) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _repaymentTotalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText:
                        'Total a rembourser (${AppFormats.currencyCode})',
                    prefixText: '${AppFormats.currencySymbol} ',
                  ),
                  validator: (v) {
                    if (!_repaymentPlan) return null;
                    if (v == null || v.trim().isEmpty) return 'Requis';
                    final n = double.tryParse(v.replaceAll(',', '.'));
                    if (n == null || n <= 0) return 'Montant invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (_) {
                    final installments = _repaymentInstallments;
                    final endDate = _repaymentEndDate;
                    if (installments <= 0 || endDate == null) {
                      return const Text(
                        'Renseigne mensualite et total pour calculer le plan.',
                        style: TextStyle(color: AppColors.info, fontSize: 12),
                      );
                    }
                    return Text(
                      '$installments mensualite(s) jusqu au ${DateFormat('dd MMM yyyy', 'fr_FR').format(endDate)} (derniere: ${AppFormats.currency.format(_repaymentLastInstallment)})',
                      style: const TextStyle(
                        color: AppColors.info,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.softRed,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _repaymentPlan && _repaymentInstallments > 0
                              ? 'Creer plan ($_repaymentInstallments mensualites)'
                              : _recurrence && _occurrences > 0
                              ? 'Creer $_occurrences transaction(s)'
                              : 'Creer la transaction',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Category> _dedupeCategories(List<Category> categories) {
    final seen = <String>{};
    final deduped = <Category>[];
    for (final c in categories) {
      final key =
          '${c.type.toLowerCase()}|${c.group.toLowerCase()}|${c.name.toLowerCase()}';
      if (seen.contains(key)) continue;
      seen.add(key);
      deduped.add(c);
    }
    return deduped;
  }

  int _compareCategories(Category a, Category b) {
    final byType = a.type.compareTo(b.type);
    if (byType != 0) return byType;
    final byGroup = a.group.toLowerCase().compareTo(b.group.toLowerCase());
    if (byGroup != 0) return byGroup;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  double? _tryParseAmount(String value) {
    final normalized = value.replaceAll(',', '.').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  DateTime _shiftMonthKeepingDay(DateTime date, int monthsToAdd) {
    final rawMonth = date.month + monthsToAdd;
    final targetYear = date.year + ((rawMonth - 1) ~/ 12);
    final targetMonth = ((rawMonth - 1) % 12) + 1;
    final maxDay = DateUtils.getDaysInMonth(targetYear, targetMonth);
    final day = math.min(date.day, maxDay);
    return DateTime(targetYear, targetMonth, day);
  }

  Future<int> _createTransactionRequest(
    ApiClient client, {
    required String accountId,
    required double amount,
    required String dateStr,
    required int status,
  }) async {
    if (_repaymentPlan) {
      final totalAmount = _repaymentTotalAmount;
      if (totalAmount == null || totalAmount <= 0) {
        throw Exception('Total repayment amount is invalid');
      }

      final response = await client.post<Map<String, dynamic>>(
        '/api/transactions/repayment-plan',
        data: {
          'transaction': {
            'accountId': accountId,
            'date': dateStr,
            'amount': amount,
            'note': _noteCtrl.text.trim().isEmpty
                ? null
                : _noteCtrl.text.trim(),
            'status': status,
            'isAuto': _isAuto,
          },
          'repayment': {'totalAmount': totalAmount, 'monthlyAmount': amount},
        },
      );
      final count = (response.data?['count'] as num?)?.toInt();
      return count ?? _repaymentInstallments;
    }

    if (_recurrence) {
      final dayOfMonth = _date.day;
      final response = await client.post<Map<String, dynamic>>(
        '/api/transactions/batch',
        data: {
          'transaction': {
            'accountId': accountId,
            'date': dateStr,
            'amount': amount,
            'note': _noteCtrl.text.trim().isEmpty
                ? null
                : _noteCtrl.text.trim(),
            'status': status,
            'isAuto': _isAuto,
          },
          'recurrence': {
            'dayOfMonth': dayOfMonth,
            'endDate': DateFormat(
              'yyyy-MM-dd',
            ).format(_effectiveRecurrenceEndDate),
          },
        },
      );
      final count = (response.data?['count'] as num?)?.toInt();
      return count ?? _occurrences;
    }

    await client.post(
      '/api/transactions',
      data: {
        'accountId': accountId,
        'date': dateStr,
        'amount': amount,
        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        'status': status,
        'isAuto': _isAuto,
      },
    );
    return 1;
  }

  bool _isAccountNotFoundError(DioException e) {
    if (e.response?.statusCode != 404) return false;
    final payload = e.response?.data;
    if (payload is Map<String, dynamic>) {
      final message = payload['error'];
      if (message is String) {
        return message.toLowerCase().contains('account not found');
      }
    }
    return true;
  }

  String? _findMatchingCategoryId(
    List<Category> categories,
    _CategoryIdentity identity,
  ) {
    for (final c in categories) {
      final sameType = c.type == identity.type;
      final sameName = _normalize(c.name) == _normalize(identity.name);
      final sameGroup = _normalize(c.group) == _normalize(identity.group);
      if (sameType && sameName && sameGroup) return c.id;
    }
    return null;
  }

  String _extractApiMessage(dynamic payload) {
    if (payload is String && payload.trim().isNotEmpty) {
      return payload;
    }
    if (payload is Map<String, dynamic>) {
      final error = payload['error'];
      if (error is String && error.trim().isNotEmpty) return error;

      final detail = payload['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail;

      final title = payload['title'];
      if (title is String && title.trim().isNotEmpty) return title;

      final errors = payload['errors'];
      if (errors is Map<String, dynamic>) {
        for (final value in errors.values) {
          if (value is List) {
            for (final item in value) {
              if (item is String && item.trim().isNotEmpty) return item;
            }
          }
          if (value is String && value.trim().isNotEmpty) return value;
        }
      }
    }
    return 'Erreur lors de la creation';
  }

  String _normalize(String value) => value.trim().toLowerCase();
}

class _QuickCategoryDraft {
  final String name;
  final String type;
  final String? groupId;
  final String? groupName;
  final String? newGroupName;

  const _QuickCategoryDraft({
    required this.name,
    required this.type,
    required this.groupId,
    required this.groupName,
    required this.newGroupName,
  });
}

class _CategoryIdentity {
  final String name;
  final String group;
  final String type;

  const _CategoryIdentity({
    required this.name,
    required this.group,
    required this.type,
  });

  factory _CategoryIdentity.fromCategory(Category category) =>
      _CategoryIdentity(
        name: category.name,
        group: category.group,
        type: category.type,
      );
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;
  final String? helperText;
  final Color? helperColor;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.color = AppColors.electricBlue,
    this.helperText,
    this.helperColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            Switch(value: value, activeThumbColor: color, onChanged: onChanged),
          ],
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              helperText!,
              style: TextStyle(
                color: helperColor ?? AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
