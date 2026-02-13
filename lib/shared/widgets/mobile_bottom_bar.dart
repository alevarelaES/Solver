import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/shared/widgets/nav_items.dart';

class MobileBottomBar extends StatelessWidget {
  const MobileBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = navItems.indexWhere(
      (item) => location.startsWith(item.route),
    );

    return BottomNavigationBar(
      currentIndex: currentIndex < 0 ? 0 : currentIndex,
      backgroundColor: theme.cardColor,
      selectedItemColor: AppColors.primary,
      unselectedItemColor:
          isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      onTap: (index) => context.go(navItems[index].route),
      items: navItems
          .map(
            (item) => BottomNavigationBarItem(
              icon: Icon(item.icon),
              label: item.label,
            ),
          )
          .toList(),
    );
  }
}
