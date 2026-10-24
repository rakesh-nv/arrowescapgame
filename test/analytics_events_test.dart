import 'package:arrowescapegame/core/constants/app_constants.dart';
import 'package:arrowescapegame/data/models/player_progress.dart';
import 'package:arrowescapegame/data/repositories/level_repository.dart';
import 'package:arrowescapegame/data/repositories/progress_repository.dart';
import 'package:arrowescapegame/game/solver/level_solver.dart';
import 'package:arrowescapegame/modules/ads/services/ad_service.dart';
import 'package:arrowescapegame/modules/gameplay/gameplay_controller.dart';
import 'package:arrowescapegame/services/analytics_service.dart';
import 'package:arrowescapegame/services/audio_service.dart';
import 'package:arrowescapegame/services/economy_service.dart';
import 'package:arrowescapegame/services/haptic_service.dart';
import 'package:arrowescapegame/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FakeStorage extends StorageService {
  PlayerProgress _progress = PlayerProgress(coins: 100, hints: 3);

  @override
  PlayerProgress get progress => _progress;

  @override
  Future<void> saveProgress(PlayerProgress p) async => _progress = p;
}

class _RecordingAnalytics implements IAnalyticsService {
  final List<(String, Map<String, dynamic>)> events = [];

  @override
  void logEvent(String name, {Map<String, dynamic>? params}) =>
      events.add((name, params ?? const {}));

  List<String> get names => [for (final e in events) e.$1];

  int count(String name) => names.where((n) => n == name).length;

  Map<String, dynamic> last(String name) =>
      events.lastWhere((e) => e.$1 == name).$2;
}

Future<void> _escapeWait() => Future.delayed(
  Duration(milliseconds: AppConstants.arrowFlightDurationForLength(45) + 60),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingAnalytics analytics;

  setUp(() {
    Get.reset();
    final storage = _FakeStorage();
    Get.put<StorageService>(storage);
    Get.put(ProgressRepository(storage));
    Get.put(EconomyService(storage));
    Get.put(HapticService());
    Get.put<IAudioService>(NoOpAudioService());
    Get.put<IAdService>(NoOpAdService());
    analytics = _RecordingAnalytics();
    Get.put<IAnalyticsService>(analytics);
  });

  tearDown(Get.reset);

  test('a completed level logs start and complete once, and no quit', () async {
    final gc = Get.put(GameplayController());
    await gc.loadLevel(1);
    final level = LevelRepository.getLevel(1);

    expect(analytics.count(AnalyticsEvent.gameSessionStart), 1);
    expect(analytics.count(AnalyticsEvent.levelStart), 1);
    expect(analytics.count(AnalyticsEvent.tutorialBegin), 1);
    final start = analytics.last(AnalyticsEvent.levelStart);
    expect(start[AnalyticsParam.levelNumber], 1);
    expect(start[AnalyticsParam.levelName], 'level_1');
    expect(start[AnalyticsParam.gameMode], GameMode.campaign);
    expect(start[AnalyticsParam.resumed], false);

    gc.dismissTutorial();
    expect(analytics.count(AnalyticsEvent.tutorialComplete), 1);

    final order = LevelSolver.solve(level.arrows, level.gridSize).solution;
    for (final id in order) {
      gc.onArrowTap(id);
      await _escapeWait();
    }

    expect(analytics.count(AnalyticsEvent.levelComplete), 1);
    final done = analytics.last(AnalyticsEvent.levelComplete);
    expect(done[AnalyticsParam.moveCount], order.length);
    expect(done[AnalyticsParam.mistakeCount], 0);
    expect(done[AnalyticsParam.stars], 3);
    expect(done[AnalyticsParam.arrowsCleared], level.arrows.length);

    // Per-tap events are not sent; moves are aggregated on level events.
    expect(analytics.names, isNot(contains('arrow_tapped')));

    // Leaving after a win is not a quit; the session ends once.
    await Get.delete<GameplayController>();
    expect(analytics.count(AnalyticsEvent.levelQuit), 0);
    expect(analytics.count(AnalyticsEvent.gameSessionEnd), 1);
    expect(
      analytics.last(AnalyticsEvent.gameSessionEnd)[AnalyticsParam
          .levelsCompleted],
      1,
    );
  });

  test('failing logs level_fail once; retry restarts as a new attempt',
      () async {
    final gc = Get.put(GameplayController());
    await gc.loadLevel(5);
    final level = LevelRepository.getLevel(5);
    final free = LevelSolver.getAvailableArrows(level.arrows, level.gridSize)
        .map((a) => a.id)
        .toSet();
    final blocked = level.arrows.firstWhere((a) => !free.contains(a.id)).id;

    for (var i = 0; i < AppConstants.startingLives; i++) {
      gc.onArrowTap(blocked);
      await Future.delayed(
        const Duration(milliseconds: AppConstants.blockedAnimDurationMs + 200),
      );
    }
    expect(gc.isGameOver.value, isTrue);
    expect(analytics.count(AnalyticsEvent.levelFail), 1);
    expect(
      analytics.last(AnalyticsEvent.levelFail)[AnalyticsParam.mistakeCount],
      AppConstants.startingLives,
    );
    final firstAttempt =
        analytics.last(AnalyticsEvent.levelStart)[AnalyticsParam.attemptNumber]
            as int;

    gc.onReset();
    expect(analytics.last(AnalyticsEvent.levelRestart)[AnalyticsParam.reason],
        'retry');
    expect(analytics.count(AnalyticsEvent.levelStart), 2);
    expect(
      analytics.last(AnalyticsEvent.levelStart)[AnalyticsParam.attemptNumber],
      firstAttempt + 1,
    );

    // Leaving the fresh attempt is a quit, reported once.
    await Get.delete<GameplayController>();
    expect(analytics.count(AnalyticsEvent.levelQuit), 1);
    expect(analytics.count(AnalyticsEvent.levelFail), 1);
  });

  test('pause, resume, hint, undo and next level are logged once each',
      () async {
    final gc = Get.put(GameplayController());
    await gc.loadLevel(3);
    final level = LevelRepository.getLevel(3);

    gc.onPauseOpened();
    gc.onPauseClosed(resumed: true);
    gc.onPauseOpened();
    gc.onPauseClosed(resumed: false);
    expect(analytics.count(AnalyticsEvent.pauseGame), 2);
    expect(analytics.count(AnalyticsEvent.resumeGame), 1);

    expect(gc.onHint(), isTrue);
    expect(analytics.count(AnalyticsEvent.hintUsed), 1);

    final free = LevelSolver.getAvailableArrows(level.arrows, level.gridSize);
    gc.onArrowTap(free.first.id);
    await _escapeWait();
    gc.onUndo();
    expect(analytics.count(AnalyticsEvent.undoUsed), 1);

    final order = LevelSolver.solve(level.arrows, level.gridSize).solution;
    for (final id in order) {
      gc.onArrowTap(id);
      await _escapeWait();
    }
    expect(analytics.count(AnalyticsEvent.levelComplete), 1);
    expect(
      analytics.last(AnalyticsEvent.levelComplete)[AnalyticsParam.hintCount],
      1,
    );

    gc.loadNextLevel();
    await Future.delayed(Duration.zero);
    while (gc.isLoadingLevel.value) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    expect(analytics.count(AnalyticsEvent.nextLevel), 1);
    expect(analytics.last(AnalyticsEvent.nextLevel)[AnalyticsParam.fromLevel],
        3);
    expect(analytics.last(AnalyticsEvent.levelStart)[AnalyticsParam.levelNumber],
        4);
    expect(analytics.count(AnalyticsEvent.levelQuit), 0);
  });
}
