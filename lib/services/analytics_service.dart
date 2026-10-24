import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Analytics event names. Names and parameters follow the Firebase rules:
/// at most 40 characters, letters, digits and underscores, starting with a
/// letter. Standard (recommended) Firebase events are marked as such.
class AnalyticsEvent {
  // Screens
  static const String screenView = 'screen_view'; // standard
  static const String mainMenuView = 'main_menu_view';
  static const String levelSelectionView = 'level_selection_view';
  static const String settingsOpen = 'settings_open';

  // Play sessions (time on the gameplay screen, possibly several levels)
  static const String gameSessionStart = 'game_session_start';
  static const String gameSessionEnd = 'game_session_end';

  // Level progression
  static const String levelStart = 'level_start'; // standard
  static const String levelComplete = 'level_complete';
  static const String levelFail = 'level_fail';
  static const String levelRestart = 'level_restart';
  static const String levelQuit = 'level_quit';
  static const String nextLevel = 'next_level';

  // Gameplay
  static const String hintUsed = 'hint_used';
  static const String undoUsed = 'undo_used';
  static const String pauseGame = 'pause_game';
  static const String resumeGame = 'resume_game';
  static const String tutorialBegin = 'tutorial_begin'; // standard
  static const String tutorialComplete = 'tutorial_complete'; // standard

  // Economy
  static const String themeUnlocked = 'theme_unlocked';
}

/// Parameter names shared by several events.
class AnalyticsParam {
  static const String screenName = 'screen_name';
  static const String screenClass = 'screen_class';
  static const String levelName = 'level_name'; // standard for level_start
  static const String levelNumber = 'level_number';
  static const String gameMode = 'game_mode';
  static const String difficulty = 'difficulty';
  static const String attemptNumber = 'attempt_number';
  static const String resumed = 'resumed';
  static const String moveCount = 'move_count';
  static const String mistakeCount = 'mistake_count';
  static const String hintCount = 'hint_count';
  static const String continueCount = 'continue_count';
  static const String stars = 'stars';
  static const String timeSeconds = 'completion_time_seconds';
  static const String arrowsCleared = 'arrows_cleared';
  static const String arrowsTotal = 'arrows_total';
  static const String reason = 'reason';
  static const String source = 'source';
  static const String fromLevel = 'from_level';
  static const String levelsStarted = 'levels_started';
  static const String levelsCompleted = 'levels_completed';
  static const String durationSeconds = 'duration_seconds';
  static const String dailyDate = 'daily_date';
}

/// `game_mode` values.
class GameMode {
  static const String campaign = 'campaign';
  static const String daily = 'daily';
}

abstract class IAnalyticsService {
  /// Fire-and-forget. Implementations must never throw or block the caller.
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

/// Used when Firebase is unavailable outside debug builds.
class NoOpAnalyticsService extends GetxService implements IAnalyticsService {
  @override
  void logEvent(String name, {Map<String, dynamic>? params}) {}
}

/// Sends events to Firebase Analytics. Events are queued on the device by
/// the Firebase SDK and uploaded when a connection is available, so this
/// works offline. Failures are swallowed: analytics never affects gameplay.
class FirebaseAnalyticsService extends GetxService
    implements IAnalyticsService {
  final FirebaseAnalytics _analytics;

  FirebaseAnalyticsService(this._analytics);

  @override
  void logEvent(String name, {Map<String, dynamic>? params}) {
    try {
      final parameters = _sanitize(params);
      final Future<void> call = name == AnalyticsEvent.screenView
          ? _analytics.logScreenView(
              screenName: parameters?[AnalyticsParam.screenName] as String?,
              screenClass: parameters?[AnalyticsParam.screenClass] as String?,
            )
          : _analytics.logEvent(name: name, parameters: parameters);
      call.catchError((Object e) => _report(name, e));
      if (kDebugMode) {
        // ignore: avoid_print
        print('[Analytics] $name ${parameters ?? ''}');
      }
    } catch (e) {
      _report(name, e);
    }
  }

  /// Firebase accepts only String and num values: bools become 0/1, nulls
  /// are dropped and strings are capped at the 100-character limit.
  static Map<String, Object>? _sanitize(Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) return null;
    final out = <String, Object>{};
    params.forEach((key, value) {
      if (value is bool) {
        out[key] = value ? 1 : 0;
      } else if (value is num) {
        out[key] = value;
      } else if (value != null) {
        final s = value.toString();
        out[key] = s.length > 100 ? s.substring(0, 100) : s;
      }
    });
    return out.isEmpty ? null : out;
  }

  static void _report(String name, Object e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[Analytics] failed to log $name: $e');
    }
  }
}

/// Typed game events. Defined as an extension so every [IAnalyticsService]
/// (Firebase, debug, test fakes) gets them without extra implementation.
extension GameAnalytics on IAnalyticsService {
  void screenView(String screenName) => logEvent(
    AnalyticsEvent.screenView,
    params: {
      AnalyticsParam.screenName: screenName,
      AnalyticsParam.screenClass: screenName,
    },
  );

  void gameSessionStart() => logEvent(AnalyticsEvent.gameSessionStart);

