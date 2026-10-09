import 'package:arrowescapegame/core/constants/app_constants.dart';
import 'package:arrowescapegame/data/models/arrow_direction.dart';
import 'package:arrowescapegame/data/models/arrow_model.dart';
import 'package:arrowescapegame/data/models/arrow_state.dart';
import 'package:arrowescapegame/data/models/difficulty.dart';
import 'package:arrowescapegame/data/models/level_model.dart';
import 'package:arrowescapegame/data/models/player_progress.dart';
import 'package:arrowescapegame/data/repositories/progress_repository.dart';
import 'package:arrowescapegame/modules/ads/services/ad_service.dart';
import 'package:arrowescapegame/modules/daily_challenge/daily_challenge_controller.dart';
import 'package:arrowescapegame/modules/gameplay/gameplay_controller.dart';
import 'package:arrowescapegame/modules/home/home_controller.dart';
import 'package:arrowescapegame/services/analytics_service.dart';
import 'package:arrowescapegame/services/audio_service.dart';
import 'package:arrowescapegame/services/economy_service.dart';
import 'package:arrowescapegame/services/haptic_service.dart';
import 'package:arrowescapegame/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// In-memory progress; saved games use StorageService's in-memory fallback.
class FakeStorageService extends StorageService {
  PlayerProgress _progress = PlayerProgress(coins: 100, hints: 3);

  @override
  PlayerProgress get progress => _progress;

  @override
  Future<void> saveProgress(PlayerProgress p) async => _progress = p;
}

/// Two one-cell arrows that can both escape immediately.
LevelModel _dailyBoard() => LevelModel(
      levelNumber: 0,
      seed: 20261009,
      gridSize: 4,
      difficulty: Difficulty.normal,
      arrowCount: 2,
      maxMistakes: 3,
      arrows: [
        ArrowModel(
          id: 'a1',
          headRow: 0,
          headCol: 0,
          length: 1,
          direction: ArrowDirection.up,
        ),
        ArrowModel(
          id: 'a2',
          headRow: 3,
          headCol: 3,
          length: 1,
          direction: ArrowDirection.down,
        ),
      ],
    );

