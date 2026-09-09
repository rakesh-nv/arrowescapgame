import 'package:get/get.dart';

/// Abstract audio service interface.
/// Concrete implementations can be swapped (AudioPlayers, no-op, etc.)
abstract class IAudioService {
  Future<void> playButtonClick();
  Future<void> playArrowEscape();
  Future<void> playBlocked();
  Future<void> playLevelComplete();
  Future<void> playCoinReward();
  Future<void> playStarReward();
  void setEnabled(bool enabled);
  void setMusicEnabled(bool enabled);
}

/// No-op implementation — architecture ready for real audio assets.
/// The AudioPlayers package is installed; swap this with RealAudioService
/// once audio assets are available.
class NoOpAudioService extends GetxService implements IAudioService {
  bool _soundEnabled = true;
  bool _musicEnabled = true;

  bool get isSoundEnabled => _soundEnabled;
  bool get isMusicEnabled => _musicEnabled;

  @override
  void setEnabled(bool enabled) => _soundEnabled = enabled;

  @override
  void setMusicEnabled(bool enabled) => _musicEnabled = enabled;

  @override
  Future<void> playButtonClick() async {}

  @override
  Future<void> playArrowEscape() async {}

  @override
  Future<void> playBlocked() async {}

  @override
  Future<void> playLevelComplete() async {}

  @override
  Future<void> playCoinReward() async {}

  @override
  Future<void> playStarReward() async {}
}
