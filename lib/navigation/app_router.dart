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

class AppRouter {
  static GoRouter createRouter(BuildContext context) {
    return GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final authProvider = context.read<AuthProvider>();
        final isAuthenticated =
            authProvider.status == AuthStatus.authenticated;
        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register';

        // If still loading auth state
        if (authProvider.status == AuthStatus.unknown) return null;

        // If not logged in and not on auth screen → go to login
        if (!isAuthenticated && !isAuthRoute) return '/login';

        // If logged in and on auth screen → go to home
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
              path: '/add-expense',
              builder: (context, state) {
                // Pass transaction id for edit mode
                final extra = state.extra as Map<String, dynamic>?;
                return AddExpenseScreen(existingTransaction: extra?['transaction']);
              },
            ),
            GoRoute(
              path: '/summary',
              builder: (context, state) => const SummaryScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],

      // ── Error page ─────────────────────────────────────────
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text('Page not found: ${state.error}'),
        ),
      ),
    );
  }
}