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
  final RxList<String> unlockedThemeIds = <String>[].obs;
  final List<ThemeModel> allThemes = ThemeRepository.allThemes;

  @override
  void onInit() {
    super.onInit();
    activeThemeId.value = _progress.progress.currentThemeId;
    final unlocked = List<String>.from(_progress.progress.unlockedThemes);
    if (!unlocked.contains('classic')) unlocked.add('classic');
    if (!unlocked.contains('ocean')) unlocked.add('ocean');
    if (!unlocked.contains(activeThemeId.value)) {
      unlocked.add(activeThemeId.value);
    }
    unlockedThemeIds.assignAll(unlocked);
  }

  bool isUnlocked(ThemeModel theme) {
    if (theme.isFree) return true;
    if (theme.id == activeThemeId.value) return true;
    return unlockedThemeIds.contains(theme.id);
  }

  bool canAfford(ThemeModel theme) {
    return _economy.coins.value >= theme.coinsRequired;
  }

  Future<bool> unlockTheme(ThemeModel theme) async {
    if (!_economy.spendCoins(theme.coinsRequired)) return false;
    if (!unlockedThemeIds.contains(theme.id)) {
      unlockedThemeIds.add(theme.id);
    }
    await _progress.unlockTheme(theme.id);
    activeThemeId.value = theme.id;
    _analytics.logEvent(AnalyticsEvent.themeUnlocked,
        params: {'themeId': theme.id});
    return true;
  }

  Future<void> selectTheme(ThemeModel theme) async {
    activeThemeId.value = theme.id;
    if (!unlockedThemeIds.contains(theme.id)) {
      unlockedThemeIds.add(theme.id);
    }
    await _progress.updateTheme(theme.id);
  }
}
