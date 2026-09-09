import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/player_progress.dart';
import '../../services/storage_service.dart';

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

    await _storage.saveProgress(p);
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
