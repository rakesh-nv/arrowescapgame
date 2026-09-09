import 'package:get/get.dart';
import '../../data/repositories/progress_repository.dart';
import '../../services/economy_service.dart';

class HomeController extends GetxController {
  final ProgressRepository _progress = Get.find<ProgressRepository>();
  final EconomyService _economy = Get.find<EconomyService>();

  RxInt get coins => _economy.coins;
  RxInt get hints => _economy.hints;

  final RxInt highestUnlockedLevel = 1.obs;
  final RxInt totalStars = 0.obs;

  int get currentLevel => highestUnlockedLevel.value;
  bool get hasProgress => highestUnlockedLevel.value > 1;

  @override
  void onInit() {
    super.onInit();
    loadProgress();
  }

  void loadProgress() {
    highestUnlockedLevel.value = _progress.progress.highestUnlockedLevel;
    totalStars.value = _progress.progress.totalStars;
    _economy.refresh();
  }
}
