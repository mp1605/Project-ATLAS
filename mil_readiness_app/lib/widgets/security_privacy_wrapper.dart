import 'dart:ui';
import 'package:flutter/material.dart';

/// A wrapper that blurs the app content when it goes into the background
class SecurityPrivacyWrapper extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const SecurityPrivacyWrapper({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<SecurityPrivacyWrapper> createState() => _SecurityPrivacyWrapperState();
}

class _SecurityPrivacyWrapperState extends State<SecurityPrivacyWrapper> with WidgetsBindingObserver {
  bool _isBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;

    setState(() {
      // Blur when app is inactive or hidden (backgrounded)
      _isBackgrounded = state == AppLifecycleState.inactive || 
                        state == AppLifecycleState.hidden ||
                        state == AppLifecycleState.paused;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isBackgrounded)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        color: Colors.white,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'AUIX SECURE',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
