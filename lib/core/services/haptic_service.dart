import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Haptic enabled state provider
///
/// Used for settings toggle and to control haptic feedback globally
final hapticEnabledProvider = StateProvider<bool>((ref) => true);

/// Haptic feedback service
///
/// Provides tactile confirmation for user interactions.
/// Can be disabled via settings for accessibility or battery concerns.
///
/// Intensity levels:
/// - Light: Button taps, navigation, minor actions
/// - Medium: Successful actions (clock-in, save, complete)
/// - Heavy: Errors, warnings, critical feedback
/// - Selection: Tab/item selection, checkboxes
class HapticService {
  HapticService(this.ref);

  final Ref ref;

  /// Check if haptics are enabled
  bool get isEnabled => ref.read(hapticEnabledProvider);

  /// Enable or disable haptic feedback
  void setEnabled(bool enabled) {
    ref.read(hapticEnabledProvider.notifier).state = enabled;
  }

  /// Light haptic feedback
  ///
  /// Use for:
  /// - Button taps
  /// - Navigation
  /// - Form field focus
  /// - Minor UI interactions
  Future<void> light() async {
    if (isEnabled) {
      await HapticFeedback.lightImpact();
    }
  }

  /// Medium haptic feedback
  ///
  /// Use for:
  /// - Clock in/out
  /// - Invoice marked paid
  /// - Estimate sent
  /// - Save actions
  /// - Successful completions
  Future<void> medium() async {
    if (isEnabled) {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Heavy haptic feedback
  ///
  /// Use for:
  /// - Errors
  /// - Warnings
  /// - Critical alerts
  /// - Failed operations
  Future<void> heavy() async {
    if (isEnabled) {
      await HapticFeedback.heavyImpact();
    }
  }

  /// Selection haptic feedback
  ///
  /// Use for:
  /// - Tab bar selection
  /// - Checkbox/radio toggle
  /// - Item selection in list
  /// - Picker/slider interaction
  Future<void> selection() async {
    if (isEnabled) {
      await HapticFeedback.selectionClick();
    }
  }

  /// Vibrate (Android-like pattern)
  ///
  /// Use for:
  /// - Notifications
  /// - Alarms
  /// - Long-running task completion
  Future<void> vibrate() async {
    if (isEnabled) {
      await HapticFeedback.vibrate();
    }
  }
}

/// Haptic service provider
///
/// Provides a HapticService instance that automatically syncs with
/// the hapticEnabledProvider state
final hapticServiceProvider = Provider<HapticService>((ref) {
  return HapticService(ref);
});
