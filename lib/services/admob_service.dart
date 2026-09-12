import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/ads_config.dart';
import 'ad_service.dart';
import 'purchase_service.dart';

/// Concrete AdMob implementation of [IAdService].
///
/// Manages AdMob initialization, banner widget creation, preloading,
/// frequency control, and reward callback tracking.
class AdMobService extends GetxService implements IAdService {
  late final IPurchaseService _purchaseService;

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  bool _isInterstitialLoading = false;
  bool _isRewardedLoading = false;

  int _levelCompletionCount = 0;
  DateTime? _lastInterstitialTime;

  /// Minimum duration required between showing interstitial ads (2 minutes).
  static const Duration _interstitialCooldown = Duration(minutes: 2);

  @override
  bool get adsEnabled => !_purchaseService.removeAdsPurchased;

  @override
  void onInit() {
    super.onInit();
    _purchaseService = Get.find<IPurchaseService>();
    _initAdMob();
  }

  Future<void> _initAdMob() async {
    try {
      await MobileAds.instance.initialize();
      if (kDebugMode) {
        debugPrint('[ADS] AdMob initialized successfully');
      }
      _preloadInterstitial();
      _preloadRewarded();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ADS] AdMob initialization error: $e');
      }
    }
  }

  // ── Interstitial Ad Management ────────────────────────────────────────────

  void _preloadInterstitial() {
    if (!adsEnabled || _interstitialAd != null || _isInterstitialLoading) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: AdsConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          if (kDebugMode) {
            debugPrint('[ADS] Interstitial loaded successfully');
          }
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialLoading = false;
          if (kDebugMode) {
            debugPrint('[ADS] Interstitial failed to load: ${error.message}');
          }
        },
      ),
    );
  }

  @override
  Future<void> showInterstitial() async {
    if (!adsEnabled) {
      if (kDebugMode) {
        debugPrint('[ADS] Interstitial skipped: ads disabled via Remove Ads purchase');
      }
      return;
    }

    _levelCompletionCount++;

    // Guard: Only show every 3 level completions
    if (_levelCompletionCount % 3 != 0) {
      if (kDebugMode) {
        debugPrint('[ADS] Interstitial skipped: level count $_levelCompletionCount (shows every 3 levels)');
      }
      return;
    }

    // Guard: Respect 2-minute cooldown
    final now = DateTime.now();
    if (_lastInterstitialTime != null &&
        now.difference(_lastInterstitialTime!) < _interstitialCooldown) {
      if (kDebugMode) {
        debugPrint('[ADS] Interstitial skipped: 2-minute cooldown active');
      }
      return;
    }

    if (_interstitialAd == null) {
      if (kDebugMode) {
        debugPrint('[ADS] Interstitial requested but not ready');
      }
      _preloadInterstitial();
      return;
    }

    final ad = _interstitialAd!;
    _interstitialAd = null;
    _lastInterstitialTime = now;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (kDebugMode) {
          debugPrint('[ADS] Interstitial shown');
        }
      },
      onAdDismissedFullScreenContent: (ad) {
        if (kDebugMode) {
          debugPrint('[ADS] Interstitial dismissed');
        }
        ad.dispose();
        _preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        if (kDebugMode) {
          debugPrint('[ADS] Interstitial failed to show: ${error.message}');
        }
        ad.dispose();
        _preloadInterstitial();
      },
    );

    try {
      await ad.show();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ADS] Exception showing interstitial: $e');
      }
      _preloadInterstitial();
    }
  }

  // ── Rewarded Ad Management ────────────────────────────────────────────────

  void _preloadRewarded() {
    if (_rewardedAd != null || _isRewardedLoading) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: AdsConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          if (kDebugMode) {
            debugPrint('[ADS] Rewarded ad loaded successfully');
          }
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedLoading = false;
          if (kDebugMode) {
            debugPrint('[ADS] Rewarded ad failed to load: ${error.message}');
          }
        },
      ),
    );
  }

  @override
  Future<bool> showRewardedHint() async {
    return _showRewarded('hint');
  }

  @override
  Future<bool> showRewardedCoins() async {
    return _showRewarded('coins');
  }

  @override
  Future<bool> showRewardedLife() async {
    return _showRewarded('life');
  }

  Future<bool> _showRewarded(String rewardType) async {
    if (_rewardedAd == null) {
      if (kDebugMode) {
        debugPrint('[ADS] Rewarded ad requested for $rewardType but not ready');
      }
      _preloadRewarded();
      return false;
    }

    final ad = _rewardedAd!;
    _rewardedAd = null;
    bool userEarnedReward = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (kDebugMode) {
          debugPrint('[ADS] Rewarded ad shown for $rewardType');
        }
      },
      onAdDismissedFullScreenContent: (ad) {
        if (kDebugMode) {
          debugPrint('[ADS] Rewarded ad dismissed');
        }
        ad.dispose();
        _preloadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        if (kDebugMode) {
          debugPrint('[ADS] Rewarded ad failed to show: ${error.message}');
        }
        ad.dispose();
        _preloadRewarded();
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          userEarnedReward = true;
          if (kDebugMode) {
            debugPrint('[ADS] Reward earned for $rewardType! Amount: ${reward.amount} ${reward.type}');
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ADS] Exception showing rewarded ad: $e');
      }
      _preloadRewarded();
      return false;
    }

    return userEarnedReward;
  }

  @override
  void onClose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    super.onClose();
  }
}
