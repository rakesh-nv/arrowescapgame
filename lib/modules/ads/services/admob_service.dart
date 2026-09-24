import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../services/purchase_service.dart';
import '../config/ads_config.dart';
import 'ad_service.dart';

/// Concrete AdMob implementation of [IAdService] using exclusively real production ads.
///
/// Manages real AdMob initialization, banner widget creation, preloading,
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
      if (adsEnabled) {
        _preloadInterstitial();
        _preloadRewarded();
      }
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
            debugPrint('[ADS] Real interstitial ad loaded successfully');
          }
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialLoading = false;
          if (kDebugMode) {
            debugPrint('[ADS] Real interstitial failed to load: ${error.message}');
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

    // Guard: Enforce minimum cooldown between interstitials
    final now = DateTime.now();
    if (_lastInterstitialTime != null &&
        now.difference(_lastInterstitialTime!) < _interstitialCooldown) {
      if (kDebugMode) {
        debugPrint('[ADS] Interstitial skipped: on cooldown');
      }
      return;
    }

    if (_interstitialAd == null) {
      if (kDebugMode) {
        debugPrint('[ADS] Real interstitial requested but not ready');
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
          debugPrint('[ADS] Real interstitial shown');
        }
      },
      onAdDismissedFullScreenContent: (ad) {
        if (kDebugMode) {
          debugPrint('[ADS] Real interstitial dismissed');
        }
        ad.dispose();
        _preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        if (kDebugMode) {
          debugPrint('[ADS] Real interstitial failed to show: ${error.message}');
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
            debugPrint('[ADS] Real rewarded ad loaded successfully');
          }
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedLoading = false;
          if (kDebugMode) {
            debugPrint('[ADS] Real rewarded ad failed to load: ${error.message} (Code: ${error.code})');
          }
        },
      ),
    );
  }

  /// Loads real rewarded ad on-demand if not preloaded and waits for it
  Future<bool> _loadRewardedOnDemand() async {
    if (_rewardedAd != null) return true;
    _isRewardedLoading = true;
    final completer = Completer<bool>();

    RewardedAd.load(
      adUnitId: AdsConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          if (kDebugMode) {
            debugPrint('[ADS] Real rewarded ad loaded on-demand');
          }
          if (!completer.isCompleted) completer.complete(true);
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedLoading = false;
          if (kDebugMode) {
            debugPrint('[ADS] Real rewarded ad failed on-demand: ${error.message} (Code: ${error.code})');
          }
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _isRewardedLoading = false;
        return false;
      },
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
        debugPrint('[ADS] Real rewarded ad not ready for $rewardType, loading now...');
      }
      final loaded = await _loadRewardedOnDemand();
      if (!loaded || _rewardedAd == null) {
        if (kDebugMode) {
          debugPrint('[ADS] Failed to load real rewarded ad for $rewardType');
        }
        return false;
      }
    }

    final ad = _rewardedAd!;
    _rewardedAd = null;
    bool userEarnedReward = false;

    // Completer resolves AFTER the ad is fully dismissed, carrying the reward flag.
    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (kDebugMode) {
          debugPrint('[ADS] Real rewarded ad shown for $rewardType');
        }
      },
      onAdDismissedFullScreenContent: (ad) {
        if (kDebugMode) {
          debugPrint('[ADS] Real rewarded ad dismissed (earned: $userEarnedReward)');
        }
        ad.dispose();
        _preloadRewarded();
        if (!completer.isCompleted) completer.complete(userEarnedReward);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        if (kDebugMode) {
          debugPrint('[ADS] Real rewarded ad failed to show: ${error.message}');
        }
        ad.dispose();
        _preloadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          userEarnedReward = true;
          if (kDebugMode) {
            debugPrint('[ADS] User earned real reward: ${reward.amount} ${reward.type} for $rewardType');
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ADS] Exception showing real rewarded ad: $e');
      }
      _preloadRewarded();
      return false;
    }

    return completer.future;
  }
}
