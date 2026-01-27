import 'package:flutter/material.dart';
import '../services/sleep_source_resolver.dart';
import '../repositories/manual_sleep_repository.dart';
import '../models/manual_sleep_entry.dart';
import '../screens/manual_sleep_entry_sheet.dart';
import '../theme/app_theme.dart';

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
      decoration: AppTheme.glassCard(),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppTheme.primaryCyan)),
          ),
          const SizedBox(width: 16),
          Text(
            'LOADING SLEEP DATA...',
            style: AppTheme.titleStyle.copyWith(color: AppTheme.textGray, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard(color: AppTheme.accentOrange.withOpacity(0.1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bedtime, color: AppTheme.accentOrange, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SLEEP MISSING',
                      style: AppTheme.titleStyle.copyWith(
                        color: AppTheme.accentOrange,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'LOG DATA TO SYNC READINESS',
                      style: TextStyle(
                        color: AppTheme.textGray,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleEdit,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('LOG SLEEP DATA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentOrange,
                foregroundColor: AppTheme.bgDarker,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: AppTheme.titleStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  fontSize: 14,
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
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.nightlight_round, color: AppTheme.primaryCyan, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'SLEEP (AUTO)',
                          style: AppTheme.titleStyle.copyWith(
                            color: AppTheme.textWhite,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'DETECTED',
                            style: TextStyle(
                              color: AppTheme.accentGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(sleep.minutes / 60).floor()}H ${sleep.minutes % 60}M TOTAL',
                      style: const TextStyle(
                        color: AppTheme.primaryCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Confidence indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getConfidenceColor(sleep.confidence).withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _getConfidenceColor(sleep.confidence).withOpacity(0.3)),
                ),
                child: Icon(
                  _getConfidenceIcon(sleep.confidence),
                  color: _getConfidenceColor(sleep.confidence),
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!_shouldShowPrompt)
            // Just show Edit button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _handleEdit,
                icon: const Icon(Icons.edit, size: 16, color: AppTheme.primaryCyan),
                label: const Text('EDIT'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryCyan,
                  textStyle: AppTheme.titleStyle.copyWith(fontSize: 12, letterSpacing: 1.0),
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
                    label: const Text('CONFIRM'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryCyan,
                      foregroundColor: AppTheme.bgDarker,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: AppTheme.titleStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleEdit,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('EDIT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textWhite,
                      side: const BorderSide(color: AppTheme.glassBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: AppTheme.titleStyle.copyWith(fontSize: 13),
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
    final isOverride = sleep.isOverride;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard(
        color: isOverride ? AppTheme.accentOrange.withOpacity(0.1) : AppTheme.primaryBlue.withOpacity(0.1),
      ).copyWith(
        border: Border.all(
          color: isOverride ? AppTheme.accentOrange.withOpacity(0.5) : AppTheme.primaryBlue.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isOverride ? AppTheme.accentOrange : AppTheme.primaryBlue).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isOverride ? Icons.emergency_share : Icons.edit_note,
                  color: isOverride ? AppTheme.accentOrange : AppTheme.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOverride ? 'MANUAL OVERRIDE' : 'MANUAL LOG',
                      style: AppTheme.titleStyle.copyWith(
                        color: AppTheme.textWhite,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(sleep.minutes / 60).floor()}H ${sleep.minutes % 60}M TOTAL',
                      style: TextStyle(
                        color: isOverride ? AppTheme.accentOrange : AppTheme.primaryBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _handleEdit,
              icon: Icon(
                Icons.edit,
                size: 16,
                color: isOverride ? AppTheme.accentOrange : AppTheme.primaryBlue,
              ),
              label: const Text('EDIT'),
              style: TextButton.styleFrom(
                foregroundColor: isOverride ? AppTheme.accentOrange : AppTheme.primaryBlue,
                textStyle: AppTheme.titleStyle.copyWith(fontSize: 12, letterSpacing: 1.0),
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
