import 'package:flutter/material.dart';
import 'package:solver/core/l10n/app_strings.dart';

class NavItem {
  final String label;
  final IconData icon;
  final String route;

  const NavItem(this.label, this.icon, this.route);
}

final navItems = [
  NavItem(AppStrings.nav.dashboard, Icons.dashboard_outlined, '/dashboard'),
  NavItem(AppStrings.nav.journal, Icons.list_alt_outlined, '/journal'),
  NavItem(AppStrings.nav.schedule, Icons.calendar_today_outlined, '/schedule'),
  NavItem(AppStrings.nav.budget, Icons.pie_chart_outline, '/budget'),
  NavItem(AppStrings.nav.goals, Icons.flag_outlined, '/goals'),
  NavItem(AppStrings.nav.portfolio, Icons.candlestick_chart_outlined, '/portfolio'),
  NavItem(AppStrings.nav.analysis, Icons.analytics_outlined, '/analysis'),
  NavItem(AppStrings.nav.spreadsheet, Icons.table_view, '/spreadsheet'),
];
