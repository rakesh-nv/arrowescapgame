import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Handles haptic feedback throughout the game: single short impacts only,
/// never patterns. Respects the in-game hapticsOn setting; Android's own
/// touch-feedback setting also applies, since Flutter's HapticFeedback goes
/// through the system. Devices without a vibrator simply do nothing.
class HapticService extends GetxService {
  bool _enabled = true;

  void setEnabled(bool enabled) => _enabled = enabled;

  /// Light tap — an arrow left the board; ad rewards
  Future<void> lightTap() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Medium tap — crash / invalid move
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

  /// Selection click — the tap that sends an arrow on its way
  Future<void> selectionClick() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
