import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/shared/widgets/nav_items.dart';

class DesktopSidebar extends StatelessWidget {
  final bool collapsed;

  const DesktopSidebar({super.key, required this.collapsed});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final width = collapsed ? 64.0 : 220.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(
          right: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          collapsed
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Icon(Icons.bolt, color: AppColors.electricBlue, size: 24),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Solver',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.electricBlue,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: navItems.map((item) {
                final isActive = location.startsWith(item.route);
                return _SidebarTile(
                  item: item,
                  isActive: isActive,
                  collapsed: collapsed,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final NavItem item;
  final bool isActive;
  final bool collapsed;

  const _SidebarTile({
    required this.item,
    required this.isActive,
    required this.collapsed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.go(item.route),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 12,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isActive ? AppColors.electricBlue.withAlpha(30) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: collapsed
              ? Center(
                  child: Icon(
                    item.icon,
                    color: isActive ? AppColors.electricBlue : AppColors.textSecondary,
                    size: 22,
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      item.icon,
                      color: isActive ? AppColors.electricBlue : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: isActive ? AppColors.electricBlue : AppColors.textSecondary,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
