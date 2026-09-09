import 'package:get/get.dart';
import '../../data/repositories/progress_repository.dart';

class LevelSelectController extends GetxController {
  final ProgressRepository _progress = Get.find<ProgressRepository>();

  int get highestUnlocked => _progress.progress.highestUnlockedLevel;

  bool isUnlocked(int level) => level <= highestUnlocked;
  bool isCompleted(int level) => _progress.progress.isLevelCompleted(level);
  int starsForLevel(int level) => _progress.progress.starsForLevel(level);
  bool isCurrent(int level) => level == highestUnlocked;
}
