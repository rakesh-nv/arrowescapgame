import 'package:get/get.dart';

/// Abstract ad service interface — no ads shown unless configured.
abstract class IAdService {
  Future<void> showInterstitial();
  Future<bool> showRewardedHint();
  Future<bool> showRewardedLife();
  Future<bool> showRewardedCoins();
  bool get adsEnabled;
}

/// No-op implementation for development without AdMob IDs.
class NoOpAdService extends GetxService implements IAdService {
  @override
  bool get adsEnabled => false;

  @override
  Future<void> showInterstitial() async {}

  @override
  Future<bool> showRewardedHint() async => false;

  @override
  Future<bool> showRewardedLife() async => false;

  @override
  Future<bool> showRewardedCoins() async => false;
}
