import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solver/core/constants/app_currency.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/main.dart';
import 'package:solver/shared/widgets/currency_converter_sheet.dart';
import 'package:solver/shared/widgets/mobile_bottom_bar.dart';
import 'package:solver/shared/widgets/nav_items.dart';

import 'package:solver/shared/widgets/desktop_sidebar.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= AppBreakpoints.tablet;

    if (isTablet) {
      return Scaffold(
        body: Row(
          children: [
            DesktopSidebar(ref: ref),
            Expanded(
              child: Column(
                children: [
                  _TopControls(ref: ref),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _MobileControls(ref: ref),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: const MobileBottomBar(),
    );
  }
}

class _TopControls extends StatelessWidget {
  final WidgetRef ref;

  const _TopControls({required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final location = GoRouterState.of(context).matchedLocation;
    final activeGroup = activePrimaryNavGroup(location);
    final hasContextPages = activeGroup.pages.length > 1;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (hasContextPages)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: activeGroup.pages
                          .map((item) {
                            final isActive = item.matchesLocation(location);
                            return Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.xs),
                              child: _ContextNavChip(
                                item: item,
                                isActive: isActive,
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                )
              else
                 const Spacer(),
              _CurrencyMenuButton(ref: ref),
              const SizedBox(width: AppSpacing.xs),
              _CurrencyConverterButton(ref: ref),
            ],
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
          const SizedBox(width: AppSpacing.xs),
          _CurrencyConverterButton(ref: ref),
          const SizedBox(width: AppSpacing.xs),
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
            tooltip: isDark
                ? AppStrings.ui.themeTooltipLight
                : AppStrings.ui.themeTooltipDark,
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
      tooltip: AppStrings.ui.currencyTooltip,
      onSelected: (currency) {
        ref.read(appCurrencyProvider.notifier).setCurrency(currency);
      },
      itemBuilder: (_) => AppCurrency.values
          .map((currency) {
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
                  Text(_currencyLabel(currency)),
                ],
              ),
            );
          })
          .toList(growable: false),
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

  String _currencyLabel(AppCurrency currency) {
    switch (currency) {
      case AppCurrency.chf:
        return AppStrings.ui.currencyChf;
      case AppCurrency.eur:
        return AppStrings.ui.currencyEur;
      case AppCurrency.usd:
        return AppStrings.ui.currencyUsd;
    }
  }
}

class _CurrencyConverterButton extends StatelessWidget {
  final WidgetRef ref;

  const _CurrencyConverterButton({required this.ref});

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(appCurrencyProvider);
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < AppBreakpoints.tablet;

    void onPressed() =>
        showCurrencyConverterSheet(context, initialSourceCode: selected.code);

    if (isCompact) {
      return Tooltip(
        message: AppStrings.ui.currencyConverterTooltip,
        child: TextButton.icon(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s6,
              vertical: AppSpacing.xs,
            ),
          ),
          icon: const Icon(Icons.currency_exchange_outlined, size: 18),
          label: Text(
            AppStrings.ui.currencyConverterAction,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      );
    }

    return Tooltip(
      message: AppStrings.ui.currencyConverterTooltip,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.currency_exchange_outlined, size: 18),
        label: Text(
          AppStrings.ui.currencyConverterAction,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.s6,
          ),
        ),
      ),
    );
  }
}


class _ContextNavChip extends StatelessWidget {
  final NavItem item;
  final bool isActive;

  const _ContextNavChip({required this.item, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.r18),
      onTap: () => context.go(item.route),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.s6,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.r18),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          color: isActive ? AppColors.primary.withValues(alpha: 0.08) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 16,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.s6),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
