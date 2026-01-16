import 'package:flutter/material.dart';

/// Reusable card widget for displaying individual readiness scores
class ScoreCard extends StatelessWidget {
  final String scoreName;
  final double scoreValue; // 0-100
  final String category; // 'GO', 'CAUTION', 'LIMITED', 'STOP'
  final String confidence; // 'high', 'medium', 'low'
  final IconData icon;
  final VoidCallback? onTap;
  final bool compact; // If true, use smaller layout
  
  const ScoreCard({
    super.key,
    required this.scoreName,
    required this.scoreValue,
    required this.category,
    required this.confidence,
    required this.icon,
    this.onTap,
    this.compact = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor(scoreValue);
    final categoryIcon = _getCategoryIcon(category);
    final confidenceBadge = _getConfidenceBadge(confidence);
    
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: compact 
            ? const EdgeInsets.all(12) 
            : const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon + Name
              Row(
                children: [
                  Icon(icon, size: compact ? 20 : 24, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      scoreName,
                      style: TextStyle(
                        fontSize: compact ? 12 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Score Value
              Center(
                child: Text(
                  scoreValue.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: compact ? 28 : 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              
              // Progress Bar
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: scoreValue / 100,
                  backgroundColor: Colors.grey[300],
                  color: color,
                  minHeight: compact ? 6 : 8,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Footer: Category + Confidence
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Category Badge
                  Row(
                    children: [
                      Icon(categoryIcon, size: compact ? 14 : 16, color: color),
                      const SizedBox(width: 4),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: compact ? 10 : 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  
                  // Confidence Badge
                  _buildConfidenceBadge(confidence, compact),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Get color based on score value
  Color _getCategoryColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.yellow[700]!;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }
  
  /// Get icon based on category
  IconData _getCategoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'GO':
        return Icons.check_circle;
      case 'CAUTION':
        return Icons.warning;
      case 'LIMITED':
        return Icons.error;
      case 'STOP':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }
  
  /// Get confidence badge text
  String _getConfidenceBadge(String confidence) {
    switch (confidence.toLowerCase()) {
      case 'high':
        return '🟢';
      case 'medium':
        return '🟡';
      case 'low':
        return '🔴';
      default:
        return '⚪';
    }
  }
  
  /// Build confidence badge widget
  Widget _buildConfidenceBadge(String confidence, bool compact) {
    final badge = _getConfidenceBadge(confidence);
    final text = confidence.toUpperCase();
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(badge, style: TextStyle(fontSize: compact ? 10 : 12)),
          const SizedBox(width: 4),
          Text(
            text[0], // Just first letter (H/M/L)
            style: TextStyle(
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Determine category from score
String getCategoryFromScore(double score) {
  if (score >= 80) return 'GO';
  if (score >= 60) return 'CAUTION';
  if (score >= 40) return 'LIMITED';
  return 'STOP';
}
