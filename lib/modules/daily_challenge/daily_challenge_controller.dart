import 'dart:isolate';

import 'package:get/get.dart';
import '../../data/models/daily_challenge.dart';
import '../../data/repositories/level_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/models/level_model.dart';
import '../../services/economy_service.dart';

class DailyChallengeController extends GetxController {
  final ProgressRepository _progress = Get.find<ProgressRepository>();
  final EconomyService _economy = Get.find<EconomyService>();

  final RxBool isCompletedToday = false.obs;
  final RxInt streak = 0.obs;
  final RxBool isChallengeLoading = true.obs;
  final RxString challengeLoadError = ''.obs;
  LevelModel? _challengeLevel;
  late String todayKey;

  LevelModel? get challengeLevel => _challengeLevel;

  @override
  void onInit() {
    super.onInit();
    todayKey = DailyChallenge.todayKey();
    final p = _progress.progress;
    streak.value = p.dailyStreak;
    isCompletedToday.value = p.lastDailyCompletedDate == todayKey;
    _loadChallenge();
  }

  /// Level generation is CPU-intensive. Run it outside the UI isolate so the
  /// route can render and remain responsive on lower-end devices.
  Future<void> _loadChallenge() async {
    isChallengeLoading.value = true;
    challengeLoadError.value = '';
    final seed = DailyChallenge.seedFromDate(todayKey);

    try {
      _challengeLevel = await Isolate.run(
        () => LevelRepository.getDailyChallenge(seed),
      );
    } catch (_) {
      challengeLoadError.value = 'Could not prepare today\'s challenge.';
    } finally {
      isChallengeLoading.value = false;
    }
  }

  Future<void> retryChallengeLoad() => _loadChallenge();

  Future<void> onChallengeComplete(int stars) async {
    if (isCompletedToday.value) return;
    isCompletedToday.value = true;

    // Update streak
    final p = _progress.progress;
    final yesterday = _yesterdayKey();
    final newStreak =
        p.lastDailyCompletedDate == yesterday ? p.dailyStreak + 1 : 1;
    streak.value = newStreak;

    await _progress.updateDailyStreak(streak: newStreak, dateKey: todayKey);
    _economy.awardDailyChallenge();
  }

  String _yesterdayKey() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }
}
