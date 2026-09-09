import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/game_settings.dart';
import '../../data/models/player_progress.dart';

/// Handles all Hive persistence.
/// Opened once at app startup; provides typed getters/setters.
class StorageService {
  late Box<PlayerProgress> _progressBox;
  late Box<GameSettings> _settingsBox;

  static const String _progressKey = 'player';
  static const String _settingsKey = 'settings';

  Future<void> init() async {
    _progressBox = await Hive.openBox<PlayerProgress>(AppConstants.progressBox);
    _settingsBox = await Hive.openBox<GameSettings>(AppConstants.settingsBox);
  }

  // ── Player Progress ───────────────────────────────────────────────────────

  PlayerProgress get progress {
    return _progressBox.get(_progressKey) ?? PlayerProgress();
  }

  Future<void> saveProgress(PlayerProgress p) async {
    await _progressBox.put(_progressKey, p);
  }

  Future<void> clearProgress() async {
    await _progressBox.clear();
  }

  // ── Settings ─────────────────────────────────────────────────────────────

  GameSettings get settings {
    return _settingsBox.get(_settingsKey) ?? GameSettings();
  }

  Future<void> saveSettings(GameSettings s) async {
    await _settingsBox.put(_settingsKey, s);
  }
}
