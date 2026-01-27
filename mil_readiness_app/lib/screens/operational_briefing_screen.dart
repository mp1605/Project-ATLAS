import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../routes.dart';

class OperationalBriefingScreen extends StatefulWidget {
  final SessionController session;
  const OperationalBriefingScreen({super.key, required this.session});

  @override
  State<OperationalBriefingScreen> createState() => _OperationalBriefingScreenState();
}

class _OperationalBriefingScreenState extends State<OperationalBriefingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<BriefingStep> _steps = [
    BriefingStep(
      title: 'THE READINESS ENGINE',
      description: 'The AUIX Engine synthesizes 18 biometric vectors to calculate your operational capacity. Focus is on baseline stability and recovery efficiency.',
      icon: Icons.analytics_outlined,
      color: AppTheme.primaryCyan,
    ),
    BriefingStep(
      title: 'SECURE CONNECTIVITY',
      description: 'Your health data is synchronized locally and encrypted with AES-256. Secure sync to command servers is optional and soldier-controlled.',
      icon: Icons.sync_lock_outlined,
      color: AppTheme.accentGreen,
    ),
    BriefingStep(
      title: 'OPERATIONAL PRIVACY',
      description: 'Personal data never leaves the device in raw form. Only high-level readiness categories are visible in the command dashboard.',
      icon: Icons.privacy_tip_outlined,
      color: AppTheme.primaryBlue,
    ),
  ];

  Future<void> _completeBriefing() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('briefing_completed', true);
    widget.session.setBriefingCompleted(true);
    if (mounted) context.go('/readiness');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (v) => setState(() => _currentPage = v),
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(step.icon, size: 100, color: step.color),
                        const SizedBox(height: 48),
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: AppTheme.titleStyle.copyWith(fontSize: 24, letterSpacing: 4),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          step.description,
                          textAlign: TextAlign.center,
                          style: AppTheme.bodyStyle.copyWith(height: 1.6, color: AppTheme.textGray),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Progress dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 4,
                  width: _currentPage == index ? 24 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? AppTheme.primaryCyan : AppTheme.glassBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
            
            const SizedBox(height: 48),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _steps.length - 1) {
                      _controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
                    } else {
                      _completeBriefing();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _currentPage == _steps.length - 1 ? 'BEGIN OPERATION' : 'NEXT',
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class BriefingStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  BriefingStep({required this.title, required this.description, required this.icon, required this.color});
}
