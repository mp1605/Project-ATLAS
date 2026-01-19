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
import 'services/local_secure_store.dart';

class SessionController extends ChangeNotifier {
  bool _ready = false;
  bool _signedIn = false;
  String? _email;

  bool get ready => _ready;
  bool get signedIn => _signedIn;
  String? get email => _email;

  void setReady(bool v) {
    _ready = v;
    notifyListeners();
  }

  void setSignedIn(bool v, {String? email}) {
    _signedIn = v;
    _email = email;
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
        path: '/readiness',
        builder: (context, state) => const ReadinessDashboardScreen(),
      ),
      GoRoute(
        path: '/data-monitor',
        builder: (context, state) => DataMonitorScreen(session: session),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => SettingsScreen(session: session),
      ),
      GoRoute(
        path: '/health-debug',
        builder: (context, state) => const HealthDebugScreen(),
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
        path: '/home',
        builder: (context, state) => HomePlaceholder(session: session),
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

      // Allow public and user-specific routes
      if (loc == '/login' ||
          loc == '/register' ||
          loc == '/home' ||
          loc == '/readiness' ||
          loc == '/data-monitor' ||
          loc == '/settings' ||
          loc == '/database-test' ||
          loc == '/raw-consent' ||
          loc == '/raw-consent/edit' ||
          loc == '/select-wearable' ||
          loc == '/log-activity' ||
          loc == '/log-activity/add' ||
          loc == '/authorize') {
        return null;
      }

      // If not signed in, redirect unauthorized to login
      if (!signedIn) return '/login';

      return null;
    },
  );
}
