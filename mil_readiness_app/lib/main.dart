import 'package:flutter/material.dart';
import 'app.dart';
import 'routes.dart';
import 'services/local_secure_store.dart';
import 'services/daily_readiness_service.dart';
import 'config/app_config.dart';
import 'theme/app_theme.dart';  // Professional theme

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load custom server URL if set
  await AppConfig.loadFromStore();

  // Initialize daily readiness scoring
  // TODO: Re-enable after iOS workmanager configuration
  // try {
  //   await DailyReadinessService.initialize();
  //   print('✅ Daily readiness service started');
  // } catch (e) {
  //   print('⚠️ Could not initialize daily service: $e');
  // }

  final session = SessionController();

   // ✅ TEST MODE: Always start signed out (forces Login every app launch)
  await LocalSecureStore.instance.clearSession();

  // Do NOT restore session in this mode
  session.setSignedIn(false, email: null);

  // Restore session (if any)
  //final email = await LocalSecureStore instance.getActiveSessionEmail();
  //if (email != null && email.isNotEmpty) {
    //session.setSignedIn(true, email: email);
  //}

  session.setReady(true);

  final router = buildRouter(session);

  runApp(MilReadinessApp(router: router));
}
