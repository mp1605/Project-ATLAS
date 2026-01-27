import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/local_secure_store.dart';

/// Email verification helper service
/// Manages verification state and resend timing (rate limiting)
class EmailVerificationService {
  static final EmailVerificationService _instance = EmailVerificationService._internal();
  factory EmailVerificationService() => _instance;
  EmailVerificationService._internal();

  // Track last resend time for rate limiting (per email)
  final Map<String, DateTime> _lastResendTime = {};
  
  // Cooldown period between resend attempts (60 seconds)
  static const Duration _resendCooldown = Duration(seconds: 60);

  /// Check if email is verified
  Future<bool> isEmailVerified(String email) async {
    return await LocalSecureStore.instance.isEmailVerifiedFor(email);
  }

  /// Set email verification status (for backend integration)
  Future<void> setEmailVerified(String email, bool verified) async {
    await LocalSecureStore.instance.setEmailVerifiedFor(email, verified);
  }

  /// Check if user can resend verification email (rate limit check)
  bool canResendVerification(String email) {
    final lastSent = _lastResendTime[email];
    if (lastSent == null) return true;
    
    final elapsed = DateTime.now().difference(lastSent);
    return elapsed >= _resendCooldown;
  }

  /// Get remaining cooldown time in seconds
  int getRemainingCooldown(String email) {
    final lastSent = _lastResendTime[email];
    if (lastSent == null) return 0;
    
    final elapsed = DateTime.now().difference(lastSent);
    final remaining = _resendCooldown - elapsed;
    
    return remaining.isNegative ? 0 : remaining.inSeconds;
  }

  /// Request verification email resend
  /// Returns true if successful, false if rate limited
  Future<bool> resendVerificationEmail(String email) async {
    if (!canResendVerification(email)) {
      return false;
    }

    // TODO: Replace with actual backend API call when ready
    // For now, just update the rate limit timestamp
    _lastResendTime[email] = DateTime.now();
    
    // Simulate backend delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    print('📧 [Email Verification] Resend requested for: $email');
    print('   (Backend integration pending - this is UI-only)');
    
    return true;
  }

  /// Show verification email sent confirmation
  void showVerificationSentSnackBar(BuildContext context, String email) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verification email sent',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Check $email for the verification link',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show rate limit error
  void showRateLimitSnackBar(BuildContext context, int remainingSeconds) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.schedule, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Please wait $remainingSeconds seconds before resending',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show backend integration pending notice (for development)
  void showBackendPendingNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Email verification ready - backend integration pending',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
