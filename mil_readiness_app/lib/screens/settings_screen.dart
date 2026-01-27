import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/local_secure_store.dart';
import '../services/biometric_auth_service.dart';
import '../services/haptic_service.dart';
import '../routes.dart';
import '../services/session_controller.dart';
import 'package:intl/intl.dart';

/// User-friendly Settings screen
/// 
/// All technical/developer items have been moved to DeveloperDiagnosticsScreen.
/// Access Developer section by tapping version 7 times.
class SettingsScreen extends StatefulWidget {
  final SessionController session;
  const SettingsScreen({super.key, required this.session});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String get _email => widget.session.email ?? '';
  
  // User settings
  bool _consent = false;
  bool _healthAuthorized = false;
  bool _biometricEnabled = false;
  
  // Preferences
  bool _notificationsEnabled = true;
  String _units = 'imperial'; // 'imperial' or 'metric'
  String _theme = 'system'; // 'system', 'dark', 'light'
  double _textScale = 1.0;
  bool _reduceMotion = false;
  
  // Developer mode
  int _versionTapCount = 0;
  bool _developerModeUnlocked = false;
  
  // Profile Info
  DateTime? _lastSync;
  String? _selectedDevice;
  
  final _biometricService = BiometricAuthService.instance;
  
  // Storage keys for preferences
  static const _keyNotifications = 'pref_notifications';
  static const _keyUnits = 'pref_units';
  static const _keyTheme = 'pref_theme';
  static const _keyTextScale = 'pref_text_scale';
  static const _keyReduceMotion = 'pref_reduce_motion';
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final consent = await LocalSecureStore.instance.getRawDataShareConsentFor(_email);
    final authorized = await LocalSecureStore.instance.getHealthAuthorizedFor(_email);
    final biometric = await _biometricService.isBiometricEnabled();
    final lastSync = await LocalSecureStore.instance.getHealthLastSyncAtFor(_email);
    final selectedDevice = await LocalSecureStore.instance.getSelectedWearableFor(_email);
    
    // Load preferences
    final store = LocalSecureStore.instance;
    final notifications = await store.getString(_keyNotifications);
    final units = await store.getString(_keyUnits);
    final theme = await store.getString(_keyTheme);
    final textScale = await store.getString(_keyTextScale);
    final reduceMotion = await store.getString(_keyReduceMotion);
    
