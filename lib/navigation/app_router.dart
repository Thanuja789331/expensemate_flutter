import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../views/auth/login_screen.dart';
import '../views/auth/register_screen.dart';
import '../views/home/home_screen.dart';
import '../views/dashboard/dashboard_screen.dart';
import '../views/add_expense/add_expense_screen.dart';
import '../views/summary/summary_screen.dart';
import '../views/profile/profile_screen.dart';
import '../views/widgets/main_scaffold.dart';
import '../views/tips_screen.dart';
import '../views/budget_planner_screen.dart';

class AppRouter {
  static GoRouter createRouter(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    return GoRouter(
      initialLocation: '/login',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuthenticated =
            authProvider.status == AuthStatus.authenticated;
        final isAuthRoute =
            state.matchedLocation == '/login' ||
                state.matchedLocation == '/register';

        if (authProvider.status == AuthStatus.unknown) return null;
        if (!isAuthenticated && !isAuthRoute) return '/login';
        if (isAuthenticated && isAuthRoute) return '/home';

        return null;
      },
      routes: [

        // ── Auth Routes ────────────────────────────────────────
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),

        // ── Add Expense (outside shell for push navigation) ────
        GoRoute(
          path: '/add-expense',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return AddExpenseScreen(
              existingTransaction: extra?['transaction'],
            );
          },
        ),

        // ── Main App Routes (with Bottom Navigation) ───────────
        ShellRoute(
          builder: (context, state, child) {
            return MainScaffold(child: child);
          },
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/summary',
              builder: (context, state) => const SummaryScreen(),
            ),
            GoRoute(
              path: '/budget',
              builder: (context, state) => const BudgetPlannerScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
            GoRoute(
              path: '/tips',
              builder: (context, state) => const TipsScreen(),
            ),
          ],
        ),
      ],
    );
  }
}