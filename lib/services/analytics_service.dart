import 'package:get/get.dart';

/// Analytics event names
class AnalyticsEvent {
  static const String gameOpened = 'game_opened';
  static const String levelStarted = 'level_started';
  static const String levelCompleted = 'level_completed';
  static const String levelFailed = 'level_failed';
  static const String arrowTapped = 'arrow_tapped';
  static const String arrowBlocked = 'arrow_blocked';
  static const String hintUsed = 'hint_used';
  static const String undoUsed = 'undo_used';
  static const String dailyChallengeStarted = 'daily_challenge_started';
  static const String dailyChallengeCompleted = 'daily_challenge_completed';
  static const String themeUnlocked = 'theme_unlocked';
  static const String adWatched = 'ad_watched';
  static const String purchaseCompleted = 'purchase_completed';
}

abstract class IAnalyticsService {
  void logEvent(String name, {Map<String, dynamic>? params});
}

/// Debug implementation — logs events to console
class DebugAnalyticsService extends GetxService implements IAnalyticsService {
  @override
  void logEvent(String name, {Map<String, dynamic>? params}) {
    // ignore: avoid_print
    print('[Analytics] $name ${params ?? ''}');
  }
}
