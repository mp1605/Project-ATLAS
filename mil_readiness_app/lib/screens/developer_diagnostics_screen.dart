import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/local_secure_store.dart';
import '../routes.dart';

/// Developer/Diagnostics screen containing all technical settings
/// 
/// ACCESS: Hidden from normal users. Revealed by tapping version 7 times in Settings.
/// REMOVAL: Delete this file + remove route + remove section in settings_screen.dart
class DeveloperDiagnosticsScreen extends StatefulWidget {
  final SessionController session;
  const DeveloperDiagnosticsScreen({super.key, required this.session});

  @override
  State<DeveloperDiagnosticsScreen> createState() => _DeveloperDiagnosticsScreenState();
}

class _DeveloperDiagnosticsScreenState extends State<DeveloperDiagnosticsScreen> {
  String get _email => widget.session.email ?? '';
  bool _debugMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text('DEVELOPER', style: AppTheme.titleStyle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Warning Banner
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentOrange.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppTheme.accentOrange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Developer tools - not for regular users',
                      style: AppTheme.bodyStyle.copyWith(color: AppTheme.accentOrange),
                    ),
                  ),
                ],
              ),
            ),
            
            // Sync & Collection Section
            _buildSectionHeader('SYNC & COLLECTION'),
            _buildGlassCard(
              child: Column(
                children: [
                  _buildInfoTile(
                    icon: Icons.sync,
                    title: 'LiveSync Status',
                    value: 'Running',
                    color: AppTheme.accentGreen,
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  _buildInfoTile(
                    icon: Icons.access_time,
                    title: 'Sync Interval',
                    value: '60 seconds',
                    color: AppTheme.primaryCyan,
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  _buildInfoTile(
                    icon: Icons.monitor_heart,
                    title: 'Metrics Tracked',
                    value: '30 types',
                    color: AppTheme.primaryBlue,
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  ListTile(
                    leading: const Icon(Icons.terminal, color: AppTheme.primaryCyan, size: 24),
                    title: Text('Terminal Logging', style: AppTheme.bodyStyle),
                    subtitle: Text('Check terminal for live logs every 60s', style: AppTheme.captionStyle),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Security & Encryption Section
            _buildSectionHeader('SECURITY & ENCRYPTION'),
            _buildGlassCard(
              child: Column(
                children: [
                  _buildInfoTile(
                    icon: Icons.lock,
                    title: 'Database Encryption',
                    value: 'AES-256 SQLCipher',
                    color: AppTheme.accentGreen,
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  _buildInfoTile(
                    icon: Icons.security,
                    title: 'Security Level',
                    value: 'Military Grade',
                    color: AppTheme.accentGreen,
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  _buildInfoTile(
                    icon: Icons.storage,
                    title: 'Database Engine',
                    value: 'SQLCipher 4.x',
                    color: AppTheme.textGray,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Debug Tools Section
            _buildSectionHeader('DEBUG TOOLS'),
            _buildGlassCard(
              child: Column(
                children: [
                  _buildSwitchTile(
                    title: 'Debug Mode',
                    subtitle: 'Show additional developer information',
                    value: _debugMode,
                    onChanged: (val) => setState(() => _debugMode = val),
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  _buildActionTile(
                    icon: Icons.bug_report,
                    title: 'Health Debug',
                    subtitle: 'View permissions & data status',
                    onTap: () => context.push('/health-debug'),
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  _buildActionTile(
                    icon: Icons.storage,
                    title: 'Database Inspector',
                    subtitle: 'View database contents',
                    onTap: () => context.push('/database-test'),
                  ),
                  if (_debugMode) ...[
                    const Divider(color: AppTheme.glassBorder, height: 1),
                    _buildActionTile(
                      icon: Icons.analytics,
                      title: 'Debug Panel',
                      subtitle: 'View system logs',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Debug panel coming soon')),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: AppTheme.captionStyle.copyWith(
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: AppTheme.glassCard(),
      child: child,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: AppTheme.bodyStyle),
      subtitle: Text(subtitle, style: AppTheme.captionStyle),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primaryCyan,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 24),
      title: Text(title, style: AppTheme.bodyStyle),
      trailing: Text(
        value,
        style: AppTheme.bodyStyle.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryCyan, size: 24),
      title: Text(title, style: AppTheme.bodyStyle),
      subtitle: Text(subtitle, style: AppTheme.captionStyle),
      trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.textGray, size: 16),
      onTap: onTap,
    );
  }
}
