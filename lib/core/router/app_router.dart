import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solver/features/auth/providers/auth_provider.dart';
import 'package:solver/features/auth/views/login_view.dart';
import 'package:solver/features/dashboard/views/dashboard_view.dart';
import 'package:solver/features/journal/views/journal_view.dart';
import 'package:solver/features/schedule/views/schedule_view.dart';
import 'package:solver/features/budget/views/budget_view.dart';
import 'package:solver/features/goals/views/goals_view.dart';
import 'package:solver/features/portfolio/views/portfolio_view.dart';
import 'package:solver/features/analysis/views/analysis_view.dart';
import 'package:solver/features/spreadsheet/views/spreadsheet_view.dart';
import 'package:solver/shared/widgets/app_shell.dart';

Page<void> _fadePage(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoggedIn = authState.value?.session != null;
      final isGoingToLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isGoingToLogin) return '/login';
      if (isLoggedIn && isGoingToLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginView()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) =>
                _fadePage(const DashboardView(), state),
          ),
          GoRoute(
            path: '/journal',
            pageBuilder: (context, state) =>
                _fadePage(const JournalView(), state),
          ),
          GoRoute(
            path: '/schedule',
            pageBuilder: (context, state) =>
                _fadePage(const ScheduleView(), state),
          ),
          GoRoute(
            path: '/budget',
            pageBuilder: (context, state) =>
                _fadePage(const BudgetView(), state),
          ),
          GoRoute(
            path: '/goals',
            pageBuilder: (context, state) =>
                _fadePage(const GoalsView(), state),
          ),
          GoRoute(
            path: '/portfolio',
            pageBuilder: (context, state) =>
                _fadePage(const PortfolioView(), state),
          ),
          GoRoute(
            path: '/analysis',
            pageBuilder: (context, state) =>
                _fadePage(const AnalysisView(), state),
          ),
          GoRoute(
            path: '/spreadsheet',
            pageBuilder: (context, state) =>
                _fadePage(const SpreadsheetView(), state),
          ),
        ],
      ),
    ],
  );
});
