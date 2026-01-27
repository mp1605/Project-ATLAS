import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/comprehensive_readiness_result.dart';
import '../theme/app_theme.dart';

/// GitHub-style heat map showing 365 days of readiness scores
/// Color intensity represents readiness level
class ReadinessHeatMap extends StatelessWidget {
  final List<ComprehensiveReadinessResult> results;
  final Function(DateTime)? onDayTapped;
  
  const ReadinessHeatMap({
    super.key,
    required this.results,
    this.onDayTapped,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startDate = DateTime(now.year - 1, now.month, now.day);
    
    // Create map of date (timestamp) -> score for fast lookup
    final Map<int, double> scoreMap = {};
    for (var result in results) {
      // Results are stored with date as midnight timestamp
      scoreMap[result.calculatedAt.millisecondsSinceEpoch] = result.overallReadiness;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '365-Day Readiness History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textWhite,
            ),
          ),
          const SizedBox(height: 16),
          _buildHeatMapGrid(scoreMap, startDate, now),
          const SizedBox(height: 16),
          _buildLegend(),
        ],
      ),
    );
  }
  
  Widget _buildHeatMapGrid(Map<int, double> scoreMap, DateTime start, DateTime end) {
    // Calculate grid dimensions (52 weeks × 7 days)
    final daysList = <DateTime>[];
    for (int i = 0; i < 365; i++) {
      daysList.add(start.add(Duration(days: i)));
    }
    
    // Group by week
    final weeks = <List<DateTime>>[];
    for (int i = 0; i < daysList.length; i += 7) {
      weeks.add(daysList.sublist(i, (i + 7 > daysList.length) ? daysList.length : i + 7));
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day labels (M, W, F)
          Row(
            children: [
              const SizedBox(width: 32), // Offset for month labels
              ...List.generate(7, (index) {
                final labels = ['', 'M', '', 'W', '', 'F', ''];
                return SizedBox(
                  width: 16,
                  child: Text(
                    labels[index],
                    style: const TextStyle(fontSize: 10, color: AppTheme.textGray),
                    textAlign: TextAlign.center,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 4),
          
          // Heat map grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month labels (vertical)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _buildMonthLabels(start),
              ),
              const SizedBox(width: 8),
              
              // Grid of days
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(7, (dayOfWeek) {
                  return Row(
                    children: weeks.map((week) {
                      if (dayOfWeek >= week.length) {
                        return const SizedBox(width: 16, height: 16);
                      }
                      final day = week[dayOfWeek];
                      final dateKey = DateFormat('yyyy-MM-dd').format(day);
                      final score = scoreMap[dateKey];
                      
                      return GestureDetector(
                        onTap: () => onDayTapped?.call(day),
                        child: Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: _getColorForScore(score),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: AppTheme.glassBorder.withOpacity(0.2),
                              width: 0.5,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  List<Widget> _buildMonthLabels(DateTime start) {
    final labels = <Widget>[];
    String? currentMonth;
    
    for (int dayOfWeek = 0; dayOfWeek < 7; dayOfWeek++) {
      final date = start.add(Duration(days: dayOfWeek));
      final monthName = DateFormat('MMM').format(date);
      
      if (currentMonth != monthName && dayOfWeek == 0) {
        labels.add(
          SizedBox(
            height: 16,
            child: Text(
              monthName,
              style: const TextStyle(fontSize: 10, color: AppTheme.textGray),
            ),
          ),
        );
        currentMonth = monthName;
      } else {
        labels.add(const SizedBox(height: 16));
      }
    }
    
    return labels;
  }
  
  Color _getColorForScore(double? score) {
    if (score == null) {
      // No data
      return Colors.white.withOpacity(0.05);
    } else if (score >= 85) {
      // Excellent (dark green)
      return const Color(0xFF00D084);
    } else if (score >= 75) {
      // Good (green)
      return const Color(0xFF26D07C);
    } else if (score >= 60) {
      // Fair (light green/yellow)
      return const Color(0xFF9BE9A8);
    } else {
      // Low (red/orange)
      return const Color(0xFFFF6B6B);
    }
  }
  
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          'Less',
          style: TextStyle(fontSize: 11, color: AppTheme.textGray),
        ),
        const SizedBox(width: 8),
        _legendBox(Colors.white.withOpacity(0.05)),
        _legendBox(const Color(0xFF9BE9A8)),
        _legendBox(const Color(0xFF26D07C)),
        _legendBox(const Color(0xFF00D084)),
        const SizedBox(width: 8),
        const Text(
          'More',
          style: TextStyle(fontSize: 11, color: AppTheme.textGray),
        ),
      ],
    );
  }
  
  Widget _legendBox(Color color) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: AppTheme.glassBorder.withOpacity(0.2),
          width: 0.5,
        ),
      ),
    );
  }
}
