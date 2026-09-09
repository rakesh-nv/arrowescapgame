import 'package:get/get.dart';
import '../../data/models/game_settings.dart';
import '../../data/repositories/progress_repository.dart';
import '../../services/audio_service.dart';
import '../../services/haptic_service.dart';
import '../../services/storage_service.dart';

class SettingsController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final ProgressRepository _progress = Get.find<ProgressRepository>();
  final IAudioService _audio = Get.find<IAudioService>();
  final HapticService _haptic = Get.find<HapticService>();

  late Rx<GameSettings> settings;

  @override
  void onInit() {
    super.onInit();
    settings = _storage.settings.obs;
  }

  void toggleSound() {
    final s = settings.value.copyWith(soundOn: !settings.value.soundOn);
    _apply(s);
  }

  void toggleMusic() {
    final s = settings.value.copyWith(musicOn: !settings.value.musicOn);
    _apply(s);
  }

  void toggleHaptics() {
    final s = settings.value.copyWith(hapticsOn: !settings.value.hapticsOn);
    _apply(s);
  }

  void toggleNotifications() {
    final s = settings.value
        .copyWith(notificationsOn: !settings.value.notificationsOn);
    _apply(s);
  }

  Future<void> resetProgress() async {
    await _progress.resetAllProgress();
    // Re-init progress defaults
    Get.offAllNamed('/');
  }

  void _apply(GameSettings s) {
    settings.value = s;
    _storage.saveSettings(s);
    _audio.setEnabled(s.soundOn);
    _audio.setMusicEnabled(s.musicOn);
    _haptic.setEnabled(s.hapticsOn);
  }
}
