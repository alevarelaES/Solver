import 'package:flutter/material.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/categories/models/category.dart';
import 'package:solver/features/categories/models/category_group.dart';
import 'package:solver/features/categories/providers/categories_provider.dart';

Future<void> showCategoriesManagerModal(BuildContext context, WidgetRef ref) {
  return showDialog(
    context: context,
    builder: (_) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: const _CategoriesManagerDialog(),
    ),
  );
}

class _CategoriesManagerDialog extends ConsumerStatefulWidget {
  const _CategoriesManagerDialog();

  @override
  ConsumerState<_CategoriesManagerDialog> createState() =>
      _CategoriesManagerDialogState();
}

class _CategoriesManagerDialogState
    extends ConsumerState<_CategoriesManagerDialog> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider(true));
    final groupsAsync = ref.watch(categoryGroupsProvider(true));

    return Dialog(
      backgroundColor: AppColors.surfaceDialog,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.forms.manageCategoriesTitle,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _saving ? null : _createGroup,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: Text(AppStrings.forms.newGroupBtn),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _saving ? null : _createCategory,
                    icon: const Icon(Icons.add),
                    label: Text(AppStrings.forms.newCategoryBtn),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.forms.categoriesManagerHint,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: categoriesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      AppStrings.forms.categoriesError(e),
                      style: const TextStyle(color: AppColors.softRed),
                    ),
                  ),
                  data: (categories) => groupsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Text(
                        AppStrings.forms.groupsError(e),
                        style: const TextStyle(color: AppColors.softRed),
                      ),
                    ),
                    data: (groups) => _buildContent(categories, groups),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<Category> categories, List<CategoryGroup> groups) {
    final orderedCategories = [...categories]..sort(_compareCategories);
    final activeCategories = orderedCategories
        .where((c) => !c.isArchived)
        .toList();
    final archivedCategories = orderedCategories
        .where((c) => c.isArchived)
        .toList();

    final orderedGroups = [...groups]..sort(_compareGroups);
    final activeGroups = orderedGroups.where((g) => !g.isArchived).toList();
    final archivedGroups = orderedGroups.where((g) => g.isArchived).toList();

    return ListView(
      children: [
        ..._buildTypeSections(
          type: 'expense',
          title: AppStrings.forms.typeExpensePlural,
          groups: activeGroups,
          categories: activeCategories,
        ),
        const SizedBox(height: 14),
        ..._buildTypeSections(
          type: 'income',
          title: AppStrings.forms.typeIncomePlural,
          groups: activeGroups,
          categories: activeCategories,
        ),
        if (archivedGroups.isNotEmpty || archivedCategories.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            AppStrings.forms.archives,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...archivedGroups.map(
            (g) => ListTile(
              dense: true,
              title: Text('${g.name} (${g.isIncome ? AppStrings.forms.typeIncome : AppStrings.forms.typeExpense})'),
              subtitle: Text(AppStrings.forms.archivedGroup),
              trailing: IconButton(
                onPressed: _saving ? null : () => _archiveGroup(g, false),
                icon: const Icon(Icons.unarchive_outlined, size: 18),
              ),
            ),
          ),
          ...archivedCategories.map(_buildCategoryRow),
        ],
      ],
    );
  }

  List<Widget> _buildTypeSections({
    required String type,
    required String title,
    required List<CategoryGroup> groups,
    required List<Category> categories,
  }) {
    final sectionGroups = groups.where((g) => g.type == type).toList()
      ..sort(_compareGroups);

    final result = <Widget>[
      Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 8),
    ];

    if (sectionGroups.isEmpty) {
      result.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            AppStrings.forms.noGroups,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      );
      return result;
    }

    for (final group in sectionGroups) {
      final items =
          categories
              .where(
                (c) =>
                    c.type == type &&
                    (c.groupId == group.id ||
                        (c.groupId == null &&
                            c.group.trim().toLowerCase() ==
                                group.name.trim().toLowerCase())),
              )
              .toList()
            ..sort(_compareCategories);

      result.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderSubtle),
            borderRadius: BorderRadius.circular(AppRadius.r12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.s10, AppSpacing.sm, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${items.length} cat.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : () => _editGroup(group),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: AppStrings.forms.renameGroup,
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => _archiveGroup(group, true),
                      icon: const Icon(Icons.archive_outlined, size: 18),
                      tooltip: AppStrings.forms.archiveGroup,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    AppStrings.forms.noCategories,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                ...items.map(_buildCategoryRow),
            ],
          ),
        ),
      );
    }

    return result;
  }

  Widget _buildCategoryRow(Category c) {
    return ListTile(
      dense: true,
      title: Text(c.name),
      subtitle: Text(c.group),
      leading: Icon(
        c.isIncome ? Icons.trending_up : Icons.trending_down,
        color: c.isIncome ? AppColors.neonEmerald : AppColors.softRed,
      ),
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            onPressed: _saving ? null : () => _editCategory(c),
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: AppStrings.common.edit,
          ),
          IconButton(
            onPressed: _saving
                ? null
                : () => _archiveCategory(c, !c.isArchived),
            icon: Icon(
              c.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              size: 18,
            ),
            tooltip: c.isArchived ? AppStrings.forms.unarchive : AppStrings.forms.archive,
          ),
        ],
      ),
    );
  }

  Future<void> _createGroup() async {
    final draft = await _openGroupEditor();
    if (draft == null) return;

    setState(() => _saving = true);
    try {
      final api = ref.read(categoryGroupApiProvider);
      await api.create(name: draft.name, type: draft.type);
      _invalidateAll();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.forms.createGroupUnavailable),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editGroup(CategoryGroup group) async {
    final draft = await _openGroupEditor(initial: group);
    if (draft == null) return;

    setState(() => _saving = true);
    try {
      final api = ref.read(categoryGroupApiProvider);
      await api.rename(id: group.id, name: draft.name);
      _invalidateAll();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.forms.renameGroupUnavailable),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archiveGroup(CategoryGroup group, bool archived) async {
    setState(() => _saving = true);
    try {
      final api = ref.read(categoryGroupApiProvider);
      await api.archive(group.id, archived);
      _invalidateAll();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.forms.archiveGroupUnavailable),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createCategory() async {
    final groups = await ref.read(categoryGroupsProvider(false).future);
    final draft = await _openCategoryEditor(groups: groups);
    if (draft == null) return;

    setState(() => _saving = true);
    try {
      var resolvedGroupId = draft.groupId;
      var resolvedGroupName = draft.groupName;
      if (resolvedGroupId != null && resolvedGroupId.startsWith('legacy-')) {
        resolvedGroupId = null;
      }
      if (draft.newGroupName != null) {
        try {
          final createdGroup = await ref
              .read(categoryGroupApiProvider)
              .create(name: draft.newGroupName!, type: draft.type);
          resolvedGroupId = createdGroup.id;
          resolvedGroupName = createdGroup.name;
        } catch (_) {
          // Fallback when group endpoint is unavailable on older backend.
          resolvedGroupId = null;
          resolvedGroupName = draft.newGroupName;
        }
      }

      await ref
          .read(categoryApiProvider)
          .create(
            name: draft.name,
            type: draft.type,
            groupId: resolvedGroupId,
            group: resolvedGroupName,
          );
      _invalidateAll();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editCategory(Category category) async {
    final groups = await ref.read(categoryGroupsProvider(false).future);
    final draft = await _openCategoryEditor(initial: category, groups: groups);
    if (draft == null) return;

    setState(() => _saving = true);
    try {
      var resolvedGroupId = draft.groupId;
      var resolvedGroupName = draft.groupName;
      if (resolvedGroupId != null && resolvedGroupId.startsWith('legacy-')) {
        resolvedGroupId = null;
      }
      if (draft.newGroupName != null) {
        try {
          final createdGroup = await ref
              .read(categoryGroupApiProvider)
              .create(name: draft.newGroupName!, type: draft.type);
          resolvedGroupId = createdGroup.id;
          resolvedGroupName = createdGroup.name;
        } catch (_) {
          resolvedGroupId = null;
          resolvedGroupName = draft.newGroupName;
        }
      }

      await ref
          .read(categoryApiProvider)
          .update(
            id: category.id,
            name: draft.name,
            type: draft.type,
            groupId: resolvedGroupId,
            group: resolvedGroupName,
          );
      _invalidateAll();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archiveCategory(Category category, bool archived) async {
    setState(() => _saving = true);
    try {
      await ref.read(categoryApiProvider).archive(category.id, archived);
      _invalidateAll();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _invalidateAll() {
    ref.invalidate(categoriesProvider(true));
    ref.invalidate(categoriesProvider(false));
    ref.invalidate(categoryGroupsProvider(true));
    ref.invalidate(categoryGroupsProvider(false));
  }

  Future<_CategoryDraft?> _openCategoryEditor({
    Category? initial,
    required List<CategoryGroup> groups,
  }) async {
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final newGroupCtrl = TextEditingController();
    var type = initial?.type ?? 'expense';
    var selectedGroupId = initial?.groupId;
    var creatingNewGroup = false;

    List<CategoryGroup> groupsForType() =>
        groups.where((g) => !g.isArchived && g.type == type).toList()
          ..sort(_compareGroups);

    void ensureSelection() {
      final list = groupsForType();
      if (list.isEmpty) {
        creatingNewGroup = true;
        selectedGroupId = null;
        return;
      }
      if (selectedGroupId == null ||
          !list.any((g) => g.id == selectedGroupId)) {
        selectedGroupId = list.first.id;
      }
    }

    ensureSelection();

    final result = await showDialog<_CategoryDraft>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) {
          final availableGroups = groupsForType();
          return AlertDialog(
            title: Text(
              initial == null ? AppStrings.forms.newCategoryTitle : AppStrings.forms.editCategoryTitle,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: AppStrings.forms.nameLabel),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(labelText: AppStrings.forms.typeLabel),
                  items: [
                    DropdownMenuItem(value: 'expense', child: Text(AppStrings.forms.typeExpense)),
                    DropdownMenuItem(value: 'income', child: Text(AppStrings.forms.typeIncome)),
                  ],
                  onChanged: (v) {
                    setLocalState(() {
                      type = v ?? 'expense';
                      creatingNewGroup = false;
                      ensureSelection();
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (availableGroups.isNotEmpty && !creatingNewGroup)
                  DropdownButtonFormField<String>(
                    initialValue: selectedGroupId,
                    decoration: InputDecoration(labelText: AppStrings.forms.categoryGroup),
                    items: availableGroups
                        .map(
                          (g) => DropdownMenuItem(
                            value: g.id,
                            child: Text(g.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocalState(() => selectedGroupId = v),
                  ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setLocalState(() => creatingNewGroup = !creatingNewGroup);
                    },
                    icon: Icon(
                      creatingNewGroup ? Icons.list_alt_outlined : Icons.add,
                    ),
                    label: Text(
                      creatingNewGroup
                          ? AppStrings.forms.useExistingGroup
                          : AppStrings.forms.createNewGroup,
                    ),
                  ),
                ),
                if (creatingNewGroup)
                  TextField(
                    controller: newGroupCtrl,
                    decoration: InputDecoration(
                      labelText: AppStrings.forms.newGroupName,
                      hintText: AppStrings.forms.newGroupHint,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppStrings.common.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;

                  if (creatingNewGroup) {
                    final newGroupName = newGroupCtrl.text.trim();
                    if (newGroupName.isEmpty) return;
                    Navigator.pop(
                      ctx,
                      _CategoryDraft(
                        name: name,
                        type: type,
                        groupId: null,
                        groupName: newGroupName,
                        newGroupName: newGroupName,
                      ),
                    );
                    return;
                  }

                  if (selectedGroupId == null) return;
                  CategoryGroup? selectedGroup;
                  for (final g in availableGroups) {
                    if (g.id == selectedGroupId) {
                      selectedGroup = g;
                      break;
                    }
                  }
                  Navigator.pop(
                    ctx,
                    _CategoryDraft(
                      name: name,
                      type: type,
                      groupId: selectedGroupId,
                      groupName: selectedGroup?.name,
                      newGroupName: null,
                    ),
                  );
                },
                child: Text(AppStrings.common.save),
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

  Future<_GroupDraft?> _openGroupEditor({CategoryGroup? initial}) async {
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    var type = initial?.type ?? 'expense';

    final result = await showDialog<_GroupDraft>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(initial == null ? AppStrings.forms.newGroupTitle : AppStrings.forms.renameGroupTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: AppStrings.forms.groupNameLabel),
              ),
              if (initial == null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(labelText: AppStrings.forms.typeLabel),
                  items: [
                    DropdownMenuItem(value: 'expense', child: Text(AppStrings.forms.typeExpense)),
                    DropdownMenuItem(value: 'income', child: Text(AppStrings.forms.typeIncome)),
                  ],
                  onChanged: (v) => setLocalState(() => type = v ?? 'expense'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.common.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx, _GroupDraft(name: name, type: type));
              },
              child: Text(AppStrings.common.save),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    return result;
  }

  int _compareCategories(Category a, Category b) {
    final byType = a.type.compareTo(b.type);
    if (byType != 0) return byType;
    final byGroup = a.group.toLowerCase().compareTo(b.group.toLowerCase());
    if (byGroup != 0) return byGroup;
    final bySort = a.sortOrder.compareTo(b.sortOrder);
    if (bySort != 0) return bySort;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  int _compareGroups(CategoryGroup a, CategoryGroup b) {
    final byType = a.type.compareTo(b.type);
    if (byType != 0) return byType;
    final bySort = a.sortOrder.compareTo(b.sortOrder);
    if (bySort != 0) return bySort;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}

class _CategoryDraft {
  final String name;
  final String type;
  final String? groupId;
  final String? groupName;
  final String? newGroupName;

  const _CategoryDraft({
    required this.name,
    required this.type,
    required this.groupId,
    required this.groupName,
    required this.newGroupName,
  });
}

class _GroupDraft {
  final String name;
  final String type;

  const _GroupDraft({required this.name, required this.type});
}



