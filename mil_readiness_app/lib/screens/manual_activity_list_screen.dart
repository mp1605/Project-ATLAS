import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/manual_activity_entry.dart';
import '../repositories/manual_activity_repository.dart';
import '../services/local_secure_store.dart';
import '../theme/app_theme.dart';

class ManualActivityListScreen extends StatefulWidget {
  const ManualActivityListScreen({super.key});

  @override
  State<ManualActivityListScreen> createState() => _ManualActivityListScreenState();
}

class _ManualActivityListScreenState extends State<ManualActivityListScreen> {
  final ManualActivityRepository _repository = ManualActivityRepository();
  List<ManualActivityEntry> _entries = [];
  bool _isLoading = true;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _userEmail = await LocalSecureStore.instance.getActiveSessionEmail();
      if (_userEmail != null) {
        final entries = await _repository.listRecent(userEmail: _userEmail!);
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading activities: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDarker,
      appBar: AppBar(
        title: const Text('Manual Activity Log', 
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.bgDarker,
              AppTheme.bgDark,
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _entries.isEmpty
                ? _buildEmptyState()
                : _buildList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/log-activity/add').then((_) => _loadData()),
        label: const Text('Log Activity'),
        icon: const Icon(Icons.add),
        backgroundColor: AppTheme.primaryCyan,
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: 80, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'No activities logged yet',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep your training load accurate by\nlogging manual sessions.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _buildActivityCard(entry);
      },
    );
  }

  Widget _buildActivityCard(ManualActivityEntry entry) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');
    final localTime = entry.startTimeUtc.toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            // Edit/View (Not implemented in this screen yet, but ready for expansion)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Detail view coming soon'), duration: Duration(seconds: 1)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _getActivityIcon(entry.activityType),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.activityType == ActivityType.other 
                                  ? entry.customName ?? 'Other' 
                                  : _formatEnum(entry.activityType.name),
                              style: const TextStyle(
                                  color: Colors.white, 
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${dateFormat.format(localTime)} at ${timeFormat.format(localTime)}',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.5), 
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _buildFeelBadge(entry.feelAfter),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetric('Duration', '${entry.durationMinutes}m'),
                    _buildMetric('Intensity', 'RPE ${entry.rpe}'),
                    _buildMetric('Load', '${entry.durationMinutes * entry.rpe}'),
                  ],
                ),
                if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  Text(
                    entry.notes!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
              color: AppTheme.primaryCyan, 
              fontSize: 16, 
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: TextStyle(
              color: Colors.white.withOpacity(0.3), 
              fontSize: 10, 
              letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildFeelBadge(String feel) {
    Color color;
    IconData icon;
    switch (feel.toLowerCase()) {
      case 'better':
        color = Colors.greenAccent;
        icon = Icons.trending_up;
        break;
      case 'worse':
        color = Colors.orangeAccent;
        icon = Icons.trending_down;
        break;
      default:
        color = Colors.blueAccent;
        icon = Icons.trending_flat;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            feel.toUpperCase(),
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _getActivityIcon(ActivityType type) {
    IconData iconData;
    switch (type) {
      case ActivityType.walking: iconData = Icons.directions_walk; break;
      case ActivityType.running: iconData = Icons.directions_run; break;
      case ActivityType.cycling: iconData = Icons.directions_bike; break;
      case ActivityType.swimming: iconData = Icons.pool; break;
      case ActivityType.strengthTraining: iconData = Icons.fitness_center; break;
      case ActivityType.hiitCircuit: iconData = Icons.timer; break;
      case ActivityType.hiking: iconData = Icons.terrain; break;
      case ActivityType.ruckMarch: iconData = Icons.backpack; break;
      case ActivityType.mobilityStretching: iconData = Icons.accessibility_new; break;
      case ActivityType.yogaBreathwork: iconData = Icons.self_improvement; break;
      case ActivityType.combatTraining: iconData = Icons.sports_mma; break;
      case ActivityType.manualLabor: iconData = Icons.engineering; break;
      case ActivityType.ptTest: iconData = Icons.assignment_turned_in; break;
      default: iconData = Icons.more_horiz; break;
    }
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.primaryCyan.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: AppTheme.primaryCyan, size: 24),
    );
  }

  String _formatEnum(String name) {
    final result = name.replaceAllMapped(
      RegExp(r'([A-Z])'), 
      (match) => ' ${match.group(0)}'
    );
    return result[0].toUpperCase() + result.substring(1).toLowerCase();
  }
}
