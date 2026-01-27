import 'package:flutter/material.dart';
import 'app.dart';
import 'routes.dart';
import 'services/local_secure_store.dart';
import 'services/daily_readiness_service.dart';
import 'theme/app_theme.dart';  // Professional theme
import 'widgets/app_lock_wrapper.dart'; // Biometric lock wrapper

import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize daily readiness scoring
  // TODO: Re-enable after iOS workmanager configuration
  // try {
  //   await DailyReadinessService.initialize();
  //   print('✅ Daily readiness service started');
  // } catch (e) {
  //   print('⚠️ Could not initialize daily service: $e');
  // }

  final session = SessionController();

  // Restore session & theme (if any)
  final prefs = await SharedPreferences.getInstance();
  
  // PATCH: Clear iOS Keychain on fresh install (prevent persistent data survival)
  const String kFreshInstallFlag = 'v1_fresh_install_checked';
  if (!prefs.containsKey(kFreshInstallFlag)) {
    print('🔄 Fresh installation detected. Purging legacy secure storage...');
    await LocalSecureStore.instance.clearAllData();
    await prefs.setBool(kFreshInstallFlag, true);
  }

  final email = await LocalSecureStore.instance.getActiveSessionEmail();
  final themeStr = await LocalSecureStore.instance.getString('pref_theme');
  
  // Restore briefing status
  final briefingCompleted = prefs.getBool('briefing_completed') ?? false;
  session.setBriefingCompleted(briefingCompleted);

  if (email != null && email.isNotEmpty) {
    session.setSignedIn(true, email: email);
  }

  // Set initial theme
  if (themeStr != null) {
    session.setThemeMode(
      themeStr == 'dark' ? ThemeMode.dark : (themeStr == 'light' ? ThemeMode.light : ThemeMode.system)
    );
  }

  session.setReady(true);

  final router = buildRouter(session);

  // Wrap app with biometric lock for security
  runApp(
    AppLockWrapper(
      child: MilReadinessApp(router: router, session: session),
    ),
  );
}

