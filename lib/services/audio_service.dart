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
  static const String arrowSoundAsset = 'sounds/arrowsound.m4a';
  static const String blockedSoundAsset =
      'sounds/universfield-wrong-answer-beep-149895.mp3';

  bool _soundEnabled = true;
  bool _musicEnabled = true;

  // Pool of players for arrow escape sound to handle rapid consecutive taps smoothly
  static const int _escapePoolSize = 3;
  final List<AudioPlayer> _escapePlayers = [];
  int _currentEscapeIndex = 0;

  late final AudioPlayer _blockedPlayer;
  late final AudioPlayer _uiPlayer;

  bool _isInitialized = false;

  bool get isSoundEnabled => _soundEnabled;
  bool get isMusicEnabled => _musicEnabled;

  AudioPlayersService() {
    _initPlayers();
  }

  void _initPlayers() {
    try {
      for (int i = 0; i < _escapePoolSize; i++) {
        _escapePlayers.add(AudioPlayer());
      }
      _blockedPlayer = AudioPlayer();
      _uiPlayer = AudioPlayer();
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AudioPlayersService player creation error: $e');
      }
    }
  }

  Future<void> init() async {
    try {
      // Configure global audio context for games (ambient mode, non-intrusive focus)
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AudioPlayersService global audio context error: $e');
      }
    }
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
    if (!_soundEnabled || !_isInitialized || _escapePlayers.isEmpty) return;
    try {
      final player = _escapePlayers[_currentEscapeIndex];
      _currentEscapeIndex = (_currentEscapeIndex + 1) % _escapePlayers.length;
      await player.stop();
      await player.play(AssetSource(arrowSoundAsset));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AudioService playArrowEscape error: $e');
      }
    }
  }

  @override
  Future<void> playBlocked() async {
    if (!_soundEnabled || !_isInitialized) return;
    try {
      await _blockedPlayer.stop();
      await _blockedPlayer.play(AssetSource(blockedSoundAsset));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AudioService playBlocked error: $e');
      }
    }
  }

  @override
  Future<void> playButtonClick() async {
    if (!_soundEnabled || !_isInitialized) return;
    try {
      await _uiPlayer.stop();
      await _uiPlayer.play(AssetSource(arrowSoundAsset));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AudioService playButtonClick error: $e');
      }
    }
  }

  @override
  Future<void> playLevelComplete() async {}

  @override
  Future<void> playCoinReward() async {}

  @override
  Future<void> playStarReward() async {}

  @override
  void dispose() {
    for (final player in _escapePlayers) {
      try {
        player.dispose();
      } catch (_) {}
    }
    _escapePlayers.clear();
    try {
      _blockedPlayer.dispose();
    } catch (_) {}
    try {
      _uiPlayer.dispose();
    } catch (_) {}
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

