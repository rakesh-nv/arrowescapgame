import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/progress_repository.dart';

class LevelSelectController extends GetxController {
  final ProgressRepository _progress = Get.find<ProgressRepository>();

  /// Global tracking of the most recently completed level for map animation.
  static final RxInt justCompletedLevel = 0.obs;
  static int lastAnimatedLevel = 0;

  final RxInt totalStarsCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    refreshProgress();
  }

  void refreshProgress() {
    totalStarsCount.value = _progress.progress.totalStars;
  }

  int get highestUnlocked => _progress.progress.highestUnlockedLevel;
  int get totalStars => totalStarsCount.value;
  int get totalLevels => AppConstants.totalLevels;

  bool isUnlocked(int level) => level <= highestUnlocked;
  bool isCompleted(int level) => _progress.progress.isLevelCompleted(level);
  int starsForLevel(int level) => _progress.progress.starsForLevel(level);
  bool isCurrent(int level) => level == highestUnlocked;
  bool isBossLevel(int level) => level % 10 == 0;
  bool isChallengeLevel(int level) => level % 5 == 0 && !isBossLevel(level);

  /// Called when a level is completed to flag it for progression animation.
  static void recordLevelCompletion(int level) {
    justCompletedLevel.value = level;
    if (Get.isRegistered<LevelSelectController>()) {
      Get.find<LevelSelectController>().refreshProgress();
    }
  }

  /// Calculates node center X along the winding path.
  double getNodeX(int level, double screenWidth) {
    final centerX = screenWidth / 2;
    final maxAmp = (screenWidth * 0.28).clamp(70.0, 140.0);
    final i = level - 1;
    final offset = math.sin(i * 0.48) * 0.75 + math.sin(i * 0.18) * 0.25;
    return centerX + offset * maxAmp;
  }

  /// Calculates node center Y relative to total map height (bottom to top).
  double getNodeY(
      int level, double totalHeight, double rowHeight, double paddingBottom) {
    return totalHeight - paddingBottom - (level - 0.5) * rowHeight;
  }

  /// Calculates scroll offset to center a specific level in the viewport.
  double getScrollOffsetForLevel(
    int level,
    double totalHeight,
    double rowHeight,
    double paddingBottom,
    double viewportHeight,
    double maxScroll,
  ) {
    final y = getNodeY(level, totalHeight, rowHeight, paddingBottom);
    final target = y - (viewportHeight / 2);
    return target.clamp(0.0, maxScroll);
  }
}
