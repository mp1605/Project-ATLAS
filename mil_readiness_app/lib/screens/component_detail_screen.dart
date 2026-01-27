import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/comprehensive_readiness_result.dart';
import '../repositories/comprehensive_score_repository.dart';
import '../services/local_secure_store.dart';
import 'package:fl_chart/fl_chart.dart';

/// Generic component detail screen showing 30-day trends and stats
/// Read-only view of existing data, no new calculations
class ComponentDetailScreen extends StatefulWidget {
  final String componentName;
  final String componentDescription;
  final IconData icon;
  final Color color;
  final double Function(ComprehensiveReadinessResult) scoreExtractor;
  
  const ComponentDetailScreen({
    super.key,
    required this.componentName,
    required this.componentDescription,
    required this.icon,
    required this.color,
    required this.scoreExtractor,
  });

  @override
  State<ComponentDetailScreen> createState() => _ComponentDetailScreenState();
}

class _ComponentDetailScreenState extends State<ComponentDetailScreen> {
  bool _loading = true;
  List<ComprehensiveReadinessResult> _data = [];
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    try {
      setState(() => _loading = true);
      
      final email = await LocalSecureStore.instance.getActiveSessionEmail();
      if (email == null) {
        setState(() {
          _error = 'No active session';
          _loading = false;
        });
        return;
      }
      
      // Fetch last 30 days
      final results = await ComprehensiveScoreRepository.getTrend(
        userEmail: email,
        days: 30,
      );
      
      setState(() {
        _data = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.componentName.toUpperCase()),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkGradient
              : AppTheme.lightGradient,
        ),
        child: _buildBody(),
      ),
    );
  }
  
  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryCyan),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading data',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.textGray),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    if (_data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 64, color: widget.color),
              const SizedBox(height: 24),
              const Text(
                'No Data Available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Keep using the app to build your history.',
                style: TextStyle(fontSize: 14, color: AppTheme.textLight),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    // Extract scores
    final scores = _data.map((r) => widget.scoreExtractor(r)).toList();
    final avgScore = scores.reduce((a, b) => a + b) / scores.length;
    final highScore = scores.reduce((a, b) => a > b ? a : b);
    final lowScore = scores.reduce((a, b) => a < b ? a : b);
    final latestScore = scores.last;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Score Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.glassBorder.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(widget.icon, size: 48, color: widget.color),
                const SizedBox(height: 16),
                Text(
                  latestScore.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: widget.color,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Current Score',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textGray,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 30-Day Trend Chart
          const Text(
            '30-Day Trend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppTheme.textWhite,
            ),
          ),
          const SizedBox(height: 12),
          
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.glassBorder.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppTheme.glassBorder.withOpacity(0.2),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: AppTheme.textGray,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: scores.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value);
                    }).toList(),
                    isCurved: true,
                    color: widget.color,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: widget.color.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Statistics
          const Text(
            'Statistics (30 Days)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppTheme.textWhite,
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(child: _buildStatCard('Average', avgScore.toStringAsFixed(1))),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Highest', highScore.toStringAsFixed(1))),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Lowest', lowScore.toStringAsFixed(1))),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Description
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.glassBorder.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About This Metric',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.componentDescription,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textLight,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.glassBorder.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: widget.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textGray,
            ),
          ),
        ],
      ),
    );
  }
}
