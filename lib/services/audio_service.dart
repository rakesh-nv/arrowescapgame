import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
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
  void dispose();
}

/// Concrete implementation using [AudioPlayer] from audioplayers package.
/// Reuses player instances to prevent memory leaks and latency during rapid taps.
class AudioPlayersService extends GetxService implements IAudioService {
  bool _soundEnabled = true;
  bool _musicEnabled = true;

  late final AudioPlayer _escapePlayer;
  late final AudioPlayer _blockedPlayer;

  bool get isSoundEnabled => _soundEnabled;
  bool get isMusicEnabled => _musicEnabled;

  AudioPlayersService() {
    _escapePlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
    _blockedPlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
  }

  @override
  void setEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  @override
  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
  }

  @override
  Future<void> playArrowEscape() async {
    if (!_soundEnabled) return;
    try {
      await _escapePlayer.stop();
      await _escapePlayer.play(AssetSource('sounds/arrowsound.m4a'));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AudioService playArrowEscape error: $e');
      }
    }
  }

  @override
  Future<void> playBlocked() async {
    if (!_soundEnabled) return;
    try {
      await _blockedPlayer.stop();
      await _blockedPlayer.play(AssetSource('sounds/universfield-wrong-answer-beep-149895.mp3'));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AudioService playBlocked error: $e');
      }
    }
  }


  @override
  Future<void> playButtonClick() async {}

  @override
  Future<void> playLevelComplete() async {}

  @override
  Future<void> playCoinReward() async {}

  @override
  Future<void> playStarReward() async {}

  @override
  void dispose() {
    _escapePlayer.dispose();
    _blockedPlayer.dispose();
  }


  @override
  void onClose() {
    dispose();
    super.onClose();
  }
}

/// No-op implementation for testing or fallback environments.
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

  @override
  void dispose() {}
}

