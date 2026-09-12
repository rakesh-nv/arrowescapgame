import 'dart:io';

/// Centralized configuration for Google Mobile Ads (AdMob).
///
/// Toggle [isTestMode] to `false` when preparing for production Play Store release.
class AdsConfig {
  /// Toggle test mode vs production IDs.
  static const bool isTestMode = true;

  // ── Android Test IDs ──────────────────────────────────────────────────────
  static const String _androidBannerTestId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _androidInterstitialTestId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _androidRewardedTestId =
      'ca-app-pub-3940256099942544/5224354917';

  // ── Android Production IDs (Replace with your actual AdMob IDs) ────────────
  static const String _androidBannerProdId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _androidInterstitialProdId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _androidRewardedProdId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';

  // ── iOS Test IDs ──────────────────────────────────────────────────────────
  static const String _iosBannerTestId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _iosInterstitialTestId =
      'ca-app-pub-3940256099942544/4486956876';
  static const String _iosRewardedTestId =
      'ca-app-pub-3940256099942544/1712485613';

  // ── iOS Production IDs (Replace with your actual AdMob IDs) ───────────────
  static const String _iosBannerProdId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _iosInterstitialProdId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _iosRewardedProdId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';

  // ── Resolved Unit IDs based on Platform and Test Mode ────────────────────

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return isTestMode ? _androidBannerTestId : _androidBannerProdId;
    } else if (Platform.isIOS) {
      return isTestMode ? _iosBannerTestId : _iosBannerProdId;
    }
    return _androidBannerTestId;
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return isTestMode ? _androidInterstitialTestId : _androidInterstitialProdId;
    } else if (Platform.isIOS) {
      return isTestMode ? _iosInterstitialTestId : _iosInterstitialProdId;
    }
    return _androidInterstitialTestId;
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return isTestMode ? _androidRewardedTestId : _androidRewardedProdId;
    } else if (Platform.isIOS) {
      return isTestMode ? _iosRewardedTestId : _iosRewardedProdId;
    }
    return _androidRewardedTestId;
  }
}
