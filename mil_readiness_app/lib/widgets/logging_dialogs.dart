import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/manual_log.dart';
import '../repositories/manual_log_repository.dart';

class LoggingDialogs {
  static Future<void> showHydrationDialog(BuildContext context, String userEmail) async {
    double glasses = 8.0;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: AppTheme.glassCard(color: AppTheme.bgDark.withOpacity(0.95)),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.water_drop_outlined, color: AppTheme.primaryCyan, size: 40),
              const SizedBox(height: 16),
              Text('DAILY HYDRATION', style: AppTheme.titleStyle.copyWith(fontSize: 20)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppTheme.textGray), onPressed: () => setState(() => glasses = (glasses - 0.5).clamp(0, 20))),
                   const SizedBox(width: 24),
                   Column(children: [
                     Text(glasses.toStringAsFixed(1), style: AppTheme.headingStyle.copyWith(fontSize: 48, color: AppTheme.primaryCyan)),
                     Text('GLASSES (8oz)', style: AppTheme.captionStyle),
                   ]),
                   const SizedBox(width: 24),
                   IconButton(icon: const Icon(Icons.add_circle_outline, color: AppTheme.textGray), onPressed: () => setState(() => glasses = (glasses + 0.5).clamp(0, 20))),
                ],
              ),
              const SizedBox(height: 40),
              _buildSubmitButton(context, () async {
                await ManualLogRepository.store(ManualLog(
                  userEmail: userEmail,
                  logType: 'hydration',
                  value: glasses,
                  unit: 'glasses',
                  loggedAt: DateTime.now(),
                ));
              }),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> showNutritionDialog(BuildContext context, String userEmail) async {
    double quality = 3.0; // 1-5 scale
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: AppTheme.glassCard(color: AppTheme.bgDark.withOpacity(0.95)),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restaurant_outlined, color: AppTheme.accentGreen, size: 40),
              const SizedBox(height: 16),
              Text('NUTRITION QUALITY', style: AppTheme.titleStyle.copyWith(fontSize: 20)),
              const SizedBox(height: 32),
              Slider(
                value: quality,
                min: 1,
                max: 5,
                divisions: 4,
                activeColor: AppTheme.accentGreen,
                onChanged: (v) => setState(() => quality = v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('POOR', style: AppTheme.captionStyle),
                  Text('OPTIMAL', style: AppTheme.captionStyle),
                ],
              ),
              const SizedBox(height: 40),
              _buildSubmitButton(context, () async {
                await ManualLogRepository.store(ManualLog(
                  userEmail: userEmail,
                  logType: 'nutrition',
                  value: quality,
                  metadata: {'label': _getQualityLabel(quality)},
                  loggedAt: DateTime.now(),
                ));
              }),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> showStressDialog(BuildContext context, String userEmail) async {
    double stress = 2.0; // 1-5 scale
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: AppTheme.glassCard(color: AppTheme.bgDark.withOpacity(0.95)),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.psychology_outlined, color: AppTheme.accentOrange, size: 40),
              const SizedBox(height: 16),
              Text('PERCEIVED STRESS', style: AppTheme.titleStyle.copyWith(fontSize: 20)),
              const SizedBox(height: 32),
              Slider(
                value: stress,
                min: 1,
                max: 5,
                divisions: 4,
                activeColor: AppTheme.accentOrange,
                onChanged: (v) => setState(() => stress = v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text('LOW', style: AppTheme.captionStyle),
                   Text('CRITICAL', style: AppTheme.captionStyle),
                ],
              ),
              const SizedBox(height: 40),
              _buildSubmitButton(context, () async {
                await ManualLogRepository.store(ManualLog(
                  userEmail: userEmail,
                  logType: 'stress',
                  value: stress,
                  loggedAt: DateTime.now(),
                ));
              }),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildSubmitButton(BuildContext context, Future<void> Function() onAction) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryCyan,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: () async {
          await onAction();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Log Entry Recorded'), backgroundColor: AppTheme.accentGreen),
          );
        },
        child: const Text('SUBMIT ENTRY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      ),
    );
  }

  static String _getQualityLabel(double v) {
    if (v >= 4.5) return 'Optimal';
    if (v >= 3.5) return 'Good';
    if (v >= 2.5) return 'Fair';
    return 'Poor';
  }
}
