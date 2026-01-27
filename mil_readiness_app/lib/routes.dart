import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/raw_data_consent_screen.dart';
import 'screens/home_placeholder.dart';
import 'screens/authorize_screen.dart';
import 'screens/wearable_selection_screen.dart';
import 'screens/database_test_screen.dart';
import 'screens/readiness_dashboard_screen.dart';
import 'screens/data_monitor_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/health_debug_screen.dart';
import 'screens/score_detail_screen.dart';
import 'screens/manual_activity_list_screen.dart';
import 'screens/manual_activity_entry_screen.dart';
import 'screens/biometric_setup_screen.dart';
import 'screens/developer_diagnostics_screen.dart';
import 'screens/readiness_info_screen.dart';
import 'screens/operational_briefing_screen.dart';
import 'screens/analytics_screen.dart';
import 'widgets/privacy_widgets.dart';
import 'widgets/main_scaffold.dart';
import 'services/local_secure_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/main_navigation_screen.dart';


class SessionController extends ChangeNotifier {
  bool _ready = false;
  bool _signedIn = false;
  bool _briefingCompleted = false;
  String? _email;
  ThemeMode _themeMode = ThemeMode.system;

  bool get ready => _ready;
  bool get signedIn => _signedIn;
  bool get briefingCompleted => _briefingCompleted;
  String? get email => _email;
  ThemeMode get themeMode => _themeMode;

  void setBriefingCompleted(bool v) {
    _briefingCompleted = v;
    notifyListeners();
  }

  void setReady(bool v) {
    _ready = v;
    notifyListeners();
  }

  void setSignedIn(bool v, {String? email}) {
    _signedIn = v;
    _email = email;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  Future<void> signOut() async {
    await LocalSecureStore.instance.clearSession();
    setSignedIn(false, email: null);
  }
}

GoRouter buildRouter(SessionController session) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: session,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          session: session,
          message: state.uri.queryParameters['msg'],
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterScreen(session: session),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // ✅ Biometric setup (Face ID/Touch ID prompt after first login)
      GoRoute(
        path: '/biometric-setup',
        builder: (context, state) => const BiometricSetupScreen(),
      ),

      // Onboarding raw consent (only forced if not decided yet)
      GoRoute(
        path: '/raw-consent',
        builder: (context, state) => const RawDataConsentScreen(editMode: false),
      ),

      // ✅ Edit consent anytime from Home
      GoRoute(
        path: '/raw-consent/edit',
        builder: (context, state) => const RawDataConsentScreen(editMode: true),
      ),
      
      GoRoute(
        path: '/database-test',
        builder: (context, state) => const DatabaseTestScreen(),
      ),

      GoRoute(
        path: '/home',
        builder: (context, state) => MainNavigationScreen(session: session),
      ),
      
      // Direct routes (no wrapper)
      GoRoute(
        path: '/settings',
        builder: (context, state) => SettingsScreen(session: session),
      ),

      // Routes that should NOT have the bottom nav (full-screen detail/onboarding)
      GoRoute(
        path: '/data-monitor',
        builder: (context, state) => DataMonitorScreen(session: session),
      ),

      // ✅ Wearable device selection
      GoRoute(
        path: '/select-wearable',
        builder: (context, state) {
          final email = state.extra as String?;
          return WearableSelectionScreen(
            isOnboarding: true,
            userEmail: email ?? '',
          );
        },
      ),

      // ✅ Apple Health permission onboarding page
      GoRoute(
        path: '/authorize',
        builder: (context, state) => AuthorizeScreen(session: session),
      ),

      GoRoute(
        path: '/score-detail',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>;
          return ScoreDetailScreen(
            scoreName: args['scoreName'] as String,
            scoreValue: args['scoreValue'] as double,
            components: args['components'] as Map<String, double>,
            confidence: args['confidence'] as String,
          );
        },
      ),
      
      GoRoute(
        path: '/health-debug',
        builder: (context, state) => const HealthDebugScreen(),
      ),
      GoRoute(
        path: '/developer-diagnostics',
        builder: (context, state) => DeveloperDiagnosticsScreen(session: session),
      ),
      GoRoute(
        path: '/readiness-info',
        builder: (context, state) => const ReadinessInfoScreen(),
      ),
      GoRoute(
        path: '/privacy-info',
        builder: (context, state) => const PrivacyInfoScreen(),
      ),
      GoRoute(
        path: '/wearable-select',
        builder: (context, state) => WearableSelectionScreen(
          isOnboarding: false,
          userEmail: session.email ?? '',
        ),
      ),
      GoRoute(
        path: '/briefing',
        builder: (context, state) => OperationalBriefingScreen(session: session),
      ),
      GoRoute(
        path: '/log-activity',
        builder: (context, state) => const ManualActivityListScreen(),
      ),
      GoRoute(
        path: '/log-activity/add',
        builder: (context, state) => const ManualActivityEntryScreen(),
      ),
    ],

    redirect: (context, state) async {
      final loc = state.matchedLocation;
      final ready = session.ready;
      final signedIn = session.signedIn;

      if (!ready) return null;

      // If signed in and trying to access login/register, redirect to home
      if (signedIn && (loc == '/login' || loc == '/register')) {
        return '/home';
      }

      // If not signed in, redirect protected routes to login
      if (!signedIn) {
        // Allow access to login and register without being signed in
        if (loc == '/login' || loc == '/register') {
          return null;
        }
        // Redirect everything else to login
        return '/login';
      }

      // Check for briefing completion if signed in
      if (signedIn && loc != '/briefing' && !session.briefingCompleted) {
         return '/briefing';
      }

      // Signed in - allow all routes
      return null;
    },
  );
}
