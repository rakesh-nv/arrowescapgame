import 'package:get/get.dart';
import '../../data/models/theme_model.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/theme_repository.dart';
import '../../services/economy_service.dart';
import '../../services/analytics_service.dart';

class ThemesController extends GetxController {
  final ProgressRepository _progress = Get.find<ProgressRepository>();
  final EconomyService _economy = Get.find<EconomyService>();
  final IAnalyticsService _analytics = Get.find<IAnalyticsService>();

  final RxString activeThemeId = 'classic'.obs;
  final List<ThemeModel> allThemes = ThemeRepository.allThemes;

  @override
  void onInit() {
    super.onInit();
    activeThemeId.value = _progress.progress.currentThemeId;
  }

  bool isUnlocked(ThemeModel theme) {
    if (theme.isFree) return true;
    return _progress.progress.levelStars.values.fold(0, (s, v) => s + v) >=
        theme.coinsRequired; // using coins purchased check
  }

  bool canAfford(ThemeModel theme) {
    return _economy.coins.value >= theme.coinsRequired;
  }

  Future<bool> unlockTheme(ThemeModel theme) async {
    if (!_economy.spendCoins(theme.coinsRequired)) return false;
    await selectTheme(theme);
    _analytics.logEvent(AnalyticsEvent.themeUnlocked,
        params: {'themeId': theme.id});
    return true;
  }

  Future<void> selectTheme(ThemeModel theme) async {
    activeThemeId.value = theme.id;
    await _progress.updateTheme(theme.id);
  }
}
