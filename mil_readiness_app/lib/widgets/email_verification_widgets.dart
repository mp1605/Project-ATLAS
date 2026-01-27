import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Non-blocking email verification notice banner
/// Shows on home screen when email is unverified
/// Prepared for future backend verification integration
class EmailVerificationBanner extends StatelessWidget {
  final VoidCallback onResendVerification;
  final VoidCallback onDismiss;
  
  const EmailVerificationBanner({
    super.key,
    required this.onResendVerification,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade700.withOpacity(0.15),
            Colors.orange.shade900.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.shade600.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mark_email_unread_outlined,
                color: Colors.orange.shade400,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Email Verification Recommended',
                  style: TextStyle(
                    color: Colors.orange.shade300,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: Colors.orange.shade400,
                ),
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Verify your email to ensure account security and enable password recovery.',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onResendVerification,
                icon: const Icon(Icons.send_outlined, size: 16),
                label: const Text('Resend Verification'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange.shade300,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Email verification status indicator
/// Shows verification state in settings or profile
class EmailVerificationStatus extends StatelessWidget {
  final bool isVerified;
  final VoidCallback? onVerify;
  
  const EmailVerificationStatus({
    super.key,
    required this.isVerified,
    this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isVerified 
          ? Colors.green.shade900.withOpacity(0.2)
          : Colors.orange.shade900.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isVerified 
            ? Colors.green.shade600.withOpacity(0.3)
            : Colors.orange.shade600.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.verified_outlined : Icons.pending_outlined,
            size: 16,
            color: isVerified ? Colors.green.shade400 : Colors.orange.shade400,
          ),
          const SizedBox(width: 6),
          Text(
            isVerified ? 'Verified' : 'Unverified',
            style: TextStyle(
              color: isVerified ? Colors.green.shade300 : Colors.orange.shade300,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!isVerified && onVerify != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onVerify,
              child: Text(
                'Verify Now',
                style: TextStyle(
                  color: Colors.orange.shade200,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
