import 'package:get/get.dart';
import '../../data/models/theme_model.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/theme_repository.dart';
import '../../services/economy_service.dart';
import '../../services/analytics_service.dart';

enum ThemeUnlockResult {
  /// Coins were deducted once and the theme is now owned and applied.
  unlocked,

  /// Already owned: no coins taken; the theme was applied.
  alreadyOwned,

  /// Balance too low: nothing changed.
  insufficientCoins,

  /// Another purchase is still being processed: nothing changed.
  busy,
}

class ThemesController extends GetxController {
  final ProgressRepository _progress = Get.find<ProgressRepository>();
  final EconomyService _economy = Get.find<EconomyService>();
  final IAnalyticsService _analytics = Get.find<IAnalyticsService>();

  final RxString activeThemeId = ThemeRepository.defaultThemeId.obs;
  final RxList<String> unlockedThemeIds = <String>[].obs;
  final RxBool isPurchasing = false.obs;
  final List<ThemeModel> allThemes = ThemeRepository.allThemes;

  RxInt get coins => _economy.coins;

  @override
  void onInit() {
    super.onInit();
    final p = _progress.progress;
    // A stored id from a theme that no longer exists falls back to default.
    activeThemeId.value = ThemeRepository.exists(p.currentThemeId)
        ? p.currentThemeId
        : ThemeRepository.defaultThemeId;
    final unlocked = List<String>.from(p.unlockedThemes);
    for (final t in allThemes.where((t) => t.isFree)) {
      if (!unlocked.contains(t.id)) unlocked.add(t.id);
    }
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

  bool isActive(ThemeModel theme) => theme.id == activeThemeId.value;

  bool canAfford(ThemeModel theme) {
    return _economy.coins.value >= theme.coinsRequired;
  }

  /// Coins still missing to unlock [theme] (0 when affordable).
  int coinsShort(ThemeModel theme) {
    final short = theme.coinsRequired - _economy.coins.value;
    return short > 0 ? short : 0;
  }

  int get ownedCount => allThemes.where(isUnlocked).length;

  /// Buys [theme] and applies it. Coins are deducted at most once: an owned
  /// theme, a short balance or a purchase already in flight changes nothing.
  Future<ThemeUnlockResult> unlockTheme(ThemeModel theme) async {
    if (isPurchasing.value) return ThemeUnlockResult.busy;
    if (isUnlocked(theme)) {
      await selectTheme(theme);
      return ThemeUnlockResult.alreadyOwned;
    }
    if (!canAfford(theme)) return ThemeUnlockResult.insufficientCoins;

    isPurchasing.value = true;
    try {
      if (!_economy.spendCoins(theme.coinsRequired)) {
        return ThemeUnlockResult.insufficientCoins;
      }
      unlockedThemeIds.add(theme.id);
      activeThemeId.value = theme.id;
      await _progress.unlockTheme(theme.id);
      _analytics.logEvent(AnalyticsEvent.themeUnlocked,
          params: {'themeId': theme.id, 'price': theme.coinsRequired});
      return ThemeUnlockResult.unlocked;
    } finally {
      isPurchasing.value = false;
    }
  }

  /// Applies an owned theme. Returns false (and changes nothing) for a theme
  /// that has not been unlocked.
  Future<bool> selectTheme(ThemeModel theme) async {
    if (!isUnlocked(theme)) return false;
    activeThemeId.value = theme.id;
    if (!unlockedThemeIds.contains(theme.id)) {
      unlockedThemeIds.add(theme.id);
    }
    await _progress.updateTheme(theme.id);
    return true;
  }
}