Future<void> _waitForEscape() => Future.delayed(
      Duration(milliseconds: AppConstants.arrowEscapeDurationForLength(1) + 50),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeStorageService storage;
  late EconomyService economy;
  late ProgressRepository progress;

  setUp(() {
    Get.reset();
    storage = FakeStorageService();
    Get.put<StorageService>(storage);
    progress = Get.put(ProgressRepository(storage));
    economy = Get.put(EconomyService(storage));
    Get.put(HapticService());
    Get.put<IAudioService>(NoOpAudioService());
    Get.put<IAnalyticsService>(DebugAnalyticsService());
    Get.put<IAdService>(NoOpAdService());
  });

  tearDown(Get.reset);

  group('Daily saves are separate from campaign saves', () {
    test('daily save does not write level_0 or last_active_level', () async {
      await storage.saveGame(
        levelNumber: 5,
        removedArrowIds: ['a1'],
        moves: 1,
        mistakes: 0,
        lives: 4,
      );
      await storage.saveDailyGame(
        dateKey: '2026-10-09',
        removedArrowIds: ['a2'],
        moves: 1,
        mistakes: 0,
        lives: 4,
      );

      expect(storage.getSavedGame(0), isNull);
      expect(storage.getLastActiveLevel(), 5);
      expect(storage.getSavedGame(5)!['removedArrowIds'], ['a1']);
      expect(storage.getDailySavedGame('2026-10-09')!['removedArrowIds'],
          ['a2']);

      await storage.clearDailySavedGame('2026-10-09');
      expect(storage.getDailySavedGame('2026-10-09'), isNull);
      expect(storage.getSavedGame(5), isNotNull);
      expect(storage.getLastActiveLevel(), 5);
    });

    test('a new date replaces the previous date\'s daily save', () async {
      await storage.saveDailyGame(
        dateKey: '2026-10-08',
        removedArrowIds: ['a1'],
        moves: 1,
        mistakes: 0,
        lives: 4,
      );
      await storage.saveDailyGame(
        dateKey: '2026-10-09',
        removedArrowIds: ['a2'],
        moves: 1,
        mistakes: 0,
        lives: 4,
      );

      expect(storage.getDailySavedGame('2026-10-08'), isNull);
      expect(storage.getDailySavedGame('2026-10-09'), isNotNull);
    });
  });

  group('Daily gameplay', () {
    test('a daily win leaves campaign progress and coins untouched', () async {
      final coinsBefore = economy.coins.value;
      final gc = Get.put(GameplayController());
      gc.loadLevelModel(_dailyBoard(), dailyDateKey: '2026-10-09');
      expect(gc.isDailyChallenge.value, isTrue);

      gc.onArrowTap('a1');
      await _waitForEscape();
      gc.onArrowTap('a2');
      await _waitForEscape();

      expect(gc.isCompleting.value, isTrue);
      expect(progress.progress.levelStars, isEmpty);
      expect(progress.progress.highestUnlockedLevel, 1);
      expect(storage.getLastActiveLevel(), isNull);
      expect(storage.getSavedGame(0), isNull);
      expect(storage.getDailySavedGame('2026-10-09'), isNull);
      // The daily reward is paid by DailyChallengeController, not here.
      expect(economy.coins.value, coinsBefore);
      expect(gc.lastCoinsEarned, AppConstants.coinsDailyChallenge);
    });

    test('a partly played daily resumes after a restart, same date only',
        () async {
      final gc = Get.put(GameplayController());
      gc.loadLevelModel(_dailyBoard(), dailyDateKey: '2026-10-09');
      gc.onArrowTap('a1');
      await _waitForEscape();
      expect(storage.getDailySavedGame('2026-10-09'), isNotNull);
      expect(storage.getLastActiveLevel(), isNull);

      // Simulate an app restart: a fresh controller loads the same daily.
      Get.delete<GameplayController>();
      final restarted = Get.put(GameplayController());
      restarted.loadLevelModel(_dailyBoard(), dailyDateKey: '2026-10-09');
      expect(restarted.moves.value, 1);
      expect(
        restarted.arrows.firstWhere((a) => a.id == 'a1').state,
        ArrowState.removed,
      );

      // The next day's challenge never picks up the old save.
      restarted.loadLevelModel(_dailyBoard(), dailyDateKey: '2026-10-10');
      expect(restarted.moves.value, 0);
      expect(
        restarted.arrows.every((a) => a.state == ArrowState.normal),
        isTrue,
      );
    });

    test('replaying a daily already completed shows no coins', () async {
      progress.progress.lastDailyCompletedDate = '2026-10-09';
      final gc = Get.put(GameplayController());
      gc.loadLevelModel(_dailyBoard(), dailyDateKey: '2026-10-09');
      gc.onArrowTap('a1');
      await _waitForEscape();
      gc.onArrowTap('a2');
      await _waitForEscape();

      expect(gc.lastCoinsEarned, 0);
    });
  });

  group('Daily completion, streak and date changes', () {
    DailyChallengeController controllerFor(String dateKey) =>
        DailyChallengeController()..todayKey = dateKey;

    test('completing the day after the last completion extends the streak',
        () async {
      progress.progress
        ..dailyStreak = 4
        ..lastDailyCompletedDate = '2026-10-08';
      final coinsBefore = economy.coins.value;

      await controllerFor('2026-10-09').onChallengeComplete(3);

      expect(progress.progress.dailyStreak, 5);
      expect(progress.progress.lastDailyCompletedDate, '2026-10-09');
      expect(economy.coins.value,
          coinsBefore + AppConstants.coinsDailyChallenge);
    });

    test('a missed day resets the streak to 1', () async {
      progress.progress
        ..dailyStreak = 4
        ..lastDailyCompletedDate = '2026-10-06';

      await controllerFor('2026-10-09').onChallengeComplete(2);

      expect(progress.progress.dailyStreak, 1);
    });

    test('finishing after midnight counts for the challenge\'s own date',
        () async {
      // Started on 10-09 (todayKey captured then), finished on 10-10.
      progress.progress
        ..dailyStreak = 2
        ..lastDailyCompletedDate = '2026-10-08';

      await controllerFor('2026-10-09').onChallengeComplete(3);

      expect(progress.progress.lastDailyCompletedDate, '2026-10-09');
      expect(progress.progress.dailyStreak, 3);
    });

    test('an older challenge never overwrites a newer completion', () async {
      progress.progress
        ..dailyStreak = 3
        ..lastDailyCompletedDate = '2026-10-10';
      final coinsBefore = economy.coins.value;

      await controllerFor('2026-10-09').onChallengeComplete(3);

      expect(progress.progress.lastDailyCompletedDate, '2026-10-10');
      expect(progress.progress.dailyStreak, 3);
      expect(economy.coins.value, coinsBefore);
    });

    test('previousDateKey crosses month, year and leap-day boundaries', () {
      expect(DailyChallengeController.previousDateKey('2026-10-09'),
          '2026-10-08');
      expect(DailyChallengeController.previousDateKey('2026-03-01'),
          '2026-02-28');
      expect(DailyChallengeController.previousDateKey('2028-03-01'),
          '2028-02-29');
      expect(DailyChallengeController.previousDateKey('2026-01-01'),
          '2025-12-31');
    });
  });

  group('Legacy level-0 data from older builds', () {
    test('Home never offers "Continue Level 0"', () async {
      await storage.saveGame(
        levelNumber: 0,
        removedArrowIds: ['a1'],
        moves: 1,
        mistakes: 0,
        lives: 4,
      );
      final home = Get.put(HomeController());
      expect(home.lastActiveLevel.value, isNull);
      expect(home.currentLevel, 1);
    });

    test('stars stored under level 0 are not counted', () {
      final p = PlayerProgress(levelStars: {0: 3, 1: 2, 2: 3});
      expect(p.totalStars, 5);
    });
  });
}
