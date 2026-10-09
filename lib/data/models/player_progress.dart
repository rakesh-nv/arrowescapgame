import 'package:hive/hive.dart';
import '../../core/constants/app_constants.dart';

part 'player_progress.g.dart';

@HiveType(typeId: AppConstants.playerProgressTypeId)
class PlayerProgress extends HiveObject {
  @HiveField(0)
  int highestUnlockedLevel;

  @HiveField(1)
  Map<int, int> levelStars; // levelNumber → stars (1-3)

  @HiveField(2)
  int coins;

  @HiveField(3)
  int hints;

  @HiveField(4)
  String currentThemeId;

  @HiveField(5)
  int dailyStreak;

  @HiveField(6)
  String? lastDailyCompletedDate; // ISO date string 'YYYY-MM-DD'

  @HiveField(7)
  bool removeAds;

  @HiveField(8)
  bool hasSeenTutorial;

  @HiveField(9)
  List<String> unlockedThemes;

  PlayerProgress({
    this.highestUnlockedLevel = 1,
    Map<int, int>? levelStars,
    this.coins = AppConstants.startingCoins,
    this.hints = AppConstants.startingHints,
    this.currentThemeId = 'classic',
    this.dailyStreak = 0,
    this.lastDailyCompletedDate,
    this.removeAds = false,
    this.hasSeenTutorial = false,
    List<String>? unlockedThemes,
  })  : levelStars = levelStars ?? {},
        unlockedThemes = unlockedThemes ?? ['classic', 'ocean'];

  bool isThemeUnlocked(String themeId) {
    if (themeId == 'classic' || themeId == 'ocean' || themeId == currentThemeId) {
      return true;
    }
    return unlockedThemes.contains(themeId);
  }

  int starsForLevel(int level) => levelStars[level] ?? 0;

  bool isLevelUnlocked(int level) => level <= highestUnlockedLevel;

  bool isLevelCompleted(int level) => levelStars.containsKey(level);

  // Older builds stored daily wins as level 0; campaign levels start at 1.
  int get totalStars => levelStars.entries
      .where((e) => e.key >= 1)
      .fold(0, (sum, e) => sum + e.value);
}
