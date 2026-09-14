import 'package:flutter_test/flutter_test.dart';
import 'package:arrowescapegame/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IAudioService & NoOpAudioService Tests', () {
    test('NoOpAudioService handles state changes and sound playback without errors', () async {
      final audioService = NoOpAudioService();

      expect(audioService.isSoundEnabled, isTrue);
      expect(audioService.isMusicEnabled, isTrue);

      audioService.setEnabled(false);
      expect(audioService.isSoundEnabled, isFalse);

      audioService.setMusicEnabled(false);
      expect(audioService.isMusicEnabled, isFalse);

      // Verify all methods execute safely without throwing
      await audioService.playArrowEscape();
      await audioService.playBlocked();
      await audioService.playButtonClick();
      await audioService.playLevelComplete();
      await audioService.playCoinReward();
      await audioService.playStarReward();
      audioService.dispose();
    });

    test('Audio constant paths match valid assets format', () {
      expect(AudioPlayersService.arrowSoundAsset, equals('sounds/arrowsound.m4a'));
      expect(
        AudioPlayersService.blockedSoundAsset,
        equals('sounds/universfield-wrong-answer-beep-149895.mp3'),
      );
    });
  });
}
