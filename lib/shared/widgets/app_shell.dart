import 'package:flutter/material.dart';
import 'package:solver/shared/widgets/desktop_sidebar.dart';
import 'package:solver/shared/widgets/mobile_bottom_bar.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1024;
    final isTablet = width > 768;

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop) const DesktopSidebar(collapsed: false),
          if (isTablet && !isDesktop) const DesktopSidebar(collapsed: true),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: isTablet ? null : const MobileBottomBar(),
    );
  }
}

