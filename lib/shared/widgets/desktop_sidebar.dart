import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/shared/widgets/nav_items.dart';

/// Icon-only sidebar (Stitch style). Always 64px wide.
class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final location = GoRouterState.of(context).matchedLocation;

    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: navItems.map((item) {
                final isActive = location.startsWith(item.route);
                return _SidebarIcon(
                  item: item,
                  isActive: isActive,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarIcon extends StatelessWidget {
  final NavItem item;
  final bool isActive;

  const _SidebarIcon({
    required this.item,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Tooltip(
        message: item.label,
        preferBelow: false,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          onTap: () => context.go(item.route),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.r12),
            ),
            alignment: Alignment.center,
            child: Icon(
              item.icon,
              size: 22,
              color: isActive
                  ? AppColors.primary
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
          ),
        ),
      ),
    );
  }
}

