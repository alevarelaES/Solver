import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/main.dart';
import 'package:solver/shared/widgets/nav_items.dart';

class DesktopSidebar extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const DesktopSidebar({super.key, required this.ref});

  @override
  ConsumerState<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends ConsumerState<DesktopSidebar> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final location = GoRouterState.of(context).matchedLocation;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: _isHovered ? 260.0 : 81.0,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(
            right: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          boxShadow: _isHovered && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(4, 0),
                  ),
                ]
              : null,
        ),
        child: OverflowBox(
          minWidth: 260.0,
          maxWidth: 260.0,
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SidebarHeader(isDark: isDark, isHovered: _isHovered),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  children: primaryNavGroups.map((group) {
                    final isActive = group.matchesLocation(location);
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.xs,
                        left: AppSpacing.md,
                        right: AppSpacing.md,
                      ),
                      child: _SidebarNavItem(
                        label: group.label,
                        icon: group.icon,
                        isActive: isActive,
                        isHovered: _isHovered,
                        onTap: () => context.go(group.route),
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),
              const Divider(height: 1),
              _SidebarFooter(ref: widget.ref, isHovered: _isHovered, isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  final bool isDark;
  final bool isHovered;

  const _SidebarHeader({required this.isDark, required this.isHovered});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 22.0,
        top: AppSpacing.xl,
        bottom: AppSpacing.xl,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.r8),
            ),
            alignment: Alignment.center,
            child: const Text(
              'S',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: isHovered ? 1.0 : 0.0,
              child: Text(
                'Solver',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: isDark ? Colors.white : AppColors.primaryDarker,
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final bool isHovered;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.isHovered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: isHovered ? '' : label,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 48,
          padding: const EdgeInsets.only(left: 13.0, right: 16.0),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 22,
                color: isActive
                    ? AppColors.primary
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: isHovered ? 1.0 : 0.0,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? (isDark ? Colors.white : AppColors.primaryDarker)
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                    ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  final WidgetRef ref;
  final bool isHovered;
  final bool isDark;

  const _SidebarFooter({
    required this.ref,
    required this.isHovered,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: _buildCollapsed(),
      secondChild: _buildExpanded(),
      crossFadeState: isHovered ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.centerLeft,
    );
  }

  Widget _buildCollapsed() {
    return Padding(
      padding: const EdgeInsets.only(
        left: 22.0,
        top: AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isDark ? AppColors.borderDark : AppColors.borderLight,
            child: Icon(
              Icons.person,
              size: 20,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _ThemeToggleButton(ref: ref, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildExpanded() {
    return Padding(
      padding: const EdgeInsets.only(
        left: 22.0,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isDark ? AppColors.borderDark : AppColors.borderLight,
            child: Icon(
              Icons.person,
              size: 20,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Utilisateur',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
                Text(
                  'Mon Profil',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _ThemeToggleButton(ref: ref, isDark: isDark),
        ],
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  final WidgetRef ref;
  final bool isDark;

  const _ThemeToggleButton({required this.ref, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          size: 20,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
        onPressed: () {
          final current = ref.read(themeModeProvider);
          ref.read(themeModeProvider.notifier).state =
              current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
        },
        tooltip: isDark
            ? AppStrings.ui.themeTooltipLight
            : AppStrings.ui.themeTooltipDark,
      ),
    );
  }
}

