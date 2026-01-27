import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Privacy & Security Summary Card (Home screen - bottom, calm)
/// Shows reassuring, static privacy features - NO toggles, NO technical jargon
class PrivacySummaryCard extends StatelessWidget {
  final VoidCallback? onTap;
  
  const PrivacySummaryCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.bgDark.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.accentGreen.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.security_outlined,
                  color: AppTheme.accentGreen,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Privacy & Security',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppTheme.textWhite,
                  ),
                ),
                const Spacer(),
                if (onTap != null)
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.textGray,
                    size: 16,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _buildPrivacyPoint('Data encrypted on your device'),
            const SizedBox(height: 8),
            _buildPrivacyPoint('No raw health data uploaded'),
            const SizedBox(height: 8),
            _buildPrivacyPoint('Works offline'),
            const SizedBox(height: 8),
            _buildPrivacyPoint('You control syncing'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPrivacyPoint(String text) {
    return Row(
      children: [
        Icon(
          Icons.check_circle_outline,
          color: AppTheme.accentGreen,
          size: 14,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppTheme.textLight,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Privacy & Security Info Screen (detailed explanation, calm)
/// Accessed by tapping the privacy summary card
class PrivacyInfoScreen extends StatelessWidget {
  const PrivacyInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Your Data Security'),
            const SizedBox(height: 12),
            _buildInfoCard(
              icon: Icons.lock_outline,
              title: 'Device Encryption',
              description: 'Your health data is encrypted and stored securely on your device using device security features.',
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              icon: Icons.cloud_off_outlined,
              title: 'Offline-First',
              description: 'The app works completely offline. Your readiness scores are calculated locally on your device.',
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              icon: Icons.shield_outlined,
              title: 'Data Protection',
              description: 'No raw health data is uploaded. Only anonymized, aggregated scores are synced if you choose.',
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              icon: Icons.person_outline,
              title: 'You\'re in Control',
              description: 'You decide when to sync, what to share, and can delete your data at any time.',
            ),
            const SizedBox(height: 28),
            _buildSectionHeader('Security Status'),
            const SizedBox(height: 12),
            _buildSecurityStatusBadge(),
            const SizedBox(height: 28),
            _buildSectionHeader('Privacy Best Practices'),
            const SizedBox(height: 12),
            _buildBestPracticePoint('Enable device passcode or biometric lock'),
            const SizedBox(height: 10),
            _buildBestPracticePoint('Keep your app updated'),
            const SizedBox(height: 10),
            _buildBestPracticePoint('Review health data permissions regularly'),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'Your privacy is our priority.',
                style: TextStyle(
                  color: AppTheme.textGray,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        color: AppTheme.textWhite,
      ),
    );
  }
  
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.glassBorder.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryCyan, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textLight,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSecurityStatusBadge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.accentGreen.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppTheme.accentGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security Status: Active',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textWhite,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your data is encrypted and protected using device security features.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textLight,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBestPracticePoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.primaryCyan.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppTheme.textLight,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Permission Awareness Banner (calm, non-blocking)
/// Shows when health permissions are partial or missing
class PermissionAwarenessBanner extends StatelessWidget {
  final VoidCallback? onTap;
  
  const PermissionAwarenessBanner({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.accentOrange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.accentOrange.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: AppTheme.accentOrange,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Some data sources are unavailable. Readiness may be less accurate.',
                style: TextStyle(
                  color: AppTheme.accentOrange,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
