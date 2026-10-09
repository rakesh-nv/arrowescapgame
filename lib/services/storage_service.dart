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

  static const String _genVersionKey = 'genVersion';

  /// Reads a saved puzzle. A save made by another level-generator version
  /// refers to a different board, so it is discarded instead of restored.
  Map<String, dynamic>? _readSave(String key) {
    final useBox = _savedGameBox != null && _savedGameBox!.isOpen;
    final raw = useBox ? _savedGameBox!.get(key) : _inMemorySavedGames[key];
    if (raw == null) return null;
    final data = Map<String, dynamic>.from(raw as Map);
    if (data[_genVersionKey] != AppConstants.levelGeneratorVersion) {
      if (useBox) {
        _savedGameBox!.delete(key);
      } else {
        _inMemorySavedGames.remove(key);
      }
      return null;
    }
    return data;
  }

  /// Retrieves the saved in-progress puzzle state for [levelNumber] if one exists.
  Map<String, dynamic>? getSavedGame(int levelNumber) =>
      _readSave('level_$levelNumber');

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
      _genVersionKey: AppConstants.levelGeneratorVersion,
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

  // ── Daily Challenge Puzzle State ──────────────────────────────────────────
  // Kept apart from campaign saves: keyed by date, and never touches
  // 'last_active_level', so a daily run cannot appear as a campaign level.

  static const String _dailyKeyPrefix = 'daily_';

  /// Retrieves the saved in-progress daily challenge for [dateKey] ('YYYY-MM-DD').
  Map<String, dynamic>? getDailySavedGame(String dateKey) =>
      _readSave('$_dailyKeyPrefix$dateKey');

  /// Saves the in-progress daily challenge for [dateKey], replacing any saved
  /// daily from another date (that board can never be played again).
  Future<void> saveDailyGame({
    required String dateKey,
    required List<String> removedArrowIds,
    required int moves,
    required int mistakes,
    required int lives,
  }) async {
    final key = '$_dailyKeyPrefix$dateKey';
    final data = {
      'dateKey': dateKey,
      'removedArrowIds': List<String>.from(removedArrowIds),
      'moves': moves,
      'mistakes': mistakes,
      'lives': lives,
      'isDaily': true,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      _genVersionKey: AppConstants.levelGeneratorVersion,
    };

    if (_savedGameBox != null && _savedGameBox!.isOpen) {
      final stale = _savedGameBox!.keys
          .where((k) => k is String && k.startsWith(_dailyKeyPrefix) && k != key)
          .toList();
      if (stale.isNotEmpty) await _savedGameBox!.deleteAll(stale);
      await _savedGameBox!.put(key, data);
    } else {
      _inMemorySavedGames.removeWhere(
        (k, _) => k.startsWith(_dailyKeyPrefix) && k != key,
      );
      _inMemorySavedGames[key] = data;
    }
  }

  /// Clears the saved daily challenge for [dateKey] (e.g. on win or reset).
  Future<void> clearDailySavedGame(String dateKey) async {
    final key = '$_dailyKeyPrefix$dateKey';
    if (_savedGameBox != null && _savedGameBox!.isOpen) {
      await _savedGameBox!.delete(key);
    } else {
      _inMemorySavedGames.remove(key);
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
