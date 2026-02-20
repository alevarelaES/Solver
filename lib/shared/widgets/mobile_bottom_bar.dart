import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/shared/widgets/nav_items.dart';

class MobileBottomBar extends StatelessWidget {
  const MobileBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final location = GoRouterState.of(context).matchedLocation;
    final groupIndex = primaryNavGroups.indexWhere(
      (group) => group.matchesLocation(location),
    );
    final isOverflowRoute = overflowNavItems.any(
      (item) => item.matchesLocation(location),
    );
    final currentIndex = groupIndex >= 0
        ? groupIndex
        : (isOverflowRoute ? primaryNavGroups.length : 0);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      backgroundColor: theme.cardColor,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: isDark
          ? AppColors.textSecondaryDark
          : AppColors.textSecondaryLight,
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      onTap: (index) {
        if (index < primaryNavGroups.length) {
          context.go(primaryNavGroups[index].route);
          return;
        }
        _openMoreMenu(context, location);
      },
      items: [
        ...primaryNavGroups.map(
          (group) => BottomNavigationBarItem(
            icon: Icon(group.icon),
            label: group.label,
          ),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.more_horiz),
          label: AppStrings.nav.more,
        ),
      ],
    );
  }

  Future<void> _openMoreMenu(BuildContext context, String location) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.s6,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.nav.more,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ...overflowNavItems.map(
                (item) => ListTile(
                  leading: Icon(
                    item.icon,
                    color: item.matchesLocation(location)
                        ? AppColors.primary
                        : null,
                  ),
                  title: Text(item.label),
                  trailing: item.matchesLocation(location)
                      ? const Icon(
                          Icons.check_circle,
                          size: 18,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go(item.route);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
