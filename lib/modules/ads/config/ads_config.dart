import 'dart:io';

/// Centralized configuration for Google Mobile Ads (AdMob).
/// Configured exclusively with real production AdMob Ad Unit IDs.
class AdsConfig {
  static Future<bool> isSupportedDevice() async {
    return true;
  }

  // ── Production Ad Unit IDs ────────────────────────────────────────────────
  static const String _androidBannerProdId =
      'ca-app-pub-3552932543509858/8214251063';
  static const String _androidInterstitialProdId =
      'ca-app-pub-3552932543509858/7211773549';
  static const String _androidRewardedProdId =
      'ca-app-pub-3552932543509858/8333283523';

  static const String _iosBannerProdId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _iosInterstitialProdId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _iosRewardedProdId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';

  // ── Resolved Real Production Unit IDs ─────────────────────────────────────

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return _androidBannerProdId;
    } else if (Platform.isIOS) {
      return _iosBannerProdId;
    }
    return _androidBannerProdId;
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return _androidInterstitialProdId;
    } else if (Platform.isIOS) {
      return _iosInterstitialProdId;
    }
    return _androidInterstitialProdId;
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return _androidRewardedProdId;
    } else if (Platform.isIOS) {
      return _iosRewardedProdId;
    }
    return _androidRewardedProdId;
  }
}
