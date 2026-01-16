import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes.dart';
import '../services/local_secure_store.dart';
import '../adapters/health_adapter_factory.dart';
import '../models/wearable_type.dart';

class AuthorizeScreen extends StatefulWidget {
  final SessionController session;
  const AuthorizeScreen({super.key, required this.session});

  @override
  State<AuthorizeScreen> createState() => _AuthorizeScreenState();
}

class _AuthorizeScreenState extends State<AuthorizeScreen> {
  bool _busy = false;

  bool _authorized = false;
  DateTime? _checkedAt;

  String? _email;
  bool _loading = true;
  
  // Device status
  WearableType? _selectedWearable;
  bool _isDeviceImplemented = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final email = widget.session.email ?? await LocalSecureStore.instance.getActiveSessionEmail();
    if (!mounted) return;

    if (email == null || email.isEmpty) {
      context.go('/login?msg=Session%20expired');
      return;
    }

    final auth = await LocalSecureStore.instance.getHealthAuthorizedFor(email);
    final checked = await LocalSecureStore.instance.getHealthAuthCheckedAtFor(email);
    
    // Get selected wearable
    final selectedWearableName = await LocalSecureStore.instance.getSelectedWearableFor(email);
    WearableType? wearableType;
    bool isImplemented = true;
    
    if (selectedWearableName != null) {
      try {
        wearableType = WearableType.values.byName(selectedWearableName);
        isImplemented = HealthAdapterFactory.isImplemented(wearableType);
      } catch (e) {
        // Invalid device in storage
        wearableType = WearableType.appleWatch;
      }
    } else {
      wearableType = WearableType.appleWatch;
    }

    if (!mounted) return;
    setState(() {
      _email = email;
      _authorized = auth;
      _checkedAt = checked;
      _selectedWearable = wearableType;
      _isDeviceImplemented = isImplemented;
      _loading = false;
    });
  }

  Future<void> _requestHealthPermission() async {
    if (_busy || _email == null) return;
    
    // Check if device is implemented
    if (!_isDeviceImplemented) {
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Device Not Available Yet'),
            content: Text(
              '${_selectedWearable?.displayName ?? 'This device'} integration is coming soon! '
              'For now, please use Apple Watch or wait for future updates.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }
    
    setState(() => _busy = true);

    try {
      // Get user's selected wearable
      final selectedWearableName = await LocalSecureStore.instance.getSelectedWearableFor(_email!);
      
      // Default to Apple Watch if no selection (backward compatibility)
      final wearableType = selectedWearableName != null
          ? WearableType.values.byName(selectedWearableName)
          : WearableType.appleWatch;

      // Create appropriate adapter
      final adapter = HealthAdapterFactory.createAdapter(wearableType);

      // Request permissions using the adapter
      final authorized = await adapter.requestPermissions();

      await LocalSecureStore.instance.setHealthAuthorizedFor(_email!, authorized);
      await LocalSecureStore.instance.setHealthAuthCheckedAtFor(_email!, DateTime.now());

      // ✅ PER USER baseline sync status
      await LocalSecureStore.instance.setHealthLastSyncStatusFor(_email!, "idle");

      await _load();
    } catch (e) {
      print('❌ Authorization error: $e');
      // ✅ PER USER error status
      await LocalSecureStore.instance.setHealthLastSyncStatusFor(_email!, "error");
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueToHome({required bool allowWithoutHealth}) async {
    if (_email == null) return;

    // If you want strict flow:
    // - If not authorized, don't allow normal continue unless allowWithoutHealth == true.
    if (!_authorized && !allowWithoutHealth) return;

    await LocalSecureStore.instance.setAuthorizeCompletedFor(_email!, true);

    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _resetThisStep() async {
    if (_email == null) return;

    // This resets APP state only (does NOT revoke iOS Health permission).
    await LocalSecureStore.instance.clearHealthAuthStatusFor(_email!);
    await LocalSecureStore.instance.setAuthorizeCompletedFor(_email!, false);

    // Also reset sync flags for this user (optional)
    await LocalSecureStore.instance.setHealthLastSyncStatusFor(_email!, "idle");

    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final statusText = _authorized ? "Connected" : "Not connected";
    final checkedText = _checkedAt == null ? "Last checked: never" : "Last checked: ${_checkedAt!.toLocal()}";

    return Scaffold(
      appBar: AppBar(title: const Text("Wearable Authorization")),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite_outline, size: 44),
                      const SizedBox(height: 12),
                      Text(
                        "Authorize ${_selectedWearable?.displayName ?? 'Device'}",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      if (!_isDeviceImplemented)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '🚧 Coming Soon',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        "We request READ-only access to minimal metrics for live sync (heart rate, steps, active energy).",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Status
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Status: $statusText"),
                            const SizedBox(height: 4),
                            Text(checkedText, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      FilledButton(
                        onPressed: _busy ? null : _requestHealthPermission,
                        child: Text(_busy ? "Requesting…" : "Request Apple Health Permission"),
                      ),

                      const SizedBox(height: 10),

                      // ✅ Strict continue (only when authorized)
                      FilledButton.tonal(
                        onPressed: _authorized ? () => _continueToHome(allowWithoutHealth: false) : null,
                        child: const Text("Continue to Home (requires connected)"),
                      ),

                      const SizedBox(height: 6),

                      // Optional “continue anyway” (production-friendly)
                      TextButton(
                        onPressed: () => _continueToHome(allowWithoutHealth: true),
                        child: const Text("Continue anyway (connect later from Home)"),
                      ),

                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _resetThisStep,
                        child: const Text("Reset authorization step (app state)"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
