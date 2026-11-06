import 'dart:async';

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

/// Stands in for the Hive progress box: survives "app restarts" (new
/// services) within a test, like the real box does on the device.
class _Disk extends StorageService {
  _Disk(int hints) : _saved = PlayerProgress(coins: 100, hints: hints);
  PlayerProgress _saved;

  @override
  PlayerProgress get progress => _saved;

  @override
  Future<void> saveProgress(PlayerProgress p) async => _saved = p;
}

/// Rewarded ad whose outcome the test decides; [release] finishes it.
class _Ads extends NoOpAdService {
  int shown = 0;
  Completer<bool>? _open;

  @override
  Future<bool> showRewardedHint() {
    shown++;
    _open = Completer<bool>();
    return _open!.future;
  }

  void release({required bool earned}) => _open!.complete(earned);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    LevelRepository.getLevel(30);
    LevelRepository.getLevel(31);
  });

  late _Disk disk;
  late _Ads ads;

  /// A fresh app process on the same saved data.
  EconomyService launch() {
    Get.reset();
    Get.put<StorageService>(disk);
    Get.put(ProgressRepository(disk));
    final economy = Get.put(EconomyService(disk));
    Get.put(HapticService());
    Get.put<IAudioService>(NoOpAudioService());
    Get.put<IAnalyticsService>(DebugAnalyticsService());
    Get.put<IAdService>(ads);
    return economy;
  }

  setUp(() => ads = _Ads());
  tearDown(Get.reset);

  test(
    'hints used up stay used up: opening another level, reopened screen, daily, '
    'Home refresh and app restart grant nothing',
    () async {
      disk = _Disk(AppConstants.startingHints);
      var economy = launch();
      var gc = Get.put(GameplayController());
      await gc.loadLevel(30);
      for (var i = 0; i < AppConstants.startingHints; i++) {
        expect(gc.onHint(), isTrue);
        // Clear the shown hint so the next press is a new one.
        gc.hintedArrowId.value = '';
      }
      expect(economy.hints.value, 0);
      expect(disk.progress.hints, 0, reason: 'saved immediately');

      // Next level, and the same level again.
      await gc.loadLevel(31);
      await gc.loadLevel(30);
      expect(economy.hints.value, 0);

      // Leave the game screen and open it again (new controller).
      Get.delete<GameplayController>();
      gc = Get.put(GameplayController());
      await gc.loadLevel(30);
      expect(economy.hints.value, 0);

      // A daily board and Home's progress refresh.
      gc.loadLevelModel(
        LevelRepository.getLevel(31),
        dailyDateKey: '2026-11-05',
      );
      economy.refresh();
      expect(economy.hints.value, 0);

      // Restart and game-over retry.
      gc.onReset();
      expect(economy.hints.value, 0);

      // Close and reopen the app.
      economy = launch();
      gc = Get.put(GameplayController());
      await gc.loadLevel(30);
      expect(economy.hints.value, 0);
      expect(gc.onHint(), isFalse);
      expect(disk.progress.hints, 0);
    },
  );

  test('only a completed rewarded ad adds a hint, saved at once and kept '
      'across a restart', () async {
    disk = _Disk(0);
    var economy = launch();
    final gc = Get.put(GameplayController());
    await gc.loadLevel(30);

    // Closed early / failed: nothing.
    var pending = gc.watchAdForHint();
    ads.release(earned: false);
    expect(await pending, isFalse);
    expect(economy.hints.value, 0);
    expect(disk.progress.hints, 0);

    // Watched to the end: exactly one, persisted.
    pending = gc.watchAdForHint();
    ads.release(earned: true);
    expect(await pending, isTrue);
    expect(economy.hints.value, 1);
    expect(disk.progress.hints, 1);

    economy = launch();
    expect(economy.hints.value, 1);
  });

  test(
    'a second request while an ad is open is ignored: one ad, one hint',
    () async {
      disk = _Disk(0);
      final economy = launch();
      final gc = Get.put(GameplayController());
      await gc.loadLevel(30);

      final first = gc.watchAdForHint();
      final second = gc.watchAdForHint();
      expect(await second, isFalse);
      ads.release(earned: true);
      expect(await first, isTrue);
      expect(ads.shown, 1);
      expect(economy.hints.value, 1);
      expect(disk.progress.hints, 1);
    },
  );

  test('a brand-new player still starts with the usual free hints', () {
    disk = _Disk(AppConstants.startingHints);
    expect(PlayerProgress().hints, AppConstants.startingHints);
    expect(launch().hints.value, AppConstants.startingHints);
  });

  test(
    'finishing a level refills hints for the next one, saved at once',
    () async {
      disk = _Disk(0);
      var economy = launch();
      final gc = Get.put(GameplayController());
      await gc.loadLevel(1);
      final level = LevelRepository.getLevel(1);
      final order = LevelSolver.solve(level.arrows, level.gridSize).solution;
      for (final id in order) {
        final len = level.arrows.firstWhere((a) => a.id == id).length;
        gc.onArrowTap(id);
        await Future.delayed(
          Duration(
            milliseconds: AppConstants.arrowEscapeDurationForLength(len) + 20,
          ),
        );
      }
      expect(gc.isCompleting.value, isTrue);
      expect(economy.hints.value, AppConstants.startingHints);
      expect(disk.progress.hints, AppConstants.startingHints);

      // "Next Level" (or Continue after a restart) starts with them.
      gc.loadNextLevel();
      expect(economy.hints.value, AppConstants.startingHints);
      economy = launch();
      expect(economy.hints.value, AppConstants.startingHints);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('the refill only tops up: extra hints from ads are kept', () {
    disk = _Disk(5);
    final economy = launch();
    economy.refillHintsForNextLevel();
    expect(economy.hints.value, 5);
    economy.hints.value = 1;
    economy.refillHintsForNextLevel();
    expect(economy.hints.value, AppConstants.startingHints);
    expect(disk.progress.hints, AppConstants.startingHints);
  });

  test('a daily challenge win does not refill hints', () async {
    disk = _Disk(0);
    final economy = launch();
    final gc = Get.put(GameplayController());
    final board = LevelRepository.getLevel(1);
    gc.loadLevelModel(board, dailyDateKey: '2026-11-06');
    final order = LevelSolver.solve(board.arrows, board.gridSize).solution;
    for (final id in order) {
      final len = board.arrows.firstWhere((a) => a.id == id).length;
      gc.onArrowTap(id);
      await Future.delayed(
        Duration(
          milliseconds: AppConstants.arrowEscapeDurationForLength(len) + 20,
        ),
      );
    }
    expect(gc.isCompleting.value, isTrue);
    expect(economy.hints.value, 0);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
