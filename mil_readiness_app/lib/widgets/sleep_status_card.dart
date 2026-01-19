import 'package:flutter/material.dart';
import '../services/sleep_source_resolver.dart';
import '../repositories/manual_sleep_repository.dart';
import '../models/manual_sleep_entry.dart';
import '../screens/manual_sleep_entry_sheet.dart';

/// Sleep status card for home screen
/// 
/// Shows:
/// - Auto sleep with "Confirm" / "Edit" buttons
/// - Missing sleep with "Log sleep" prompt
/// - Manual sleep with "Edit" option
class SleepStatusCard extends StatefulWidget {
  final String userEmail;
  final String date; // WAKE-UP DAY (YYYY-MM-DD)

  const SleepStatusCard({
    super.key,
    required this.userEmail,
    required this.date,
  });

  @override
  State<SleepStatusCard> createState() => _SleepStatusCardState();
}

class _SleepStatusCardState extends State<SleepStatusCard> {
  ResolvedSleep? _resolvedSleep;
  bool _loading = true;

  bool _shouldShowPrompt = false;

  @override
  void initState() {
    super.initState();
    _loadSleep();
  }

  Future<void> _loadSleep() async {
    setState(() => _loading = true);
    
    final resolved = await SleepSourceResolver.getSleepForDate(widget.userEmail, widget.date);
    
    // Check if we should prompt for confirmation
    final shouldShow = await ManualSleepRepository.instance.shouldShowConfirmPrompt(
      widget.userEmail,
      isLowConfidence: resolved.isLowConfidence,
    );

    setState(() {
      _resolvedSleep = resolved;
      _shouldShowPrompt = shouldShow;
      _loading = false;
    });
  }

  Future<void> _handleConfirm() async {
    if (_resolvedSleep?.autoSleepData == null) return;

    // Create/update manual entry matching auto sleep
    final auto = _resolvedSleep!.autoSleepData!;
    final entry = ManualSleepEntry.create(
      userEmail: widget.userEmail,
      date: widget.date,
      totalSleepMinutes: auto.totalMinutes,
      sleepStart: auto.bedtime,
      sleepEnd: auto.wakeTime,
      isUserOverride: false, // Just confirming, not overriding
    );

    await ManualSleepRepository.instance.upsertManualSleep(entry);
    await ManualSleepRepository.instance.recordConfirmPromptShown(widget.userEmail);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Sleep confirmed'),
          duration: Duration(seconds: 2),
        ),
      );
      await _loadSleep();
    }
  }

  Future<void> _handleEdit() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManualSleepEntrySheet(
        userEmail: widget.userEmail,
        date: widget.date,
        initialMinutes: _resolvedSleep?.minutes,
        initialSleepStart: _resolvedSleep?.sleepStart,
        initialSleepEnd: _resolvedSleep?.sleepEnd,
      ),
    );

    if (result == true && mounted) {
      await _loadSleep();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _buildLoadingCard();
    }

    if (_resolvedSleep == null || _resolvedSleep!.isMissing) {
      return _buildMissingCard();
    }

    if (_resolvedSleep!.source == 'auto') {
      return _buildAutoCard();
    }

    return _buildManualCard();
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[900]!.withOpacity(0.5),
            Colors.grey[850]!.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: const Row(
        children: [
          Icon(Icons.bedtime, color: Colors.white54, size: 24),
          SizedBox(width: 16),
          Text(
            'Loading sleep...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange[900]!.withOpacity(0.3),
            Colors.orange[800]!.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bedtime, color: Colors.orange[300], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sleep Missing',
                      style: TextStyle(
                        color: Colors.orange[200],
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Help us compute readiness',
                      style: TextStyle(
                        color: Colors.orange[100],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleEdit,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Log sleep (15 sec)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoCard() {
    final sleep = _resolvedSleep!;
    final shouldShowPrompt = Future.value().then((_) => 
      ManualSleepRepository.instance.shouldShowConfirmPrompt(
        widget.userEmail,
        isLowConfidence: sleep.isLowConfidence,
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue[900]!.withOpacity(0.3),
            Colors.blue[800]!.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.nightlight_round, color: Colors.blue[300], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Sleep (Auto)',
                          style: TextStyle(
                            color: Colors.blue[100],
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'Detected',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(sleep.minutes / 60).floor()}h ${sleep.minutes % 60}m',
                      style: TextStyle(
                        color: Colors.blue[200],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Confidence indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getConfidenceColor(sleep.confidence).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getConfidenceIcon(sleep.confidence),
                  color: _getConfidenceColor(sleep.confidence),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_shouldShowPrompt)
            // Just show Edit button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _handleEdit,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[200],
                ),
              ),
            )
          else
            // Show Confirm + Edit buttons
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _handleConfirm,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Confirm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleEdit,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[200],
                      side: BorderSide(color: Colors.blue[700]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildManualCard() {
    final sleep = _resolvedSleep!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple[900]!.withOpacity(0.3),
            Colors.purple[800]!.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, color: Colors.purple[300], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          sleep.isOverride ? 'Sleep (Manual Override)' : 'Sleep (Manual)',
                          style: TextStyle(
                            color: Colors.purple[100],
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(sleep.minutes / 60).floor()}h ${sleep.minutes % 60}m',
                      style: TextStyle(
                        color: Colors.purple[200],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _handleEdit,
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.purple[200],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(String confidence) {
    switch (confidence) {
      case 'high':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getConfidenceIcon(String confidence) {
    switch (confidence) {
      case 'high':
        return Icons.check_circle;
      case 'medium':
        return Icons.warning_amber_rounded;
      case 'low':
        return Icons.error;
      default:
        return Icons.help;
    }
  }
}
