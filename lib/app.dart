import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/alerts/screens/alerts_screen.dart';
import 'features/score/screens/score_screen.dart';
import 'features/analytics/screens/analytics_screen.dart';
import 'features/transactions/transactions_screen.dart';

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