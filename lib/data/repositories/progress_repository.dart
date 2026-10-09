import 'dart:math' show max;

import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/player_progress.dart';
import '../../services/storage_service.dart';
import '../../modules/level_select/level_select_controller.dart';

/// Provides access to player progress with validation
class ProgressRepository extends GetxService {
  final StorageService _storage;

  ProgressRepository(this._storage);

  PlayerProgress get progress => _storage.progress;

  Future<void> markLevelCompleted({
    required int levelNumber,
    required int stars,
  }) async {
    final p = progress;

    // Only upgrade stars, never downgrade
    final existing = p.starsForLevel(levelNumber);
    if (stars > existing) {
      p.levelStars[levelNumber] = stars;
    }

    // Unlock next level
    if (levelNumber >= p.highestUnlockedLevel &&
        levelNumber < AppConstants.totalLevels) {
      p.highestUnlockedLevel = levelNumber + 1;
    }

    LevelSelectController.recordLevelCompletion(levelNumber);

    await _storage.saveProgress(p);
  }

  /// Makes sure the level after the furthest completed one is unlocked.
  /// Builds with a shorter campaign capped unlocks at their last level, so a
  /// player who finished it would otherwise find the new levels locked.
  Future<void> normalizeUnlocks() async {
    final p = progress;
    final completed = p.levelStars.keys.where((l) => l >= 1);
    if (completed.isEmpty) return;
    final target = (completed.reduce(max) + 1).clamp(1, AppConstants.totalLevels);
    if (target > p.highestUnlockedLevel) {
      p.highestUnlockedLevel = target;
      await _storage.saveProgress(p);
    }
  }

  Future<void> updateCoinsAndHints({
    required int coins,
    required int hints,
  }) async {
    final p = progress;
    p.coins = coins.clamp(0, 999999);
    p.hints = hints.clamp(0, 999);
    await _storage.saveProgress(p);
  }

  Future<void> updateTheme(String themeId) async {
    final p = progress;
    if (!p.unlockedThemes.contains(themeId)) {
      p.unlockedThemes.add(themeId);
    }
    p.currentThemeId = themeId;
    await _storage.saveProgress(p);
  }

  Future<void> unlockTheme(String themeId) async {
    final p = progress;
    if (!p.unlockedThemes.contains(themeId)) {
      p.unlockedThemes.add(themeId);
    }
    p.currentThemeId = themeId;
    await _storage.saveProgress(p);
  }

  Future<void> updateDailyStreak({
    required int streak,
    required String dateKey,
  }) async {
    final p = progress;
    p.dailyStreak = streak;
    p.lastDailyCompletedDate = dateKey;
    await _storage.saveProgress(p);
  }

  Future<void> markTutorialSeen() async {
    final p = progress;
    p.hasSeenTutorial = true;
    await _storage.saveProgress(p);
  }

  Future<void> resetAllProgress() async {
    await _storage.clearProgress();
  }
}
