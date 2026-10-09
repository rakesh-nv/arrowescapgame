import 'dart:io';

import 'package:arrowescapegame/core/constants/app_constants.dart';
import 'package:arrowescapegame/data/models/arrow_state.dart';
import 'package:arrowescapegame/data/models/game_settings.dart';
import 'package:arrowescapegame/data/models/player_progress.dart';
import 'package:arrowescapegame/data/repositories/level_repository.dart';
import 'package:arrowescapegame/data/repositories/progress_repository.dart';
import 'package:arrowescapegame/game/config/difficulty_curve.dart';
import 'package:arrowescapegame/game/generator/level_generator.dart';
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
import 'package:hive_flutter/hive_flutter.dart';

/// In-memory progress; saved games use StorageService's in-memory fallback.
class FakeStorageService extends StorageService {
  PlayerProgress _progress = PlayerProgress(coins: 100, hints: 3);

  @override
  PlayerProgress get progress => _progress;

  @override
  Future<void> saveProgress(PlayerProgress p) async => _progress = p;
}

Future<void> _escapeWait() => Future.delayed(
      Duration(milliseconds: AppConstants.arrowFlightDurationForLength(45) + 60),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Campaign progression through GameplayController', () {
    late FakeStorageService storage;
    late ProgressRepository progress;
    late EconomyService economy;

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

    test('an uncached level loads off the UI isolate with the right spec',
        () async {
      LevelRepository.clearCache();
      final gc = Get.put(GameplayController());
      final load = gc.loadLevel(23);
      expect(gc.isLoadingLevel.value, isTrue);
      await load;
      expect(gc.isLoadingLevel.value, isFalse);
      expect(gc.currentLevelNumber, 23);
      expect(gc.gridSize, LevelGenerator.gridForLevel(23));
      expect(gc.shapeName, LevelGenerator.silhouetteForLevel(23).name);
      expect(gc.difficulty, DifficultyCurve.worldFor(23).difficulty);
      expect(gc.arrows.length, LevelRepository.cachedLevel(23)!.arrows.length);
    });

    test('clearing level 1 pays coins, saves stars and unlocks level 2',
        () async {
      final gc = Get.put(GameplayController());
      await gc.loadLevel(1);
      final level = LevelRepository.getLevel(1);
      final order = LevelSolver.solve(level.arrows, level.gridSize).solution;
      final coinsBefore = economy.coins.value;

      for (final id in order) {
        gc.onArrowTap(id);
        await _escapeWait();
      }

      expect(gc.isCompleting.value, isTrue);
      expect(gc.mistakes.value, 0);
      expect(progress.progress.starsForLevel(1), 3);
      expect(progress.progress.highestUnlockedLevel, 2);
      expect(
        economy.coins.value,
        coinsBefore +
            AppConstants.coinsPerLevelComplete +
            AppConstants.coinsFor3Stars,
      );
      expect(gc.lastCoinsEarned,
          AppConstants.coinsPerLevelComplete + AppConstants.coinsFor3Stars);
      expect(storage.getSavedGame(1), isNull);

      // "Next Level" loads level 2 with its own spec.
      await gc.loadLevel(2);
      expect(gc.currentLevelNumber, 2);
      expect(gc.gridSize, LevelGenerator.gridForLevel(2));
      expect(gc.isComplete.value, isFalse);
    });

    test('restart reproduces exactly the same board', () async {
      final gc = Get.put(GameplayController());
      await gc.loadLevel(12);
      final fresh = {
        for (final a in LevelRepository.getLevel(12).arrows) a.id: a.points,
      };
      final level = LevelRepository.getLevel(12);
      final free = LevelSolver.getAvailableArrows(level.arrows, level.gridSize);
      gc.onArrowTap(free.first.id);
      await _escapeWait();
      expect(gc.clearedArrows, 1);
      expect(storage.getSavedGame(12), isNotNull);

      gc.onReset();
      expect(gc.clearedArrows, 0);
      expect(gc.lives.value, AppConstants.startingLives);
      expect({for (final a in gc.arrows) a.id: a.points}, equals(fresh));
      expect(storage.getSavedGame(12), isNull);
    });

    test('a blocked tap costs a heart and highlights the blocking arrow',
        () async {
      final gc = Get.put(GameplayController());
      await gc.loadLevel(30);
      final level = LevelRepository.getLevel(30);
      final free = LevelSolver.getAvailableArrows(level.arrows, level.gridSize)
          .map((a) => a.id)
          .toSet();
      final blocked = level.arrows.firstWhere((a) => !free.contains(a.id));

      gc.onArrowTap(blocked.id);
      expect(gc.lives.value, AppConstants.startingLives - 1);
      expect(gc.mistakes.value, 1);
      expect(
        gc.blockerArrowId.value,
        LevelSolver.firstBlocker(blocked, level.arrows, level.gridSize),
      );
      expect(gc.blockerArrowId.value, isNotEmpty);
      expect(
        gc.arrows.firstWhere((a) => a.id == blocked.id).state,
        isNot(ArrowState.removed),
      );
    });

    test('the tutorial shows on level 1 only until it has been seen',
        () async {
      final gc = Get.put(GameplayController());
      await gc.loadLevel(1);
      expect(gc.isTutorialLevel.value, isTrue);
      gc.dismissTutorial();
      expect(progress.progress.hasSeenTutorial, isTrue);
      await gc.loadLevel(1);
      expect(gc.isTutorialLevel.value, isFalse);
      gc.showTutorial();
      expect(gc.isTutorialLevel.value, isTrue);
    });

    test('players who finished the old 100-level campaign get level 101',
        () async {
      storage._progress = PlayerProgress(
        highestUnlockedLevel: 100,
        levelStars: {for (var l = 1; l <= 100; l++) l: 3},
      );
      await progress.normalizeUnlocks();
      expect(progress.progress.highestUnlockedLevel, 101);

      // No completed levels: nothing changes.
      storage._progress = PlayerProgress(highestUnlockedLevel: 1);
      await progress.normalizeUnlocks();
      expect(progress.progress.highestUnlockedLevel, 1);
    });
  });

  group('Saved games from older generator versions', () {
    late Directory tempDir;
    late StorageService storage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_saves_');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(AppConstants.playerProgressTypeId)) {
        Hive.registerAdapter(PlayerProgressAdapter());
      }
      if (!Hive.isAdapterRegistered(AppConstants.gameSettingsTypeId)) {
        Hive.registerAdapter(GameSettingsAdapter());
      }
      storage = StorageService();
      await storage.init();
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('a legacy campaign save (no version) is ignored and removed',
        () async {
      final box = Hive.box('saved_game');
      await box.put('level_5', {
        'levelNumber': 5,
        'removedArrowIds': ['a001'],
        'moves': 1,
        'mistakes': 0,
        'lives': 4,
      });
      await box.put('last_active_level', 5);

      expect(storage.getSavedGame(5), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(box.containsKey('level_5'), isFalse);
      // The level number itself is still meaningful for "Continue".
      expect(storage.getLastActiveLevel(), 5);
    });

    test('a save from an older generator version is ignored', () async {
      await Hive.box('saved_game').put('level_9', {
        'levelNumber': 9,
        'removedArrowIds': ['a003'],
        'moves': 1,
        'mistakes': 0,
        'lives': 4,
        'genVersion': AppConstants.levelGeneratorVersion - 1,
      });
      expect(storage.getSavedGame(9), isNull);
    });

    test('a legacy daily save is ignored too', () async {
      await Hive.box('saved_game').put('daily_2026-10-09', {
        'dateKey': '2026-10-09',
        'removedArrowIds': ['a001'],
        'moves': 1,
        'mistakes': 0,
        'lives': 4,
      });
      expect(storage.getDailySavedGame('2026-10-09'), isNull);
    });

    test('a save made by this version round-trips through Hive', () async {
      await storage.saveGame(
        levelNumber: 7,
        removedArrowIds: ['a002'],
        moves: 1,
        mistakes: 0,
        lives: 4,
      );
      final saved = storage.getSavedGame(7);
      expect(saved, isNotNull);
      expect(saved!['removedArrowIds'], ['a002']);
      expect(saved['genVersion'], AppConstants.levelGeneratorVersion);
    });
  });
}
