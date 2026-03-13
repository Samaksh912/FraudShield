import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/provider/alerts_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/alerts/screens/alerts_screen.dart';
import 'features/score/screens/score_screen.dart';
import 'features/analytics/screens/analytics_screen.dart';
import 'features/transactions/transactions_screen.dart';


class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AlertsProvider is shared between DashboardScreen and AlertsScreen.
        // It is instantiated once here; both screens read the same instance.
        ChangeNotifierProvider<AlertsProvider>(
          create: (_) => AlertsProvider(),
        ),
        // Add future providers here (e.g. TransactionsProvider, ScoreProvider)
      ],
      child: MaterialApp.router(
        title: 'FraudShield',
        theme: AppTheme.dark,          // keep your existing theme
        routerConfig: appRouter,       // keep your existing GoRouter
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/signup',   builder: (_, __) => const SignupScreen()),
    GoRoute(path: '/dashboard',    builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/transactions', builder: (_, __) => const TransactionsScreen()),
    GoRoute(path: '/alerts',       builder: (_, __) => const AlertsScreen()),
    GoRoute(path: '/score',        builder: (_, __) => const ScoreScreen()),
    GoRoute(path: '/analytics',    builder: (_, __) => const AnalyticsScreen()),
    // Fallback redirect
    GoRoute(path: '/', redirect: (_, __) => '/login'),
  ],
);