import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/user_profile.dart';
import '../routes.dart';
import '../utils/validation_utils.dart';
import '../services/local_secure_store.dart';
import '../models/wearable_type.dart';
import '../adapters/health_adapter_factory.dart';

class RegisterScreen extends StatefulWidget {
  final SessionController session;
  const RegisterScreen({super.key, required this.session});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();

  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();

  final _watchBrand = TextEditingController();
  final _watchModel = TextEditingController();
  final _background = TextEditingController();

  bool _loading = false;
  bool _obscurePass = true;
  String? _error;

  // Selected wearable device
  WearableType? _selectedWearable;



  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _email.dispose();
    _pass.dispose();
    _pass2.dispose();
    _watchBrand.dispose();
    _watchModel.dispose();
    _background.dispose();
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

    final normalizedEmail = ValidationUtils.normalizeEmail(_email.text);
    final existing = await LocalSecureStore.instance.getRegisteredUser(normalizedEmail);

    if (!mounted) return;

    if (existing != null) {
      setState(() {
        _loading = false;
        _error = "This email is already registered. Please sign in.";
      });
      return;
    }

    final profile = UserProfile(
      email: normalizedEmail,
      fullName: ValidationUtils.normalize(_name.text),
      age: int.parse(ValidationUtils.normalize(_age.text)),
      heightCm: double.parse(ValidationUtils.normalize(_height.text)),
      weightKg: double.parse(ValidationUtils.normalize(_weight.text)),
      backgroundInfo: _background.text.trim().isEmpty ? null : _background.text.trim(),
    );

    await LocalSecureStore.instance.registerUser(profile, _pass.text);

    // Save selected wearable to LocalSecureStore (SINGLE SOURCE OF TRUTH)
    if (_selectedWearable != null) {
      await LocalSecureStore.instance.setSelectedWearableFor(
        normalizedEmail,
        _selectedWearable!.name,
      );
    }

    // After registration, user must sign in again (your requirement)
    if (!mounted) return;
    setState(() => _loading = false);
    context.go('/login?msg=Registration%20successful.%20Please%20sign%20in%20again.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: ListView(
                children: [
                  Text(
                    "New Personnel Profile",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "This information is used to personalize readiness scoring and device integration.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 14),

                  if (_error != null)
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

                  const SizedBox(height: 12),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _form,
                        child: Column(
                          children: [
                            // Personal
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _name,
                                    decoration: const InputDecoration(
                                      labelText: "Full Name",
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: ValidationUtils.validateName,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _age,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: "Age",
                                      prefixIcon: Icon(Icons.numbers),
                                    ),
                                    validator: ValidationUtils.validateAge,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _height,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: "Height (cm)",
                                      prefixIcon: Icon(Icons.height),
                                    ),
                                    validator: ValidationUtils.validateHeight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _weight,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Weight (kg)",
                                prefixIcon: Icon(Icons.monitor_weight_outlined),
                              ),
                              validator: ValidationUtils.validateWeight,
                            ),

                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),

                            // Account
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: "Email",
                                prefixIcon: Icon(Icons.alternate_email),
                              ),
                              validator: ValidationUtils.validateEmail,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _pass,
                              obscureText: _obscurePass,
                              decoration: InputDecoration(
                                labelText: "Password",
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                ),
                              ),
                              validator: ValidationUtils.validatePassword,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _pass2,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: "Confirm Password",
                                prefixIcon: Icon(Icons.lock_reset),
                              ),
                              validator: (v) {
                                if ((v ?? "").isEmpty) return "Confirm password";
                                if (v != _pass.text) return "Passwords do not match";
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),

                            // Device Selection
                            const Text(
                              "Which wearable device do you use?",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            
                            // Wearable device picker
                            _buildWearableSelector(),
                            
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _watchModel,
                              decoration: const InputDecoration(
                                labelText: "Watch Model (e.g., Series 9, Forerunner 255)",
                                prefixIcon: Icon(Icons.devices_other_outlined),
                                helperText: "Optional: Specific model of your device",
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _background,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: "Additional info (optional)",
                                prefixIcon: Icon(Icons.notes_outlined),
                              ),
                            ),

                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text("Create Account"),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loading ? null : () => context.go('/login'),
                              child: const Text("Back to Sign In"),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildWearableSelector() {
    final availableDevices = HealthAdapterFactory.getAvailableWearables();
    final implementedDevices = HealthAdapterFactory.getImplementedAdapters();

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: availableDevices.length,
        itemBuilder: (context, index) {
          final device = availableDevices[index];
          final isImplemented = implementedDevices.contains(device);
          final isSelected = _selectedWearable == device;

          return GestureDetector(
            onTap: () => setState(() => _selectedWearable = device),
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                gradient: isSelected ? _getDeviceGradient(device) : null,
                color: isSelected ? null : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getDeviceIcon(device),
                    size: 36,
                    color: isSelected ? Colors.white : Colors.blue[700],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    device.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.2)
                          : (isImplemented ? Colors.green[50] : Colors.orange[50]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isImplemented ? '✅' : '🚧',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getDeviceIcon(WearableType device) {
    switch (device) {
      case WearableType.appleWatch:
        return Icons.watch;
      case WearableType.garmin:
        return Icons.fitness_center;
      case WearableType.samsung:
      case WearableType.pixelWatch:
        return Icons.watch_later;
      case WearableType.fitbit:
        return Icons.favorite;
      case WearableType.ouraRing:
        return Icons.radio_button_unchecked;
      case WearableType.whoop:
        return Icons.trending_up;
      case WearableType.casio:
        return Icons.timer;
      case WearableType.amazfit:
        return Icons.sports_score;
      case WearableType.polar:
        return Icons.explore;
      case WearableType.other:
        return Icons.devices_other;
    }
  }

  LinearGradient _getDeviceGradient(WearableType device) {
    switch (device) {
      case WearableType.appleWatch:
        return const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]);
      case WearableType.garmin:
        return const LinearGradient(colors: [Color(0xFF11998e), Color(0xFF38ef7d)]);
      case WearableType.samsung:
        return const LinearGradient(colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)]);
      case WearableType.fitbit:
        return const LinearGradient(colors: [Color(0xFF00d2ff), Color(0xFF3a7bd5)]);
      case WearableType.ouraRing:
        return const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]);
      case WearableType.whoop:
        return const LinearGradient(colors: [Color(0xFFf46b45), Color(0xFFeea849)]);
      case WearableType.polar:
        return const LinearGradient(colors: [Color(0xFF4facfe), Color(0xFF00f2fe)]);
      case WearableType.amazfit:
        return const LinearGradient(colors: [Color(0xFFfa709a), Color(0xFFfee140)]);
      case WearableType.casio:
        return const LinearGradient(colors: [Color(0xFF43e97b), Color(0xFF38f9d7)]);
      case WearableType.pixelWatch:
        return const LinearGradient(colors: [Color(0xFF5f72bd), Color(0xFF9b23ea)]);
      case WearableType.other:
        return const LinearGradient(colors: [Color(0xFF757F9A), Color(0xFFD7DDE8)]);
    }
  }
}
