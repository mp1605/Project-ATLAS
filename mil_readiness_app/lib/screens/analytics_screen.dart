import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../services/local_secure_store.dart';
import '../repositories/comprehensive_score_repository.dart';
import '../models/comprehensive_readiness_result.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true;
  List<ComprehensiveReadinessResult> _history = [];
  Map<DateTime, int> _heatmapData = {};
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _email = await LocalSecureStore.instance.getActiveSessionEmail();
    if (_email != null) {
      final history = await ComprehensiveScoreRepository.getTrend(
        userEmail: _email!, 
        days: 90, 
        endDate: DateTime.now()
      );
      
      final Map<DateTime, int> heatmap = {};
      for (var result in history) {
        final date = DateTime(result.calculatedAt.year, result.calculatedAt.month, result.calculatedAt.day);
        heatmap[date] = result.overallReadiness.toInt();
      }

      setState(() {
        _history = history;
        _heatmapData = heatmap;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📊 ADVANCED ANALYTICS'), centerTitle: true),
      body: _loading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('HISTORICAL TIMELINE', Icons.calendar_view_month),
                  _buildHeatmap(),
                  const SizedBox(height: 32),
                  _buildSectionHeader('CORRELATION ANALYSIS', Icons.analytics_outlined),
                  _buildCorrelationChart(),
                  const SizedBox(height: 32),
                  _buildSectionHeader('PHYSIOLOGICAL OUTLIERS', Icons.bubble_chart_outlined),
                  _buildScatterPlot(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryCyan, size: 20),
          const SizedBox(width: 10),
          Text(title, style: AppTheme.titleStyle.copyWith(letterSpacing: 1.5, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildHeatmap() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(),
      child: HeatMap(
        datasets: _heatmapData,
        colorMode: ColorMode.opacity,
        showText: false,
        scrollable: true,
        colorsets: {
          1: AppTheme.accentRed.withOpacity(0.4),
          60: AppTheme.accentOrange.withOpacity(0.6),
          80: AppTheme.accentGreen.withOpacity(0.8),
        },
        onClick: (value) {
           // Drill down logic could go here
        },
      ),
    );
  }

  Widget _buildCorrelationChart() {
    return Container(
      height: 240,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard(),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20, getDrawingHorizontalLine: (v) => FlLine(color: AppTheme.glassBorder, strokeWidth: 1)),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: AppTheme.captionStyle))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.overallReadiness)).toList(),
              isCurved: true,
              color: AppTheme.primaryCyan,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: AppTheme.primaryCyan.withOpacity(0.1)),
            ),
            LineChartBarData(
              spots: _history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.recoveryScore)).toList(),
              isCurved: true,
              color: AppTheme.accentOrange,
              barWidth: 2,
              dotData: FlDotData(show: false),
              dashArray: [5, 5],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScatterPlot() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard(),
      child: ScatterChart(
        ScatterChartData(
          scatterSpots: _history.map((e) => ScatterSpot(e.recoveryScore, e.overallReadiness)).toList(),
          minX: 0, maxX: 100, minY: 0, maxY: 100,
          gridData: FlGridData(show: true, drawVerticalLine: true, horizontalInterval: 20, verticalInterval: 20, getDrawingHorizontalLine: (v) => FlLine(color: AppTheme.glassBorder), getDrawingVerticalLine: (v) => FlLine(color: AppTheme.glassBorder)),
          titlesData: FlTitlesData(show: true, rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Color _getScoreColor(double score) => score >= 80 ? AppTheme.accentGreen : (score >= 60 ? AppTheme.accentOrange : AppTheme.accentRed);
}
