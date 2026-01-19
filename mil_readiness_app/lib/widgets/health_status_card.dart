import 'package:flutter/material.dart';
import '../services/health_service.dart';
import '../services/local_secure_store.dart';

class HealthStatusCard extends StatefulWidget {
  final String email;
  const HealthStatusCard({super.key, required this.email});

  @override
  State<HealthStatusCard> createState() => _HealthStatusCardState();
}

class _HealthStatusCardState extends State<HealthStatusCard> {
  bool _loading = true;
  bool _busy = false;

  bool _authorized = false; // OS truth
  DateTime? _checkedAt;

  @override
  void initState() {
    super.initState();
    _refreshFromOs();
  }

  Future<void> _refreshFromOs() async {
    setState(() => _loading = true);

    final service = HealthService();
    final now = DateTime.now();
    
    // iOS Privacy: hasPermissions() is unreliable - try reading data instead
    bool hasAccess = false;
    try {
      // Attempt to read recent data - this is the ONLY reliable way on iOS
      final data = await service.readRecent(window: const Duration(hours: 1));
      hasAccess = true;  // If we got here without error, we have access
      print('✅ HealthStatusCard: Data access verified (${data.length} points found)');
    } catch (e) {
      hasAccess = false;
      print('❌ HealthStatusCard: No data access - $e');
    }

    // Keep store in sync with actual access status
    await LocalSecureStore.instance.setHealthAuthorizedFor(widget.email, hasAccess);
    await LocalSecureStore.instance.setHealthAuthCheckedAtFor(widget.email, now);

    if (!mounted) return;
    setState(() {
      _authorized = hasAccess;
      _checkedAt = now;
      _loading = false;
    });
  }

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final service = HealthService();

      // Check if we already have permissions before showing prompt
      final hasPerms = await service.hasPermissions();
      
      if (!hasPerms) {
        // Only show permission sheet if not already granted
        print('🔐 HealthStatusCard: Requesting first-time authorization...');
        await service.requestAuthorization();
      } else {
        print('✅ HealthStatusCard: Permissions already granted, skipping prompt');
      }

      // Re-check actual data access (the reliable way on iOS)
      await _refreshFromOs();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Checking Apple Health status…'),
            ],
          ),
        ),
      );
    }

    final statusText = _authorized ? 'Connected' : 'Not connected';
    final checkedText = _checkedAt == null ? 'Last checked: never' : 'Last checked: ${_checkedAt!.toLocal()}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apple Health', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Status: $statusText'),
            const SizedBox(height: 4),
            Text(checkedText, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _retry,
              child: Text(_busy ? 'Connecting…' : 'Connect / Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
