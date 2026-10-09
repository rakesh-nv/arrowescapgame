import 'dart:isolate';

import 'package:get/get.dart';
import '../../data/models/daily_challenge.dart';
import '../../data/repositories/level_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/models/level_model.dart';
import '../../services/economy_service.dart';
import '../gameplay/gameplay_controller.dart';

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

  Worker? _completionWorker;

  /// Records today's completion when [gameplay] finishes the daily board.
  void watchCompletion(GameplayController gameplay) {
    _completionWorker?.dispose();
    _completionWorker = ever(gameplay.isComplete, (bool done) {
      if (done) onChallengeComplete(gameplay.calculatedStars);
    });
  }

  @override
  void onClose() {
    _completionWorker?.dispose();
    super.onClose();
  }

  Future<void> onChallengeComplete(int stars) async {
    if (isCompletedToday.value) return;
    isCompletedToday.value = true;

    // The streak is judged against the challenge's own date ([todayKey]), not
    // the clock, so finishing after midnight still counts for that challenge.
    final p = _progress.progress;
    final last = p.lastDailyCompletedDate;
    // A later date was already recorded (e.g. the next day's challenge was
    // finished first): pay nothing and leave the streak alone.
    if (last != null && last.compareTo(todayKey) >= 0) return;

    final newStreak =
        last == previousDateKey(todayKey) ? p.dailyStreak + 1 : 1;
    streak.value = newStreak;

    await _progress.updateDailyStreak(streak: newStreak, dateKey: todayKey);
    _economy.awardDailyChallenge();
  }

  /// The 'YYYY-MM-DD' key of the day before [dateKey].
  static String previousDateKey(String dateKey) {
    final parts = dateKey.split('-').map(int.parse).toList();
    // Noon avoids DST edges when stepping back one day.
    final prev = DateTime(parts[0], parts[1], parts[2], 12)
        .subtract(const Duration(days: 1));
    return '${prev.year}-${prev.month.toString().padLeft(2, '0')}-${prev.day.toString().padLeft(2, '0')}';
  }
}
