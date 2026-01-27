import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Local-only goal tracking (no backend, simple SharedPreferences)
class LocalGoalCard extends StatefulWidget {
  final String userEmail;
  
  const LocalGoalCard({super.key, required this.userEmail});

  @override
  State<LocalGoalCard> createState() => _LocalGoalCardState();
}

class _LocalGoalCardState extends State<LocalGoalCard> {
  bool _hasGoal = false;
  String _goalType = '';
  int _progress = 0;
  int _target = 7;
  
  @override
  void initState() {
    super.initState();
    _loadGoal();
  }
  
  Future<void> _loadGoal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasGoal = prefs.getBool('${widget.userEmail}_has_goal') ?? false;
      _goalType = prefs.getString('${widget.userEmail}_goal_type') ?? '7-day-streak';
      _progress = prefs.getInt('${widget.userEmail}_goal_progress') ?? 0;
      _target = prefs.getInt('${widget.userEmail}_goal_target') ?? 7;
    });
  }
  
  Future<void> _setGoal(String type, int target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${widget.userEmail}_has_goal', true);
    await prefs.setString('${widget.userEmail}_goal_type', type);
    await prefs.setInt('${widget.userEmail}_goal_progress', 0);
    await prefs.setInt('${widget.userEmail}_goal_target', target);
    _loadGoal();
  }
  
  Future<void> _clearGoal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${widget.userEmail}_has_goal');
    await prefs.remove('${widget.userEmail}_goal_type');
    await prefs.remove('${widget.userEmail}_goal_progress');
    await prefs.remove('${widget.userEmail}_goal_target');
    _loadGoal();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_hasGoal) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.glassBorder.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.flag_outlined, color: AppTheme.accentOrange, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set a Readiness Goal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Track your progress toward consistent readiness',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _showGoalPicker(context),
              child: const Text('SET', style: TextStyle(color: AppTheme.primaryCyan)),
            ),
          ],
        ),
      );
    }
    
    // Active goal
    final goalName = _getGoalName(_goalType);
    final progressPercent = (_progress / _target * 100).clamp(0, 100).toInt();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryCyan.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, color: AppTheme.primaryCyan, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  goalName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textWhite,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppTheme.textGray),
                onPressed: _clearGoal,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$_progress / $_target days',
            style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress / _target,
              backgroundColor: AppTheme.textGray.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryCyan),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$progressPercent% complete',
            style: const TextStyle(fontSize: 11, color: AppTheme.primaryCyan),
          ),
        ],
      ),
    );
  }
  
  String _getGoalName(String type) {
    switch (type) {
      case '7-day-streak':
        return '7-Day Readiness Streak';
      case 'avg-80':
        return 'Maintain 80+ Average';
      default:
        return 'Readiness Goal';
    }
  }
  
  void _showGoalPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.bgDark
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Choose a Goal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.check_circle, color: AppTheme.primaryCyan),
                title: const Text('7-Day Readiness Streak', style: TextStyle(color: AppTheme.textWhite)),
                subtitle: const Text('Maintain high readiness for 7 days', style: TextStyle(color: AppTheme.textGray)),
                onTap: () {
                  Navigator.pop(context);
                  _setGoal('7-day-streak', 7);
                },
              ),
              ListTile(
                leading: const Icon(Icons.trending_up, color: AppTheme.accentOrange),
                title: const Text('Maintain 80+ Average', style: TextStyle(color: AppTheme.textWhite)),
                subtitle: const Text('Keep average readiness above 80', style: TextStyle(color: AppTheme.textGray)),
                onTap: () {
                  Navigator.pop(context);
                  _setGoal('avg-80', 7);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
