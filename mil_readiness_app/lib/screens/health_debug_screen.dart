import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../adapters/health_adapter_factory.dart';
import '../models/wearable_type.dart';

/// PATCH 6: Health Debug Panel
/// Shows real-time Health permission status and data collection stats
class HealthDebugScreen extends StatefulWidget {
  const HealthDebugScreen({super.key});

  @override
  State<HealthDebugScreen> createState() => _HealthDebugScreenState();
}

class _HealthDebugScreenState extends State<HealthDebugScreen> {
  bool _isChecking = false;
  bool? _hasPermissions;
  String? _lastError;
  DateTime? _lastCheckTime;
  int _heartRateCount = 0;
  int _sleepCount = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isChecking = true;
      _lastError = null;
    });

    try {
      final adapter = HealthAdapterFactory.createAdapter(WearableType.appleWatch);
      
      // Check permissions
      final hasPerms = await adapter.hasPermissions();
      
      // Try to read some test data
      final metrics = await adapter.getMetrics(window: const Duration(hours: 24));
      
      final heartRateMetrics = metrics.where((m) => m.type == 'HEART_RATE').length;
      final sleepMetrics = metrics.where((m) => m.type.startsWith('SLEEP_')).length;
      
      setState(() {
        _hasPermissions = hasPerms;
        _heartRateCount = heartRateMetrics;
        _sleepCount = sleepMetrics;
        _lastCheckTime = DateTime.now();
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _lastError = e.toString();
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Health Debug'),
        backgroundColor: AppTheme.bgCard,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              'Device Status',
              [
                _buildInfoRow('Platform', 'iOS'),
                _buildInfoRow('Build', 'Debug'),
                _buildInfoRow(
                  'Permissions',
                  _hasPermissions == null
                      ? 'Not checked'
                      : _hasPermissions!
                          ? '✅ GRANTED'
                          : '❌ DENIED',
                  valueColor: _hasPermissions == true
                      ? Colors.green
                      : _hasPermissions == false
                          ? Colors.red
                          : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoCard(
              'Data Collection (Last 24h)',
              [
                _buildInfoRow('Heart Rate Samples', '$_heartRateCount'),
                _buildInfoRow('Sleep Metrics', '$_sleepCount'),
                _buildInfoRow(
                  'Last Check',
                  _lastCheckTime != null
                      ? _formatTime(_lastCheckTime!)
                      : 'Never',
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_lastError != null)
              _buildInfoCard(
                'Last Error',
                [
                  Text(
                    _lastError!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            _buildActionButton(
              'Refresh Status',
              Icons.refresh,
              _isChecking ? null : _checkPermissions,
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'Request Permissions',
              Icons.lock_open,
              () async {
                final adapter = HealthAdapterFactory.createAdapter(WearableType.appleWatch);
                final granted = await adapter.requestPermissions();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(granted
                          ? 'Permissions granted!'
                          : 'Permissions denied or partially granted'),
                      backgroundColor: granted ? Colors.green : Colors.orange,
                    ),
                  );
                  _checkPermissions();
                }
              },
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              'Instructions',
              [
                const Text(
                  '1. Grant permissions when prompted\n'
                  '2. Check Settings → Privacy → Health\n'
                  '3. Verify app appears in list\n'
                  '4. Ensure Apple Watch is synced\n'
                  '5. Wait 1-2 min for data sync',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.primaryBlue,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
