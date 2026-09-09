import 'package:get/get.dart';
import '../core/constants/app_constants.dart';
import 'storage_service.dart';

/// Central service for all coin and hint economy.
///
/// All coin/hint modifications MUST go through this service.
/// Never scatter economy logic in widgets or controllers.
class EconomyService extends GetxService {
  final StorageService _storage;

  EconomyService(this._storage);

  // Observable state
  final RxInt coins = 0.obs;
  final RxInt hints = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _syncFromStorage();
  }

  void _syncFromStorage() {
    final p = _storage.progress;
    coins.value = p.coins.clamp(0, 999999);
    hints.value = p.hints.clamp(0, 999);
  }

  // ── Coins ─────────────────────────────────────────────────────────────────

  bool get canAfford => coins.value > 0;

  void addCoins(int amount) {
    if (amount <= 0) return;
    coins.value = (coins.value + amount).clamp(0, 999999);
    _persist();
  }

  bool spendCoins(int amount) {
    if (amount <= 0) return true;
    if (coins.value < amount) return false;
    coins.value = coins.value - amount;
    _persist();
    return true;
  }

  void awardLevelComplete({required int stars}) {
    int reward = AppConstants.coinsPerLevelComplete;
    if (stars == 3) reward += AppConstants.coinsFor3Stars;
    addCoins(reward);
  }

  void awardDailyChallenge() {
    addCoins(AppConstants.coinsDailyChallenge);
  }

  // ── Hints ─────────────────────────────────────────────────────────────────

  bool get hasHints => hints.value > 0;

  void addHints(int amount) {
    if (amount <= 0) return;
    hints.value = (hints.value + amount).clamp(0, 999);
    _persist();
  }

  bool useHint() {
    if (!hasHints) return false;
    hints.value--;
    _persist();
    return true;
  }

  bool buyHint() {
    if (!spendCoins(AppConstants.coinsHintCost)) return false;
    addHints(1);
    return true;
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  void _persist() {
    final p = _storage.progress;
    p.coins = coins.value;
    p.hints = hints.value;
    _storage.saveProgress(p);
  }

  /// Reload from storage (e.g., after an external change)
  void refresh() => _syncFromStorage();
}
