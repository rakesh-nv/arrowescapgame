import 'dart:io';

import 'package:flutter/services.dart';

/// Centralized configuration for Google Mobile Ads (AdMob).
///
/// Toggle [isTestMode] to `false` when preparing for production Play Store release.
class AdsConfig {
  /// Toggle test mode vs production IDs.
  static const bool isTestMode = false;

  /// The currently installed Google Mobile Ads runtime attempts to use the
  /// Display Hash API on Android 11 and older. That framework API was added in
  /// Android 12, and loading an ad on an older device can terminate the app.
  ///
  /// Keep ads off on those devices until the upstream runtime no longer has
  /// this compatibility issue. Gameplay remains fully available through the
  /// app's no-op ad service.
  static const MethodChannel _deviceChannel =
      MethodChannel('com.arrowescape.arrowescapegame/device');

  static Future<bool> isSupportedDevice() async {
    if (!Platform.isAndroid) return true;

    try {
      final sdkInt = await _deviceChannel.invokeMethod<int>('sdkInt');
      return sdkInt != null && sdkInt >= 31;
    } catch (_) {
      // A failure to determine compatibility must never let native ads crash
      // the game, so use the safe no-ad path.
      return false;
    }
  }

  // ── Android Test IDs ──────────────────────────────────────────────────────
  static const String _androidBannerTestId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _androidInterstitialTestId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _androidRewardedTestId = 'ca-app-pub-3940256099942544/5224354917';

  // ── Android Production IDs ────────────────────────────────────────────────
  static const String _androidBannerProdId = 'ca-app-pub-3552932543509858/8214251063';
  static const String _androidInterstitialProdId = 'ca-app-pub-3552932543509858/7211773549';
  static const String _androidRewardedProdId = 'ca-app-pub-3552932543509858/8333283523';

  // ── iOS Test IDs ──────────────────────────────────────────────────────────
  static const String _iosBannerTestId = 'ca-app-pub-3940256099942544/2934735716';
  static const String _iosInterstitialTestId = 'ca-app-pub-3940256099942544/4486956876';
  static const String _iosRewardedTestId = 'ca-app-pub-3940256099942544/1712485613';

  // ── iOS Production IDs (Replace with your actual AdMob IDs) ───────────────
  static const String _iosBannerProdId = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _iosInterstitialProdId = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _iosRewardedProdId = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';

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
      return isTestMode
          ? _androidInterstitialTestId
          : _androidInterstitialProdId;
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
