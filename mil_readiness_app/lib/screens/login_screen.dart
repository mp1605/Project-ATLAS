import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes.dart';
import '../services/local_secure_store.dart';
import '../services/biometric_auth_service.dart';
import '../config/app_config.dart' as import_config;

class LoginScreen extends StatefulWidget {
  final SessionController session;
  final String? message;

  const LoginScreen({super.key, required this.session, this.message});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _biometricAvailable = false;
  bool _faceIdEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await BiometricAuthService.instance.isBiometricAvailable();
    if (available) {
      final enabled = await BiometricAuthService.instance.isBiometricEnabled();
      setState(() {
        _biometricAvailable = true;
        _faceIdEnabled = enabled;
      });

      // Automatically trigger biometric sign-in if enabled
      if (enabled) {
        Future.delayed(const Duration(milliseconds: 500), _biometricSignIn);
      }
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    if (!_form.currentState!.validate()) {
      setState(() => _loading = false);
      return;
    }

    final ok = await LocalSecureStore.instance.signIn(_email.text, _pass.text);

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _loading = false;
        _error = "Invalid email or password.";
      });
      return;
    }

    widget.session.setSignedIn(true, email: _email.text.trim().toLowerCase());

    // Check if user has completed biometric setup
    final biometricService = BiometricAuthService.instance;
    final hasCompletedSetup = await biometricService.hasCompletedBiometricSetup();
    
    if (!mounted) return;
    
    if (!hasCompletedSetup) {
      // First login - show biometric setup screen
      context.go('/biometric-setup');
    } else {
      // Already set up - go directly to home
      context.go('/home');
    }
  }

  Future<void> _biometricSignIn() async {
    if (!_biometricAvailable || !_faceIdEnabled) return;

    final authenticated = await BiometricAuthService.instance.authenticate(
      reason: 'Sign in to AUIX with ${BiometricAuthService.instance.getBiometricTypeName()}',
    );

    if (authenticated) {
      // Get the stored email and sign in
      final storedEmail = await LocalSecureStore.instance.getStoredUserEmail();
      if (storedEmail != null) {
        widget.session.setSignedIn(true, email: storedEmail);
        if (mounted) context.go('/home');
      } else {
        // No stored email, user needs to enter it first
        if (mounted) {
          setState(() {
            _error = "Please enter your email and sign in once with password to enable biometric login.";
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  // AUIX Logo
                  Image.asset('assets/auix_logo.png', height: 60),
                  const SizedBox(height: 20),
                  Text(
                    "AUIX - Military Readiness",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Secure daily readiness monitoring for military personnel",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 18),

                  if (widget.message != null && widget.message!.trim().isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.withOpacity(0.35)),
                      ),
                      child: Text(widget.message!, style: const TextStyle(fontSize: 14)),
                    ),

                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.withOpacity(0.35)),
                      ),
                      child: Text(_error!, style: const TextStyle(fontSize: 14)),
                    ),
                  ],

                  const SizedBox(height: 14),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _form,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: "Email",
                                prefixIcon: Icon(Icons.alternate_email),
                              ),
                              validator: (v) {
                                final s = (v ?? "").trim();
                                if (s.isEmpty) return "Email is required";
                                if (!s.contains("@")) return "Enter a valid email";
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _pass,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: "Password",
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              validator: (v) {
                                if ((v ?? "").isEmpty) return "Password is required";
                                if ((v ?? "").length < 6) return "Minimum 6 characters";
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (_biometricAvailable)
                                  Row(
                                    children: [
                                      Switch(
                                        value: _faceIdEnabled,
                                        onChanged: (v) {
                                          setState(() => _faceIdEnabled = v);
                                          BiometricAuthService.instance.setBiometricEnabled(v);
                                        },
                                        activeColor: Theme.of(context).primaryColor,
                                      ),
                                      const Text("Face ID", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  )
                                else
                                  const SizedBox.shrink(),
                                TextButton(
                                  onPressed: () => context.push('/forgot-password'),
                                  child: const Text("Forgot Password?", style: TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _loading ? null : _submit,
                                    child: _loading
                                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Text("Sign In"),
                                  ),
                                ),
                                if (_biometricAvailable && _faceIdEnabled) ...[
                                  const SizedBox(width: 12),
                                  IconButton.filledTonal(
                                    onPressed: _loading ? null : _biometricSignIn,
                                    icon: const Icon(Icons.face),
                                    iconSize: 28,
                                    padding: const EdgeInsets.all(12),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loading ? null : () => context.go('/register'),
                              child: const Text("New user? Create account"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
x                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: _showServerSettings,
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text("Server Settings"),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showServerSettings() {
    final controller = TextEditingController(text: import_config.AppConfig.apiBaseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Server Configuration"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter the address of your AUiX ATLAS Server:"),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Server URL",
                hintText: "http://192.168.1.50:8000",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              await import_config.AppConfig.setApiUrl(controller.text.trim());
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Server URL updated to: ${import_config.AppConfig.apiBaseUrl}")),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
