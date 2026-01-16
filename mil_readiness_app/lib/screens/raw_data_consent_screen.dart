import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/local_secure_store.dart';

class RawDataConsentScreen extends StatefulWidget {
  /// editMode=false: onboarding flow (Continue -> /authorize)
  /// editMode=true : opened from Home (Save -> pop back to Home)
  final bool editMode;

  const RawDataConsentScreen({super.key, required this.editMode});

  @override
  State<RawDataConsentScreen> createState() => _RawDataConsentScreenState();
}

class _RawDataConsentScreenState extends State<RawDataConsentScreen> {
  bool _shareRaw = false;
  bool _saving = false;

  String? _email;
  bool _loading = true;

  bool? _initialConsent; // track previous state for NO->YES confirmation

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final email = await LocalSecureStore.instance.getActiveSessionEmail();
    if (!mounted) return;

    if (email == null || email.isEmpty) {
      context.go('/login?msg=Session%20expired');
      return;
    }

    final existing = await LocalSecureStore.instance.getRawDataShareConsentFor(email);

    if (!mounted) return;
    setState(() {
      _email = email;
      _initialConsent = existing; // null if never decided
      _shareRaw = existing ?? false;
      _loading = false;
    });
  }

  Future<bool> _confirmNoToYesIfNeeded() async {
    final wasExplicitNo = (_initialConsent == false);
    final nowYes = (_shareRaw == true);

    if (!wasExplicitNo || !nowYes) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Confirm privacy mode change"),
          content: const Text(
            "You previously chose NOT to share raw wearable data.\n\n"
            "Switching to YES allows raw data sharing, which reduces privacy.\n\n"
            "Are you sure you want to enable raw data sharing?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text("Enable"),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _save() async {
    if (_email == null) return;

    final ok = await _confirmNoToYesIfNeeded();
    if (!ok) return;

    setState(() => _saving = true);

    await LocalSecureStore.instance.setRawDataShareConsentFor(_email!, _shareRaw);

    if (!mounted) return;

    setState(() {
      _saving = false;
      _initialConsent = _shareRaw; // update baseline after save
    });

    if (widget.editMode) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } else {
      context.go('/authorize');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final primaryLabel = widget.editMode ? "Save" : "Continue";

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editMode ? "Raw Data Consent (Edit)" : "Data Sharing Consent"),
      ),
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
                      const Icon(Icons.privacy_tip_outlined, size: 44),
                      const SizedBox(height: 12),
                      Text(
                        "Allow sharing RAW wearable data with the backend?",
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "If you choose NO, computations stay on-device and only privacy-preserved results "
                        "(derived/aggregated metrics) will be sent to the backend dashboard.",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        value: _shareRaw,
                        onChanged: (v) => setState(() => _shareRaw = v),
                        title: const Text("Share RAW data with backend"),
                        subtitle: Text(_shareRaw ? "YES — raw data allowed" : "NO — on-device computation"),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(primaryLabel),
                        ),
                      ),
                      if (widget.editMode) ...[
                        const SizedBox(height: 8),
                        Text(
                          "Note: Apple Health permissions are managed by iOS. This setting only controls "
                          "whether raw samples may ever be shared (future backend work).",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                        ),
                      ],
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