  void gameSessionEnd({
    required int durationSeconds,
    required int levelsStarted,
    required int levelsCompleted,
  }) => logEvent(
    AnalyticsEvent.gameSessionEnd,
    params: {
      AnalyticsParam.durationSeconds: durationSeconds,
      AnalyticsParam.levelsStarted: levelsStarted,
      AnalyticsParam.levelsCompleted: levelsCompleted,
    },
  );

  void levelStart(LevelAnalytics level, {required bool resumed}) => logEvent(
    AnalyticsEvent.levelStart,
    params: {
      AnalyticsParam.levelName: level.levelName,
      ...level.base,
      AnalyticsParam.resumed: resumed,
    },
  );

  void levelComplete(
    LevelAnalytics level,
    LevelStats stats, {
    required int stars,
  }) => logEvent(
    AnalyticsEvent.levelComplete,
    params: {...level.base, ...stats.toParams(), AnalyticsParam.stars: stars},
  );

  void levelFail(LevelAnalytics level, LevelStats stats) => logEvent(
    AnalyticsEvent.levelFail,
    params: {...level.base, ...stats.toParams()},
  );

  void levelQuit(LevelAnalytics level, LevelStats stats) => logEvent(
    AnalyticsEvent.levelQuit,
    params: {...level.base, ...stats.toParams()},
  );

  /// [reason]: 'restart' (pause menu), 'retry' (after failing) or 'replay'
  /// (after completing).
  void levelRestart(LevelAnalytics level, {required String reason}) =>
      logEvent(
        AnalyticsEvent.levelRestart,
        params: {...level.base, AnalyticsParam.reason: reason},
      );

  void nextLevel({required int fromLevel}) => logEvent(
    AnalyticsEvent.nextLevel,
    params: {
      AnalyticsParam.fromLevel: fromLevel,
      AnalyticsParam.levelNumber: fromLevel + 1,
    },
  );

  void hintUsed(LevelAnalytics level) =>
      logEvent(AnalyticsEvent.hintUsed, params: level.base);

  void undoUsed(LevelAnalytics level) =>
      logEvent(AnalyticsEvent.undoUsed, params: level.base);

  void pauseGame(LevelAnalytics level) =>
      logEvent(AnalyticsEvent.pauseGame, params: level.base);

  void resumeGame(LevelAnalytics level) =>
      logEvent(AnalyticsEvent.resumeGame, params: level.base);

  /// [source]: 'first_level' (automatic on level 1) or 'pause_menu'.
  void tutorialBegin({required String source}) => logEvent(
    AnalyticsEvent.tutorialBegin,
    params: {AnalyticsParam.source: source},
  );

  void tutorialComplete({required String source}) => logEvent(
    AnalyticsEvent.tutorialComplete,
    params: {AnalyticsParam.source: source},
  );
}

/// Identifies the level an event is about.
class LevelAnalytics {
  final int levelNumber;
  final String gameMode;
  final String difficulty;
  final int attemptNumber;
  final String? dailyDate;

  const LevelAnalytics({
    required this.levelNumber,
    required this.gameMode,
    required this.difficulty,
    required this.attemptNumber,
    this.dailyDate,
  });

  String get levelName =>
      gameMode == GameMode.daily ? 'daily_$dailyDate' : 'level_$levelNumber';

  Map<String, dynamic> get base => {
    AnalyticsParam.levelNumber: levelNumber,
    AnalyticsParam.gameMode: gameMode,
    AnalyticsParam.difficulty: difficulty,
    AnalyticsParam.attemptNumber: attemptNumber,
    if (dailyDate != null) AnalyticsParam.dailyDate: dailyDate,
  };
}

/// How an attempt went, sent with level_complete / level_fail / level_quit.
class LevelStats {
  final int moves;
  final int mistakes;
  final int hints;
  final int continues;
  final int arrowsCleared;
  final int arrowsTotal;
  final int seconds;

  const LevelStats({
    required this.moves,
    required this.mistakes,
    required this.hints,
    required this.continues,
    required this.arrowsCleared,
    required this.arrowsTotal,
    required this.seconds,
  });

  Map<String, dynamic> toParams() => {
    AnalyticsParam.moveCount: moves,
    AnalyticsParam.mistakeCount: mistakes,
    AnalyticsParam.hintCount: hints,
    AnalyticsParam.continueCount: continues,
    AnalyticsParam.arrowsCleared: arrowsCleared,
    AnalyticsParam.arrowsTotal: arrowsTotal,
    AnalyticsParam.timeSeconds: seconds,
  };
}

/// Logs a screen_view for every page route, plus the named menu events.
/// Dialogs and bottom sheets are not page routes, so closing one does not
/// re-log the screen underneath. Looks the service up lazily because the
/// app's routes exist before the splash screen registers services.
class AnalyticsRouteObserver extends NavigatorObserver {
  static const Map<String, String> _screenEvents = {
    '/home': AnalyticsEvent.mainMenuView,
    '/level-select': AnalyticsEvent.levelSelectionView,
    '/settings': AnalyticsEvent.settingsOpen,
  };

  void _log(Route<dynamic>? route) {
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (name == null || !Get.isRegistered<IAnalyticsService>()) return;
    final analytics = Get.find<IAnalyticsService>();
    analytics.screenView(name == '/' ? 'splash' : name.substring(1));
    final event = _screenEvents[name];
    if (event != null) analytics.logEvent(event);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _log(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _log(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _log(previousRoute);
  }
}
