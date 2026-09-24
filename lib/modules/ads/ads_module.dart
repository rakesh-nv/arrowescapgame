import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../services/purchase_service.dart';
import 'config/ads_config.dart';
import 'services/ad_service.dart';
import 'services/admob_service.dart';

export 'config/ads_config.dart';
export 'services/ad_service.dart';
export 'services/admob_service.dart';
export 'widgets/banner_ad_widget.dart';

/// Central entry point and manager for the Ads Module.
///
/// Encapsulates real AdMob ad initialization, provider selection,
/// dependency injection registration, and high-level ad access.
class AdsModule {
  AdsModule._();

  /// Gets the registered [IAdService] instance.
  static IAdService get service => Get.find<IAdService>();

  /// Whether ads are enabled and active on the current device.
  static bool get adsEnabled =>
      Get.isRegistered<IAdService>() && service.adsEnabled;

  /// Initializes the ads module with real AdMob services on supported devices.
  ///
  /// - On supported native devices (Android/iOS): registers [AdMobService].
  /// - In unit-test environments or unsupported platforms: falls back safely to [NoOpAdService].
  static Future<IAdService> initialize() async {
    if (!Get.isRegistered<IPurchaseService>()) {
      Get.put<IPurchaseService>(NoOpPurchaseService(), permanent: true);
    }

    IAdService adService;
    try {
      final nativeSupported = !kIsWeb &&
          (Platform.isAndroid || Platform.isIOS) &&
          await AdsConfig.isSupportedDevice();
      adService = nativeSupported ? AdMobService() : NoOpAdService();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdsModule] Initialization warning (fallback to NoOp): $e');
      }
      adService = NoOpAdService();
    }

    if (!Get.isRegistered<IAdService>()) {
      Get.put<IAdService>(adService, permanent: true);
    }

    return adService;
  }
}
