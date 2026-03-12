import 'package:flutter/material.dart';
import 'app.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const FraudShieldApp());
}

class FraudShieldApp extends StatelessWidget {
  const FraudShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FraudShield — AI Fraud Detection',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}