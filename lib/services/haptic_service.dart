import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Handles haptic feedback throughout the game.
/// Respects the hapticsOn setting via the settings controller.
class HapticService extends GetxService {
  bool _enabled = true;

  void setEnabled(bool enabled) => _enabled = enabled;

  /// Light tap — valid arrow selection
  Future<void> lightTap() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Medium tap — blocked arrow
  Future<void> mediumTap() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Heavy tap — level complete
  Future<void> heavyTap() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Selection click — button press
  Future<void> selectionClick() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
