import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../routes.dart';
import '../theme/app_theme.dart';
import '../models/comprehensive_readiness_result.dart';
import '../repositories/comprehensive_score_repository.dart';
import '../services/local_secure_store.dart';
import '../widgets/readiness_heat_map.dart';

/// Trends screen - Shows historical readiness data with heat map
class TrendsScreen extends StatefulWidget {
  final SessionController session;
  
  const TrendsScreen({super.key, required this.session});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  bool _loading = true;
  List<ComprehensiveReadinessResult> _historicalData = [];
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadHistoricalData();
  }
  
  Future<void> _loadHistoricalData() async {
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
      
      // Fetch last 365 days using getTrend method
      final data = await ComprehensiveScoreRepository.getTrend(
        userEmail: email,
        days: 365,
      );
      
      setState(() {
        _historicalData = data;
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
        title: const Text('READINESS TRENDS'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadHistoricalData,
          ),
        ],
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
                'Error loading trends',
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
    
    if (_historicalData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timeline, size: 64, color: AppTheme.primaryCyan),
              const SizedBox(height: 24),
              const Text(
                'No Historical Data',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Keep using the app to build your readiness history. Your trends will appear here.',
                style: TextStyle(fontSize: 14, color: AppTheme.textLight),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          
          // Heat Map
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.glassBorder.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ReadinessHeatMap(
              results: _historicalData,
              onDayTapped: (date) {
                // Future: Show day detail
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tapped: ${DateFormat('MMM d, y').format(date)}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Stats Summary
          _buildStatsSummary(),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
  
  Widget _buildStatsSummary() {
    if (_historicalData.isEmpty) return const SizedBox.shrink();
    
    final scores = _historicalData.map((r) => r.overallReadiness).toList();
    final avgScore = scores.reduce((a, b) => a + b) / scores.length;
    final highScore = scores.reduce((a, b) => a > b ? a : b);
    final lowScore = scores.reduce((a, b) => a < b ? a : b);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Summary Statistics',
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
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryCyan,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textGray,
            ),
          ),
        ],
      ),
    );
  }
}