    if (mounted) {
      setState(() {
        _consent = consent ?? false;
        _healthAuthorized = authorized ?? false;
        _biometricEnabled = biometric;
        _notificationsEnabled = notifications != 'false';
        _units = units ?? 'imperial';
        _theme = theme ?? 'system';
        _textScale = double.tryParse(textScale ?? '1.0') ?? 1.0;
        _reduceMotion = reduceMotion == 'true';
        _lastSync = lastSync;
        _selectedDevice = selectedDevice;
      });
    }
  }
  
  Future<void> _toggleConsent(bool value) async {
    await HapticService.light();
    await LocalSecureStore.instance.setRawDataShareConsentFor(_email, value);
    setState(() => _consent = value);
  }
  
  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final success = await _biometricService.authenticate(
        reason: 'Authenticate to enable biometric lock',
      );
      if (success) {
        await HapticService.success();
        await _biometricService.setBiometricEnabled(true);
        setState(() => _biometricEnabled = true);
      } else {
        await HapticService.warning();
      }
    } else {
      await HapticService.light();
      await _biometricService.setBiometricEnabled(false);
      setState(() => _biometricEnabled = false);
    }
  }
  
  Future<void> _toggleNotifications(bool value) async {
    await HapticService.light();
    await LocalSecureStore.instance.setString(_keyNotifications, value.toString());
    setState(() => _notificationsEnabled = value);
  }
  
  Future<void> _setUnits(String value) async {
    await LocalSecureStore.instance.setString(_keyUnits, value);
    setState(() => _units = value);
  }
  
  Future<void> _setTheme(String value) async {
    await LocalSecureStore.instance.setString(_keyTheme, value);
    setState(() => _theme = value);
    
    // Update global app theme reactive state
    widget.session.setThemeMode(
      value == 'dark' ? ThemeMode.dark : (value == 'light' ? ThemeMode.light : ThemeMode.system)
    );
  }
  
  void _handleVersionTap() {
    _versionTapCount++;
    if (_versionTapCount >= 7 && !_developerModeUnlocked) {
      HapticService.success();
      setState(() => _developerModeUnlocked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Developer Mode Enabled'),
          backgroundColor: AppTheme.accentOrange,
        ),
      );
    } else if (_versionTapCount < 7 && _versionTapCount >= 4) {
      HapticService.selection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${7 - _versionTapCount} taps to developer mode'),
          duration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('SETTINGS', style: AppTheme.titleStyle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkGradient : AppTheme.lightGradient,
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ===========================================
            // PROFILE SECTION
            // ===========================================
            _buildSectionHeader('PROFILE'),
            _buildGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: AppTheme.cyanGradient,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryCyan.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _email.isNotEmpty ? _email[0].toUpperCase() : 'U',
                          style: AppTheme.titleStyle.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _email.contains('@') ? _email.split('@')[0] : 'User Profile',
                            style: AppTheme.titleStyle.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _email,
                            style: AppTheme.captionStyle.copyWith(
                              color: isDark ? AppTheme.textGray : AppTheme.textDarkGray,
                            ),
                          ),
                          const Divider(height: 16, color: AppTheme.glassBorder),
                          Row(
                            children: [
                              Icon(Icons.sync, size: 12, color: AppTheme.accentGreen),
                              const SizedBox(width: 4),
                              Text(
                                _lastSync != null ? DateFormat('MMM d, h:mm a').format(_lastSync!) : 'Never',
                                style: AppTheme.captionStyle.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.watch, size: 12, color: AppTheme.primaryCyan),
                              const SizedBox(width: 4),
                              Text(
                                _selectedDevice ?? 'No device connected',
                                style: AppTheme.captionStyle.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // ===========================================
            // SECURITY & PRIVACY SECTION
            // ===========================================
            _buildSectionHeader('SECURITY & PRIVACY'),
            _buildGlassCard(
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.fingerprint,
                    title: 'Biometric Lock',
                    subtitle: 'Use Face ID or Touch ID to unlock',
                    value: _biometricEnabled,
                    onChanged: _toggleBiometric,
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  _buildSwitchTile(
                    icon: Icons.science,
                    title: 'Research Data Sharing',
                    subtitle: 'Share anonymous data for research',
                    value: _consent,
                    onChanged: _toggleConsent,
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  ListTile(
                    leading: const Icon(Icons.shield, color: AppTheme.accentGreen, size: 24),
                    title: Text('Data Protection', style: AppTheme.bodyStyle),
                    subtitle: Text(
                      'Your health data is encrypted and stored only on this device',
                      style: AppTheme.captionStyle,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // ===========================================
            // PREFERENCES SECTION
            // ===========================================
            _buildSectionHeader('PREFERENCES'),
            _buildGlassCard(
              child: Column(
                children: [
                  // Notifications
                  _buildSwitchTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Daily readiness alerts & reminders',
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  
                  // Units
                  _buildPickerTile(
                    icon: Icons.straighten,
                    title: 'Units',
                    value: _units == 'imperial' ? 'Imperial (lbs, mi)' : 'Metric (kg, km)',
                    onTap: () => _showUnitsPicker(),
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  
                  // Theme
                  _buildPickerTile(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    value: _theme == 'system' ? 'System' : (_theme == 'dark' ? 'Dark' : 'Light'),
                    onTap: () => _showThemePicker(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // ===========================================
            // DATA SOURCES SECTION
            // ===========================================
            _buildSectionHeader('DATA SOURCES'),
            _buildGlassCard(
              child: Column(
                children: [
                  _buildInfoTile(
                    icon: Icons.favorite,
                    title: 'Health Connection',
                    value: _healthAuthorized ? 'Operational' : 'Disconnected',
                    color: _healthAuthorized ? AppTheme.accentGreen : AppTheme.accentOrange,
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  _buildActionTile(
                    icon: Icons.sync_problem,
                    title: 'Troubleshoot Sync',
                    subtitle: 'Reset and re-authorize health data',
                    onTap: () => context.push('/wearable-select'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // ===========================================
            // HELP & ABOUT SECTION
            // ===========================================
            _buildSectionHeader('HELP & ABOUT'),
            _buildGlassCard(
              child: Column(
                children: [
                  _buildActionTile(
                    icon: Icons.help_outline,
                    title: 'How Readiness Works',
                    subtitle: 'Learn about your scores',
                    onTap: () => context.push('/readiness-info'),
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  _buildActionTile(
                    icon: Icons.privacy_tip,
                    title: 'Privacy Policy',
                    subtitle: 'How we protect your data',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Privacy policy coming soon')),
                      );
                    },
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  _buildActionTile(
                    icon: Icons.delete_forever,
                    title: 'Emergency Data Purge',
                    subtitle: 'Wipe all local and secure data',
                    onTap: () => _confirmDataPurge(),
                  ),
                  InkWell(
                    onTap: _handleVersionTap,
                    child: ListTile(
                      leading: const Icon(Icons.info_outline, color: AppTheme.textGray, size: 24),
                      title: Text('Version', style: AppTheme.bodyStyle),
                      trailing: Text(
                        '1.0.0',
                        style: AppTheme.bodyStyle.copyWith(
                          color: AppTheme.textGray,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // ===========================================
            // DEVELOPER SECTION (hidden until unlocked)
            // ===========================================
            if (_developerModeUnlocked) ...[
              const SizedBox(height: 24),
              _buildSectionHeader('DEVELOPER'),
              _buildGlassCard(
                child: Column(
                  children: [
                    _buildActionTile(
                      icon: Icons.developer_mode,
                      title: 'Developer Tools',
                      subtitle: 'Technical diagnostics & debug',
                      onTap: () => context.push('/developer-diagnostics'),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  
  // ===========================================
  // PICKERS & SHEETS
  // ===========================================
  
  void _showUnitsPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Units', style: AppTheme.titleStyle),
            const SizedBox(height: 20),
            _buildRadioOption(
              title: 'Imperial (lbs, mi, °F)',
              value: 'imperial',
              groupValue: _units,
              onTap: () {
                _setUnits('imperial');
                Navigator.pop(context);
              },
            ),
            _buildRadioOption(
              title: 'Metric (kg, km, °C)',
              value: 'metric',
              groupValue: _units,
              onTap: () {
                _setUnits('metric');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Theme', style: AppTheme.titleStyle),
            const SizedBox(height: 20),
            _buildRadioOption(
              title: 'System Default',
              value: 'system',
              groupValue: _theme,
              onTap: () {
                _setTheme('system');
                Navigator.pop(context);
              },
            ),
            _buildRadioOption(
              title: 'Dark Mode',
              value: 'dark',
              groupValue: _theme,
              onTap: () {
                _setTheme('dark');
                Navigator.pop(context);
              },
            ),
            _buildRadioOption(
              title: 'Light Mode',
              value: 'light',
              groupValue: _theme,
              onTap: () {
                _setTheme('light');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  
  Widget _buildRadioOption({
    required String title,
    required String value,
    required String groupValue,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = value == groupValue;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppTheme.primaryCyan : (isDark ? AppTheme.textGray : AppTheme.textDarkGray),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: AppTheme.bodyStyle.copyWith(
                color: isSelected 
                  ? (isDark ? AppTheme.textWhite : AppTheme.primaryBlue) 
                  : (isDark ? AppTheme.textGray : AppTheme.textDarkGray),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================
  // UI BUILDERS
  // ===========================================

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: isDark 
        ? AppTheme.glassCard() 
        : BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
      child: child,
    );
  }

  Widget _buildSwitchTile({
    IconData? icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: icon != null ? Icon(icon, color: AppTheme.primaryCyan, size: 24) : null,
      title: Text(title, style: AppTheme.bodyStyle),
      subtitle: Text(subtitle, style: AppTheme.captionStyle),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primaryCyan,
    );
  }
  
  Widget _buildPickerTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryCyan, size: 24),
      title: Text(title, style: AppTheme.bodyStyle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTheme.captionStyle.copyWith(
              color: isDark ? AppTheme.primaryCyan : AppTheme.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_ios, color: isDark ? AppTheme.textGray : AppTheme.textDarkGray, size: 16),
        ],
      ),
      onTap: onTap,
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

  void _confirmDataPurge() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purge All Data?'),
        content: const Text(
          'This will permanently delete your profile, all health records, and settings. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // CRITICAL: Clear session FIRST to prevent biometric re-auth
              await LocalSecureStore.instance.clearSession();
              
              // Also unlock the biometric lock so Face ID doesn't trigger
              _biometricService.unlockApp();
              
              // Now purge all data
              await LocalSecureStore.instance.clearAllData();
              
              if (mounted) {
                widget.session.setSignedIn(false, email: null);
                context.go('/login');
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.accentRed),
            child: const Text('PURGE EVERYTHING'),
          ),
        ],
      ),
    );
  }
}
