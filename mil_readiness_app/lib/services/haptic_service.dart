import 'package:flutter/services.dart';

/// Haptic feedback service for professional tactile responses
/// Provides subtle, appropriate feedback for different interaction types
class HapticService {
  HapticService._();
  
  static final HapticService instance = HapticService._();
  
  /// Light impact for selections, toggles, taps
  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }
  
  /// Medium impact for confirmations, submissions
  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }
  
  /// Heavy impact for important actions, errors
  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }
  
  /// Selection change (for pickers, segmented controls)
  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }
  
  /// Soft vibrate for successful operations (sync complete, data saved)
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
  }
  
  /// Warning vibration for attention-needed states
  static Future<void> warning() async {
    await HapticFeedback.heavyImpact();
  }
  
  /// Error vibration pattern (heavy)
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
  }
}
