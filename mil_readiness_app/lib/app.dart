import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import 'routes.dart';
import 'widgets/security_privacy_wrapper.dart';

class MilReadinessApp extends StatelessWidget {
  final GoRouter router;
  final SessionController session;
  const MilReadinessApp({super.key, required this.router, required this.session});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'AUIX - Military Readiness',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: session.themeMode,
          routerConfig: router,
          builder: (context, child) {
            return SecurityPrivacyWrapper(
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
