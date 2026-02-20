import 'package:flutter/material.dart';
import 'package:solver/core/l10n/app_strings.dart';

class NavItem {
  final String label;
  final IconData icon;
  final String route;
  final List<String> matchPrefixes;

  const NavItem(
    this.label,
    this.icon,
    this.route, {
    List<String>? matchPrefixes,
  }) : matchPrefixes = matchPrefixes ?? const [];

  bool matchesLocation(String location) {
    final prefixes = matchPrefixes.isEmpty ? <String>[route] : matchPrefixes;
    return prefixes.any(location.startsWith);
  }
}

class NavGroup {
  final String label;
  final IconData icon;
  final String route;
  final List<NavItem> pages;

  const NavGroup({
    required this.label,
    required this.icon,
    required this.route,
    required this.pages,
  });

  bool matchesLocation(String location) {
    return pages.any((item) => item.matchesLocation(location));
  }
}

final dashboardNavItem = NavItem(
  AppStrings.nav.dashboard,
  Icons.dashboard_outlined,
  '/dashboard',
);

final journalNavItem = NavItem(
  AppStrings.nav.journal,
  Icons.list_alt_outlined,
  '/journal',
);

final scheduleNavItem = NavItem(
  AppStrings.nav.schedule,
  Icons.calendar_today_outlined,
  '/schedule',
);

final budgetNavItem = NavItem(
  AppStrings.nav.budget,
  Icons.pie_chart_outline,
  '/budget',
);

final goalsNavItem = NavItem(
  AppStrings.nav.goals,
  Icons.flag_outlined,
  '/goals',
);

final analysisNavItem = NavItem(
  AppStrings.nav.analysis,
  Icons.analytics_outlined,
  '/analysis',
);

final portfolioNavItem = NavItem(
  AppStrings.nav.portfolio,
  Icons.candlestick_chart_outlined,
  '/portfolio',
);

final spreadsheetNavItem = NavItem(
  AppStrings.nav.spreadsheet,
  Icons.table_view,
  '/spreadsheet',
);

final navItems = <NavItem>[
  dashboardNavItem,
  journalNavItem,
  scheduleNavItem,
  budgetNavItem,
  goalsNavItem,
  analysisNavItem,
  portfolioNavItem,
  spreadsheetNavItem,
];

final primaryNavGroups = <NavGroup>[
  NavGroup(
    label: AppStrings.nav.dashboard,
    icon: Icons.dashboard_outlined,
    route: dashboardNavItem.route,
    pages: [dashboardNavItem],
  ),
  NavGroup(
    label: AppStrings.nav.activity,
    icon: Icons.receipt_long_outlined,
    route: journalNavItem.route,
    pages: [journalNavItem],
  ),
  NavGroup(
    label: AppStrings.nav.schedule,
    icon: Icons.calendar_today_outlined,
    route: scheduleNavItem.route,
    pages: [scheduleNavItem],
  ),
  NavGroup(
    label: AppStrings.nav.goals,
    icon: Icons.flag_outlined,
    route: goalsNavItem.route,
    pages: [goalsNavItem],
  ),
];

final overflowNavItems = <NavItem>[
  budgetNavItem,
  analysisNavItem,
  portfolioNavItem,
  spreadsheetNavItem,
];

final moreNavItem = NavItem(AppStrings.nav.more, Icons.more_horiz, '/more');

int activePrimaryNavIndex(String location) {
  final index = primaryNavGroups.indexWhere(
    (group) => group.matchesLocation(location),
  );
  return index < 0 ? 0 : index;
}

NavGroup activePrimaryNavGroup(String location) {
  return primaryNavGroups[activePrimaryNavIndex(location)];
}
