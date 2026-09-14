import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/ads_config.dart';
import '../core/constants/app_constants.dart';
import '../data/models/game_settings.dart';
import '../data/models/player_progress.dart';
import '../data/repositories/level_repository.dart';
import '../data/repositories/progress_repository.dart';
import 'ad_service.dart';
import 'admob_service.dart';
import 'analytics_service.dart';
import 'audio_service.dart';
import 'economy_service.dart';
import 'haptic_service.dart';
import 'purchase_service.dart';
import 'storage_service.dart';

enum InitStep {
  starting,
  storage,
  progress,
  audio,
  ads,
  levelSystem,
  complete,
  error,
}

class InitializationProgress {
  final double progress; // 0.0 to 1.0
  final String statusText;
  final InitStep step;
  final String? errorMessage;

  const InitializationProgress({
    required this.progress,
    required this.statusText,
    required this.step,
    this.errorMessage,
  });
}

/// Centralized service managing initialization of storage, services, audio, ads, and first level preparation.
class AppInitializationService {
  AppInitializationService._();

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  @visibleForTesting
  static void resetForTesting() {
    _isInitialized = false;
  }

  /// Executes all initialization steps sequentially with status updates.
  static Future<bool> initialize({
    required void Function(InitializationProgress progress) onProgress,
  }) async {
    if (_isInitialized) {
      onProgress(
        const InitializationProgress(
          progress: 1.0,
          statusText: 'Ready!',
          step: InitStep.complete,
        ),
      );
      return true;
    }

    try {
      // 1. Storage & Database Initialization (Critical)
      onProgress(
        const InitializationProgress(
          progress: 0.15,
          statusText: 'Loading local storage...',
          step: InitStep.storage,
        ),
      );
      final storageService = await initializeStorage();

      // 2. Player Progress, Settings & Economy Repositories (Critical)
      onProgress(
        const InitializationProgress(
          progress: 0.35,
          statusText: 'Loading player progress...',
          step: InitStep.progress,
        ),
      );
      final (progressRepo, _, hapticService) =
          await initializeGameData(storageService);

      // 3. Audio System Initialization (Non-critical)
      onProgress(
        const InitializationProgress(
          progress: 0.55,
          statusText: 'Initializing audio...',
          step: InitStep.audio,
        ),
      );
      await initializeAudio(storageService, hapticService);

      // 4. Ads, Analytics & Purchase Services (Non-critical)
      onProgress(
        const InitializationProgress(
          progress: 0.70,
          statusText: 'Preparing services...',
          step: InitStep.ads,
        ),
      );
      await initializeAds();

      // 5. Level System & Initial Level Preparation (Critical/Core)
      onProgress(
        const InitializationProgress(
          progress: 0.88,
          statusText: 'Preparing first level...',
          step: InitStep.levelSystem,
        ),
      );
      await initializeLevelSystem();
      await prepareInitialLevel(progressRepo);

      _isInitialized = true;
      onProgress(
        const InitializationProgress(
          progress: 1.0,
          statusText: 'Ready!',
          step: InitStep.complete,
        ),
      );

      return true;
    } catch (e, stack) {
      if (kDebugMode) {
        print('Critical Initialization Error: $e\n$stack');
      }
      onProgress(
        InitializationProgress(
          progress: 0.0,
          statusText: 'Unable to initialize game',
          step: InitStep.error,
          errorMessage: e.toString(),
        ),
      );
      return false;
    }
  }

  static Future<StorageService> initializeStorage() async {
    try {
      await Hive.initFlutter();
    } catch (_) {
      // Safe fallback for unit tests or already-initialized Hive
    }
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PlayerProgressAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(GameSettingsAdapter());
    }

    final storageService = StorageService();
    await storageService.init();
    if (!Get.isRegistered<StorageService>()) {
      Get.put<StorageService>(storageService, permanent: true);
    }
    return storageService;
  }

  static Future<(ProgressRepository, EconomyService, HapticService)>
      initializeGameData(StorageService storageService) async {
    final progressRepo = ProgressRepository(storageService);
    if (!Get.isRegistered<ProgressRepository>()) {
      Get.put<ProgressRepository>(progressRepo, permanent: true);
    }

    final economyService = EconomyService(storageService);
    if (!Get.isRegistered<EconomyService>()) {
      Get.put<EconomyService>(economyService, permanent: true);
    }

    final hapticService = HapticService();
    if (!Get.isRegistered<HapticService>()) {
      Get.put<HapticService>(hapticService, permanent: true);
    }

    return (progressRepo, economyService, hapticService);
  }

  static Future<void> initializeAudio(
    StorageService storageService,
    HapticService hapticService,
  ) async {
    IAudioService audioService;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        audioService = NoOpAudioService();
      } else {
        final realService = AudioPlayersService();
        await realService.init();
        audioService = realService;
      }
      final settings = storageService.settings;
      audioService.setEnabled(settings.soundOn);
      audioService.setMusicEnabled(settings.musicOn);
      hapticService.setEnabled(settings.hapticsOn);
    } catch (e) {
      if (kDebugMode) {
        print('Audio initialization warning (fallback to NoOp): $e');
      }
      audioService = NoOpAudioService();
    }

    if (!Get.isRegistered<IAudioService>()) {
      Get.put<IAudioService>(audioService, permanent: true);
    }
  }

  static Future<void> initializeAds() async {
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
        print('AdService initialization warning (fallback to NoOp): $e');
      }
      adService = NoOpAdService();
    }

    if (!Get.isRegistered<IAdService>()) {
      Get.put<IAdService>(adService, permanent: true);
    }

    if (!Get.isRegistered<IAnalyticsService>()) {
      Get.put<IAnalyticsService>(DebugAnalyticsService(), permanent: true);
    }
  }

  static Future<void> initializeLevelSystem() async {
    // Level generation system and seed system readiness
  }

  static Future<void> prepareInitialLevel(
    ProgressRepository progressRepo,
  ) async {
    final currentLvl = progressRepo.progress.highestUnlockedLevel.clamp(
      1,
      AppConstants.totalLevels,
    );
    LevelRepository.getLevel(currentLvl);
  }
}
