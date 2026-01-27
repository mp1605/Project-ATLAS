import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/biometric_auth_service.dart';
import '../config/security_config.dart';

/// Lock screen displayed when app is locked
/// 
/// Shows biometric authentication prompt with fallback options
class LockScreen extends StatefulWidget {
  final VoidCallback onAuthenticationSuccess;
  
  const LockScreen({
    super.key,
    required this.onAuthenticationSuccess,
  });
  
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _biometricService = BiometricAuthService.instance;
  bool _isAuthenticating = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    // Auto-prompt for biometric on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }
  
  /// Authenticate with biometrics
  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });
    
    try {
      final authenticated = await _biometricService.authenticate(
        reason: SecurityConfig.biometricPromptMessage,
      );
      
      if (authenticated) {
        widget.onAuthenticationSuccess();
      } else {
        setState(() {
          _errorMessage = 'Authentication failed. Please try again.';
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isAuthenticating = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27), // Dark military blue
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.shade400,
                        Colors.cyan.shade600,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Title
                Text(
                  'Secure Access',
                  style: GoogleFonts.orbitron(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Subtitle
                Text(
                  'MILITARY READINESS',
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.cyan.shade300,
                    letterSpacing: 3,
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // Biometric icon/button
                GestureDetector(
                  onTap: _isAuthenticating ? null : _authenticate,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.cyan.shade400,
                        width: 3,
                      ),
                      color: Colors.transparent,
                    ),
                    child: _isAuthenticating
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
                            ),
                          )
                        : Icon(
                            Icons.fingerprint,
                            size: 40,
                            color: Colors.cyan.shade400,
                          ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Instruction text
                Text(
                  _isAuthenticating
                      ? 'Authenticating...'
                      : 'Tap to authenticate',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Biometric type
                FutureBuilder<String>(
                  future: _getBiometricTypeName(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Text(
                        'Using ${snapshot.data}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.cyan.shade300,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                
                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.shade700,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade300,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.red.shade300,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 60),
                
                // Info text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.white60,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Your data is secured with military-grade encryption',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Future<String> _getBiometricTypeName() async {
    final biometrics = await _biometricService.getAvailableBiometrics();
    if (biometrics.isEmpty) {
      return 'Biometric Authentication';
    }
    
    // Return user-friendly name
    return _biometricService.getBiometricTypeName();
  }
}
