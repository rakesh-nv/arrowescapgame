import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'data/models/game_settings.dart';
import 'data/models/player_progress.dart';
import 'data/repositories/progress_repository.dart';
import 'routes/app_router.dart';
import 'services/ad_service.dart';
import 'services/analytics_service.dart';
import 'services/audio_service.dart';
import 'services/economy_service.dart';
import 'services/haptic_service.dart';
import 'services/purchase_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Force portrait orientation for mobile game UX
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // System UI overlay configuration
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Hive local database and register type adapters
  await Hive.initFlutter();
  Hive.registerAdapter(PlayerProgressAdapter());
  Hive.registerAdapter(GameSettingsAdapter());

  // Initialize and register core storage
  final storageService = StorageService();
  await storageService.init();
  Get.put<StorageService>(storageService, permanent: true);

  // Initialize repositories and services
  final progressRepo = ProgressRepository(storageService);
  Get.put<ProgressRepository>(progressRepo, permanent: true);

  final economyService = EconomyService(storageService);
  Get.put<EconomyService>(economyService, permanent: true);

  final hapticService = HapticService();
  Get.put<HapticService>(hapticService, permanent: true);

  final audioService = NoOpAudioService();
  Get.put<IAudioService>(audioService, permanent: true);

  Get.put<IAdService>(NoOpAdService(), permanent: true);
  Get.put<IAnalyticsService>(DebugAnalyticsService(), permanent: true);
  Get.put<IPurchaseService>(NoOpPurchaseService(), permanent: true);

  // Apply user's saved preferences
  final settings = storageService.settings;
  audioService.setEnabled(settings.soundOn);
  audioService.setMusicEnabled(settings.musicOn);
  hapticService.setEnabled(settings.hapticsOn);

  runApp(const ArrowEscapeApp());
}

class ArrowEscapeApp extends StatelessWidget {
  const ArrowEscapeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      defaultTransition: Transition.fade,
    );
  }
}
