import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/daily_challenge.dart';
import '../../data/repositories/progress_repository.dart';
import '../../game/config/difficulty_curve.dart';
import '../../services/economy_service.dart';
import '../../services/storage_service.dart';

class HomeController extends GetxController {
  final ProgressRepository _progress = Get.find<ProgressRepository>();
  final EconomyService _economy = Get.find<EconomyService>();
  final StorageService _storage = Get.find<StorageService>();

  RxInt get coins => _economy.coins;
  RxInt get hints => _economy.hints;

  final RxInt highestUnlockedLevel = 1.obs;
  final RxInt totalStars = 0.obs;
  final RxInt levelsCompleted = 0.obs;
  final Rx<int?> lastActiveLevel = Rx<int?>(null);
  final RxBool dailyDoneToday = false.obs;
  final RxInt dailyStreak = 0.obs;

  /// The level "Continue" opens: an unfinished board the player left, or the
  /// furthest unlocked level.
  int get currentLevel => lastActiveLevel.value ?? highestUnlockedLevel.value;
  bool get hasProgress =>
      lastActiveLevel.value != null || highestUnlockedLevel.value > 1;
  bool get isResuming => lastActiveLevel.value != null;
  bool get campaignComplete =>
      levelsCompleted.value >= AppConstants.totalLevels;
  CampaignWorld get currentWorld => DifficultyCurve.worldFor(currentLevel);
  int get maxStars => AppConstants.totalLevels * 3;

  @override
  void onInit() {
    super.onInit();
    loadProgress();
  }

  void loadProgress() {
    final p = _progress.progress;
    highestUnlockedLevel.value = p.highestUnlockedLevel;
    totalStars.value = p.totalStars;
    levelsCompleted.value = p.levelStars.keys
        .where((l) => l >= 1 && l <= AppConstants.totalLevels)
        .length;
    dailyStreak.value = p.dailyStreak;
    dailyDoneToday.value = p.lastDailyCompletedDate == DailyChallenge.todayKey();

    // Only resume a level that still has an unfinished saved board. Older
    // builds could save a daily run as "level 0"; never offer that.
    final last = _storage.getLastActiveLevel();
    lastActiveLevel.value =
        (last != null && last >= 1 && _storage.getSavedGame(last) != null)
            ? last
            : null;
    _economy.refresh();
  }
}
