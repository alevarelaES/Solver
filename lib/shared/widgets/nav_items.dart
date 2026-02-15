import 'package:flutter/material.dart';

class NavItem {
  final String label;
  final IconData icon;
  final String route;

  const NavItem(this.label, this.icon, this.route);
}

final navItems = [
  NavItem('Tableau de bord', Icons.dashboard_outlined, '/dashboard'),
  NavItem('Journal', Icons.list_alt_outlined, '/journal'),
  NavItem('Echeancier', Icons.calendar_today_outlined, '/schedule'),
  NavItem('Budget', Icons.pie_chart_outline, '/budget'),
  NavItem('Objectifs', Icons.flag_outlined, '/goals'),
  NavItem('Analyse', Icons.analytics_outlined, '/analysis'),
  NavItem('Tableau', Icons.table_view, '/spreadsheet'),
];
