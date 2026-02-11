import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solver/features/auth/providers/auth_provider.dart';
import 'package:solver/features/auth/views/login_view.dart';
import 'package:solver/features/dashboard/views/dashboard_view.dart';
import 'package:solver/features/journal/views/journal_view.dart';
import 'package:solver/features/schedule/views/schedule_view.dart';
import 'package:solver/features/budget/views/budget_view.dart';
import 'package:solver/features/analysis/views/analysis_view.dart';
import 'package:solver/shared/widgets/app_shell.dart';

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
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginView(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardView(),
          ),
          GoRoute(
            path: '/journal',
            builder: (context, state) => const JournalView(),
          ),
          GoRoute(
            path: '/schedule',
            builder: (context, state) => const ScheduleView(),
          ),
          GoRoute(
            path: '/budget',
            builder: (context, state) => const BudgetView(),
          ),
          GoRoute(
            path: '/analysis',
            builder: (context, state) => const AnalysisView(),
          ),
        ],
      ),
    ],
  );
});
