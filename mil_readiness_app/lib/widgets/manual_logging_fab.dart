import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'logging_dialogs.dart';

class ManualLoggingFAB extends StatefulWidget {
  final String userEmail;
  const ManualLoggingFAB({super.key, required this.userEmail});

  @override
  State<ManualLoggingFAB> createState() => _ManualLoggingFABState();
}

class _ManualLoggingFABState extends State<ManualLoggingFAB> with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: _isOpen ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
        HapticFeedback.lightImpact();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen) ...[
          _buildItem(Icons.water_drop_outlined, 'Hydration', AppTheme.primaryCyan, () => LoggingDialogs.showHydrationDialog(context, widget.userEmail)),
          const SizedBox(height: 16),
          _buildItem(Icons.restaurant_outlined, 'Nutrition', AppTheme.accentGreen, () => LoggingDialogs.showNutritionDialog(context, widget.userEmail)),
          const SizedBox(height: 16),
          _buildItem(Icons.psychology_outlined, 'Stress', AppTheme.accentOrange, () => LoggingDialogs.showStressDialog(context, widget.userEmail)),
          const SizedBox(height: 16),
        ],
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: _isOpen ? AppTheme.bgDark : AppTheme.primaryCyan,
          elevation: 4,
          child: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _controller,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return FadeTransition(
      opacity: _expandAnimation,
      child: ScaleTransition(
        scale: _expandAnimation,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.bgDark.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            FloatingActionButton.small(
              onPressed: () {
                _toggle();
                onTap();
              },
              backgroundColor: color,
              child: Icon(icon, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
