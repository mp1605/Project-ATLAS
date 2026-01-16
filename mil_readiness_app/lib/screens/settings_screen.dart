import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/local_secure_store.dart';
import '../routes.dart';

/// Settings screen for admin/technical controls (no LiveSync - that's in home screen)
class SettingsScreen extends StatefulWidget {
  final SessionController session;
  const SettingsScreen({super.key, required this.session});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String get _email => widget.session.email ?? '';
  
  bool _consent = false;
  bool _healthAuthorized = false;
  bool _debugMode = false;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final consent = await LocalSecureStore.instance.getRawDataShareConsentFor(_email);
    final authorized = await LocalSecureStore.instance.getHealthAuthorizedFor(_email);
    
    setState(() {
      _consent = consent ?? false;
      _healthAuthorized = authorized ?? false;
    });
  }
  
  Future<void> _toggleConsent(bool value) async {
    await LocalSecureStore.instance.setRawDataShareConsentFor(_email, value);
    setState(() => _consent = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text('SETTINGS', style: AppTheme.titleStyle),
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
            // Privacy & Security Section
            _buildSectionHeader('PRIVACY & SECURITY'),
            _buildGlassCard(
              child: Column(
                children: [
                  _buildSwitchTile(
                    title: 'Raw Data Consent',
                    subtitle: 'Allow anonymous data sharing for research',
                    value: _consent,
                    onChanged: _toggleConsent,
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  _buildInfoTile(
                    icon: Icons.lock,
                    title: 'Database Encryption',
                    value: 'AES-256 SQLCipher',
                    color: AppTheme.accentGreen,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Data Collection Section
            _buildSectionHeader('DATA COLLECTION'),
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
                  _buildActionTile(
                    icon: Icons.bug_report,
                    title: 'Health Debug',
                    subtitle: 'View permissions & data status',
                    onTap: () => context.push('/health-debug'),
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  _buildInfoTile(
                    icon: Icons.health_and_safety,
                    title: 'Apple Health',
                    value: _healthAuthorized ? 'Authorized' : 'Not Authorized',
                    color: _healthAuthorized ? AppTheme.accentGreen : AppTheme.accentOrange,
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
                    subtitle: Text('Check terminal for live collection logs every 60s', style: AppTheme.captionStyle),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Developer Section
            _buildSectionHeader('DEVELOPER'),
            _buildGlassCard(
              child: Column(
                children: [
                  _buildSwitchTile(
                    title: 'Debug Mode',
                    subtitle: 'Show developer information',
                    value: _debugMode,
                    onChanged: (val) => setState(() => _debugMode = val),
                  ),
                  if (_debugMode) ...[
                    const Divider(color: AppTheme.glassBorder, height: 1),
                    _buildActionTile(
                      icon: Icons.bug_report,
                      title: 'Debug Panel',
                      subtitle: 'View system logs',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Debug panel coming soon')),
                        );
                      },
                    ),
                    const Divider(color: AppTheme.glassBorder, height: 1),
                    _buildActionTile(
                      icon: Icons.storage,
                      title: 'Database Inspector',
                      subtitle: 'View database contents',
                      onTap: () => context.push('/database-test'),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // About Section
            _buildSectionHeader('ABOUT'),
            _buildGlassCard(
              child: Column(
                children: [
                  _buildInfoTile(
                    icon: Icons.info_outline,
                    title: 'App Version',
                    value: '1.0.0',
                    color: AppTheme.textGray,
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
                    title: 'Database',
                    value: 'SQLCipher 4.x',
                    color: AppTheme.textGray,
                  ),
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
