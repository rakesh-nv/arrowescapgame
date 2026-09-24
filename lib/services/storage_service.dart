import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/game_settings.dart';
import '../../data/models/player_progress.dart';

/// Handles all Hive persistence.
/// Opened once at app startup; provides typed getters/setters and in-progress puzzle saves.
class StorageService {
  late Box<PlayerProgress> _progressBox;
  late Box<GameSettings> _settingsBox;
  Box? _savedGameBox;

  static const String _progressKey = 'player';
  static const String _settingsKey = 'settings';
  static const String _savedGameBoxName = 'saved_game';

  // In-memory fallback for test environments or before Hive box opens
  final Map<String, dynamic> _inMemorySavedGames = {};

  Future<void> init() async {
    _progressBox = await Hive.openBox<PlayerProgress>(AppConstants.progressBox);
    _settingsBox = await Hive.openBox<GameSettings>(AppConstants.settingsBox);
    _savedGameBox = await Hive.openBox(_savedGameBoxName);
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
    await clearAllSavedGames();
  }

  // ── Settings ─────────────────────────────────────────────────────────────

  GameSettings get settings {
    return _settingsBox.get(_settingsKey) ?? GameSettings();
  }

  Future<void> saveSettings(GameSettings s) async {
    await _settingsBox.put(_settingsKey, s);
  }

  // ── In-Progress Puzzle State ──────────────────────────────────────────────

  /// Retrieves the saved in-progress puzzle state for [levelNumber] if one exists.
  Map<String, dynamic>? getSavedGame(int levelNumber) {
    if (_savedGameBox != null && _savedGameBox!.isOpen) {
      final data = _savedGameBox!.get('level_$levelNumber');
      if (data == null) return null;
      return Map<String, dynamic>.from(data as Map);
    }
    final inMem = _inMemorySavedGames['level_$levelNumber'];
    if (inMem == null) return null;
    return Map<String, dynamic>.from(inMem as Map);
  }

  /// Saves the current in-progress puzzle state.
  Future<void> saveGame({
    required int levelNumber,
    required List<String> removedArrowIds,
    required int moves,
    required int mistakes,
    required int lives,
    bool isDaily = false,
  }) async {
    final data = {
      'levelNumber': levelNumber,
      'removedArrowIds': List<String>.from(removedArrowIds),
      'moves': moves,
      'mistakes': mistakes,
      'lives': lives,
      'isDaily': isDaily,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
    };

    if (_savedGameBox != null && _savedGameBox!.isOpen) {
      await _savedGameBox!.put('level_$levelNumber', data);
      await _savedGameBox!.put('last_active_level', levelNumber);
    } else {
      _inMemorySavedGames['level_$levelNumber'] = data;
      _inMemorySavedGames['last_active_level'] = levelNumber;
    }
  }

  /// Clears the saved in-progress state for [levelNumber] (e.g. on win or reset).
  Future<void> clearSavedGame(int levelNumber) async {
    if (_savedGameBox != null && _savedGameBox!.isOpen) {
      await _savedGameBox!.delete('level_$levelNumber');
      final lastActive = _savedGameBox!.get('last_active_level');
      if (lastActive == levelNumber) {
        await _savedGameBox!.delete('last_active_level');
      }
    } else {
      _inMemorySavedGames.remove('level_$levelNumber');
      if (_inMemorySavedGames['last_active_level'] == levelNumber) {
        _inMemorySavedGames.remove('last_active_level');
      }
    }
  }

  /// Returns the level number of the most recently active in-progress puzzle, if any.
  int? getLastActiveLevel() {
    if (_savedGameBox != null && _savedGameBox!.isOpen) {
      return _savedGameBox!.get('last_active_level') as int?;
    }
    return _inMemorySavedGames['last_active_level'] as int?;
  }

  /// Clears all saved game state.
  Future<void> clearAllSavedGames() async {
    if (_savedGameBox != null && _savedGameBox!.isOpen) {
      await _savedGameBox!.clear();
    } else {
      _inMemorySavedGames.clear();
    }
  }
}
