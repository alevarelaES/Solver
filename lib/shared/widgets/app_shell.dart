import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solver/core/constants/app_currency.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/main.dart';
import 'package:solver/shared/widgets/mobile_bottom_bar.dart';
import 'package:solver/shared/widgets/nav_items.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 768;

    return Scaffold(
      body: Column(
        children: [
          if (isTablet) _TopHeader(ref: ref),
          if (!isTablet) _MobileControls(ref: ref),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: isTablet ? null : const MobileBottomBar(),
    );
  }
}

class _TopHeader extends StatelessWidget {
  final WidgetRef ref;

  const _TopHeader({required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final location = GoRouterState.of(context).matchedLocation;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
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
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Solver',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isDark ? Colors.white : AppColors.primaryDarker,
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: navItems.map((item) {
                  final isActive = location.startsWith(item.route);
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _NavTab(
                      label: item.label,
                      isActive: isActive,
                      onTap: () => context.go(item.route),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          _CurrencyMenuButton(ref: ref),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            onPressed: () {
              final current = ref.read(themeModeProvider);
              ref.read(themeModeProvider.notifier).state =
                  current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
            tooltip: isDark ? 'Mode clair' : 'Mode sombre',
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 16,
            backgroundColor: isDark
                ? AppColors.borderDark
                : AppColors.borderLight,
            child: Icon(
              Icons.person,
              size: 18,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileControls extends StatelessWidget {
  final WidgetRef ref;

  const _MobileControls({required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _CurrencyMenuButton(ref: ref),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            onPressed: () {
              final current = ref.read(themeModeProvider);
              ref.read(themeModeProvider.notifier).state =
                  current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
            tooltip: isDark ? 'Mode clair' : 'Mode sombre',
          ),
        ],
      ),
    );
  }
}

class _CurrencyMenuButton extends StatelessWidget {
  final WidgetRef ref;

  const _CurrencyMenuButton({required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selected = ref.watch(appCurrencyProvider);

    return PopupMenuButton<AppCurrency>(
      initialValue: selected,
      tooltip: 'Devise',
      onSelected: (currency) {
        ref.read(appCurrencyProvider.notifier).setCurrency(currency);
      },
      itemBuilder: (_) => AppCurrency.values.map((currency) {
        final isSelected = currency == selected;
        return PopupMenuItem<AppCurrency>(
          value: currency,
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: isSelected
                    ? const Icon(Icons.check, size: 16)
                    : const SizedBox.shrink(),
              ),
              Text('${currency.code} (${currency.symbol})'),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.r18),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected.code,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.r20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppColors.primaryDarker)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.r20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive
                ? Colors.white
                : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight),
          ),
        ),
      ),
    );
  }
}

