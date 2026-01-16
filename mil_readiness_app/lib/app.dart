import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';

class MilReadinessApp extends StatelessWidget {
  final GoRouter router;
  const MilReadinessApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AUIX - Military Readiness',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,  // Professional dark blue theme
      routerConfig: router,
    );
  }
}
