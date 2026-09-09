import 'package:flutter_test/flutter_test.dart';
import 'package:arrowescapegame/core/constants/app_constants.dart';
import 'package:arrowescapegame/data/models/player_progress.dart';
import 'package:arrowescapegame/services/economy_service.dart';
import 'package:arrowescapegame/services/storage_service.dart';

class FakeStorageService extends StorageService {
  PlayerProgress _mockProgress = PlayerProgress(coins: 100, hints: 3);

  @override
  PlayerProgress get progress => _mockProgress;

  @override
  Future<void> saveProgress(PlayerProgress p) async {
    _mockProgress = p;
  }
}

void main() {
  group('EconomyService Tests', () {
    late FakeStorageService fakeStorage;
    late EconomyService economy;

    setUp(() {
      fakeStorage = FakeStorageService();
      economy = EconomyService(fakeStorage);
      economy.onInit();
    });

    test('Initializes coins and hints from storage', () {
      expect(economy.coins.value, equals(100));
      expect(economy.hints.value, equals(3));
      expect(economy.hasHints, isTrue);
      expect(economy.canAfford, isTrue);
    });

    test('Adding coins increases balance and clamps to 999999', () {
      economy.addCoins(50);
      expect(economy.coins.value, equals(150));
      expect(fakeStorage.progress.coins, equals(150));

      economy.addCoins(2000000);
      expect(economy.coins.value, equals(999999));
    });

    test('Spending coins succeeds when sufficient, fails when insufficient', () {
      expect(economy.spendCoins(40), isTrue);
      expect(economy.coins.value, equals(60));

      expect(economy.spendCoins(100), isFalse);
      expect(economy.coins.value, equals(60));
    });

    test('Award level complete calculates 3-star bonus correctly', () {
      final initialCoins = economy.coins.value;
      economy.awardLevelComplete(stars: 3);
      final expectedReward = AppConstants.coinsPerLevelComplete + AppConstants.coinsFor3Stars;
      expect(economy.coins.value, equals(initialCoins + expectedReward));
    });

    test('Using hint decreases hint count', () {
      expect(economy.useHint(), isTrue);
      expect(economy.hints.value, equals(2));

      economy.useHint();
      economy.useHint();
      expect(economy.hints.value, equals(0));
      expect(economy.useHint(), isFalse);
    });

    test('Buying hint spends coins and increments hints', () {
      final initialCoins = economy.coins.value;
      final initialHints = economy.hints.value;

      final success = economy.buyHint();
      expect(success, isTrue);
      expect(economy.coins.value, equals(initialCoins - AppConstants.coinsHintCost));
      expect(economy.hints.value, equals(initialHints + 1));
    });
  });
}
