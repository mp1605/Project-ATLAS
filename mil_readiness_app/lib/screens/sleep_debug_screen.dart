import 'package:flutter/material.dart';
import '../database/secure_database_manager.dart';
import '../services/last_sleep_service.dart';
import '../routes.dart';

/// Debug screen to diagnose sleep data issues
class SleepDebugScreen extends StatefulWidget {
  final SessionController session;
  const SleepDebugScreen({super.key, required this.session});

  @override
  State<SleepDebugScreen> createState() => _SleepDebugScreenState();
}

class _SleepDebugScreenState extends State<SleepDebugScreen> {
  List<Map<String, dynamic>> _rawSleepData = [];
  Map<String, dynamic>? _lastSleepSummary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDebugData();
  }

  Future<void> _loadDebugData() async {
    final email = widget.session.email;
    if (email == null) return;

    try {
      final db = await SecureDatabaseManager.instance.database;
      
      // Get all sleep-related data from last 48 hours
      final yesterday = DateTime.now().subtract(const Duration(hours: 48));
      final rawData = await db.query(
        'health_metrics',
        where: 'user_email = ? AND metric_type LIKE ? AND timestamp >= ?',
        whereArgs: [email, 'SLEEP_%', yesterday.millisecondsSinceEpoch],
        orderBy: 'timestamp DESC',
      );

      // Get LastSleepService summary
      final lastSleep = await LastSleepService.getLastSleep(email);

      if (mounted) {
        setState(() {
          _rawSleepData = rawData;
          if (lastSleep != null) {
            _lastSleepSummary = {
              'bedtime': lastSleep.bedtime.toLocal().toString(),
              'wakeTime': lastSleep.wakeTime.toLocal().toString(),
              'totalMinutes': lastSleep.totalMinutes,
              'totalHours': (lastSleep.totalMinutes / 60.0).toStringAsFixed(2),
              'deepMinutes': lastSleep.deepMinutes,
              'remMinutes': lastSleep.remMinutes,
              'lightMinutes': lastSleep.lightMinutes,
              'awakeMinutes': lastSleep.awakeMinutes,
              'inBedMinutes': lastSleep.inBedMinutes,
              'efficiency': (lastSleep.sleepEfficiency * 100).toStringAsFixed(1),
              'confidence': lastSleep.confidence,
            };
          }
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading debug data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Data Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _loadDebugData();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Last Sleep Summary
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Last Sleep Summary (from LastSleepService)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          if (_lastSleepSummary != null) ...[
                            ..._lastSleepSummary!.entries.map((e) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 140,
                                        child: Text(
                                          '${e.key}:',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          e.value.toString(),
                                          style: const TextStyle(fontFamily: 'monospace'),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ] else
                            const Text('No sleep data found'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Raw Data Table
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Raw Sleep Data (${_rawSleepData.length} entries)',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          if (_rawSleepData.isEmpty)
                            const Text('No raw sleep data in database')
                          else
                            ...List.generate(
                              _rawSleepData.length > 20 ? 20 : _rawSleepData.length,
                              (i) {
                                final row = _rawSleepData[i];
                                final timestamp = DateTime.fromMillisecondsSinceEpoch(
                                  row['timestamp'] as int,
                                ).toLocal();
                                
                                String? dateFrom, dateTo;
                                if (row['date_from'] != null) {
                                  dateFrom = DateTime.parse(row['date_from'] as String)
                                      .toLocal()
                                      .toString()
                                      .substring(11, 19);
                                }
                                if (row['date_to'] != null) {
                                  dateTo = DateTime.parse(row['date_to'] as String)
                                      .toLocal()
                                      .toString()
                                      .substring(11, 19);
                                }

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  color: i % 2 == 0 ? Colors.grey[100] : Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                row['metric_type'] as String,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${row['value']} ${row['unit']}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Timestamp: ${timestamp.toString().substring(0, 19)}',
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                        if (dateFrom != null && dateTo != null)
                                          Text(
                                            'Window: $dateFrom → $dateTo',
                                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
