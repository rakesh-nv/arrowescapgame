import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/progress_repository.dart';
import '../../game/config/difficulty_curve.dart';

/// What a level node on the map shows.
enum MapNodeState {
  /// Not reachable yet.
  locked,

  /// Unlocked but neither completed nor the frontier level.
  available,

  /// The furthest unlocked, not yet completed level.
  current,

  /// Completed at least once (stars are shown).
  completed,
}

/// Trophy earned by clearing a whole world. Display only: it never awards
/// currency.
enum WorldTrophy { none, bronze, gold }

class LevelSelectController extends GetxController {
  final ProgressRepository _progress = Get.find<ProgressRepository>();

  /// Global tracking of the most recently completed level for map animation.
  static final RxInt justCompletedLevel = 0.obs;
  static int lastAnimatedLevel = 0;

  final RxInt totalStarsCount = 0.obs;

  /// Bumped whenever progress changes so the map can rebuild.
  final RxInt progressVersion = 0.obs;

  @override
  void onInit() {
    super.onInit();
    refreshProgress();
  }

  void refreshProgress() {
    totalStarsCount.value = _progress.progress.totalStars;
    progressVersion.value++;
  }

  int get highestUnlocked => _progress.progress.highestUnlockedLevel;
  int get totalStars => totalStarsCount.value;
  int get totalLevels => AppConstants.totalLevels;
  int get completedCount => _progress.progress.levelStars.keys
      .where((l) => l >= 1 && l <= AppConstants.totalLevels)
      .length;

  bool isUnlocked(int level) => level <= highestUnlocked;
  bool isCompleted(int level) => _progress.progress.isLevelCompleted(level);
  int starsForLevel(int level) => _progress.progress.starsForLevel(level);
  bool isCurrent(int level) => level == highestUnlocked;
  bool isBossLevel(int level) => level % 10 == 0;
  bool isChallengeLevel(int level) => level % 5 == 0 && !isBossLevel(level);

  /// Map state of [level]. Unlocking always comes from saved progress; the
  /// map never unlocks anything itself.
  MapNodeState nodeState(int level) {
    if (level < 1 || level > totalLevels || !isUnlocked(level)) {
      return MapNodeState.locked;
    }
    if (isCompleted(level)) return MapNodeState.completed;
    if (isCurrent(level)) return MapNodeState.current;
    return MapNodeState.available;
  }

  /// Level the map focuses on when it opens: the frontier level, or the
  /// last level once the campaign is finished.
  int get focusLevel => highestUnlocked.clamp(1, totalLevels);

  bool get isCampaignComplete => isCompleted(totalLevels);

  int _lastLevelOf(CampaignWorld w) =>
      w.lastLevel > totalLevels ? totalLevels : w.lastLevel;

  int worldLevelCount(CampaignWorld w) => _lastLevelOf(w) - w.firstLevel + 1;

  bool isWorldUnlocked(CampaignWorld w) => w.firstLevel <= highestUnlocked;

  int worldClearedCount(CampaignWorld w) {
    var n = 0;
    for (var l = w.firstLevel; l <= _lastLevelOf(w); l++) {
      if (isCompleted(l)) n++;
    }
    return n;
  }

  int worldStars(CampaignWorld w) {
    var n = 0;
    for (var l = w.firstLevel; l <= _lastLevelOf(w); l++) {
      n += starsForLevel(l);
    }
    return n;
  }

  WorldTrophy worldTrophy(CampaignWorld w) {
    final count = worldLevelCount(w);
    if (count <= 0 || worldClearedCount(w) < count) return WorldTrophy.none;
    return worldStars(w) >= count * 3 ? WorldTrophy.gold : WorldTrophy.bronze;
  }

  /// Called when a level is completed to flag it for progression animation.
  static void recordLevelCompletion(int level) {
    justCompletedLevel.value = level;
    if (Get.isRegistered<LevelSelectController>()) {
      Get.find<LevelSelectController>().refreshProgress();
    }
  }
}
