import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routes.dart';
import '../theme/app_theme.dart';
import '../widgets/local_goal_card.dart';
import '../services/local_secure_store.dart';

/// Profile screen - User settings, achievements, and account info
class ProfileScreen extends StatefulWidget {
  final SessionController session;

  const ProfileScreen({super.key, required this.session});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    final email = await LocalSecureStore.instance.getActiveSessionEmail();
    setState(() => _userEmail = email ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PROFILE'), centerTitle: true),
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkGradient
              : AppTheme.lightGradient,
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Goals section
            const Text(
              'Active Goals',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: AppTheme.textWhite,
              ),
            ),
            const SizedBox(height: 12),
            if (_userEmail.isNotEmpty)
              LocalGoalCard(userEmail: _userEmail)
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.glassBorder.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'Loading...',
                  style: TextStyle(color: AppTheme.textLight),
                ),
              ),

            const SizedBox(height: 32),

            // 🔧 DEVELOPER TOOLS (Remove before production)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.accentOrange.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.construction,
                    color: AppTheme.accentOrange,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🔧 Developer Tools (Remove for Production)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _buildActionCard(
              icon: Icons.monitor_heart,
              title: 'Data Monitor & Sync',
              subtitle:
                  'View raw metrics, test backend sync, check connections',
              onTap: () => context.push('/data-monitor'),
            ),

            const SizedBox(height: 12),

            _buildActionCard(
              icon: Icons.bug_report,
              title: 'Developer Diagnostics',
              subtitle: 'System info, database stats, debug tools',
              onTap: () => context.push('/developer-diagnostics'),
            ),

            const SizedBox(height: 32),

            // Account section
            const Text(
              'Account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: AppTheme.textWhite,
              ),
            ),
            const SizedBox(height: 12),

            _buildActionCard(
              icon: Icons.settings,
              title: 'Settings',
              subtitle: 'Preferences, security, and more',
              onTap: () => context.push('/settings'),
            ),

            const SizedBox(height: 12),

            _buildActionCard(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy & Security',
              subtitle: 'Data protection information',
              onTap: () => context.push('/privacy-info'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.glassBorder.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryCyan, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textWhite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textGray,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
