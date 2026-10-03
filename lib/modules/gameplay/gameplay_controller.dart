import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/arrow_model.dart';
import '../../data/models/difficulty.dart';
import '../../data/models/level_model.dart';
import '../../data/models/theme_model.dart';
import '../../data/repositories/level_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/theme_repository.dart';
import '../../game/engine/game_engine.dart';
import '../../game/models/tap_result.dart';
import '../ads/ads_module.dart';
import '../../services/analytics_service.dart';
import '../../services/audio_service.dart';
import '../../services/economy_service.dart';
import '../../services/haptic_service.dart';
import '../../services/storage_service.dart';

class GameplayController extends GetxController {
  final GameEngine _engine = GameEngine();
  final ProgressRepository _progress = Get.find<ProgressRepository>();
  final EconomyService _economy = Get.find<EconomyService>();
  final HapticService _haptic = Get.find<HapticService>();
  final IAudioService _audio = Get.find<IAudioService>();
  final IAnalyticsService _analytics = Get.find<IAnalyticsService>();
  final IAdService _adService = Get.find<IAdService>();
  final StorageService _storage = Get.find<StorageService>();

  // ── Observable state ──────────────────────────────────────────────────────
  final RxList<ArrowModel> arrows = <ArrowModel>[].obs;
  final RxInt lives = AppConstants.startingLives.obs;
  final RxInt moves = 0.obs;
  final RxInt mistakes = 0.obs;
  final RxBool isComplete = false.obs;
  final RxBool isGameOver = false.obs;

  /// Brief reward beat between the final escape and the completion dialog.
  final RxBool isCompleting = false.obs;
  final RxBool isTutorialLevel = false.obs;
  final RxString hintedArrowId = ''.obs;
  final RxString animatingArrowId = ''.obs;

  /// Short glow given to moves unlocked by the most recent escape.
  final RxSet<String> newlyAvailableArrowIds = <String>{}.obs;

  final Rx<LevelModel?> _level = Rx<LevelModel?>(null);
  final RxInt levelNumber = 1.obs;
  final Rx<ThemeModel> currentTheme = ThemeRepository.getById('classic').obs;

  ThemeModel get theme => currentTheme.value;

  int get gridSize => _engine.gridSize;
  int get currentLevelNumber => levelNumber.value;
  LevelModel? get currentLevel => _level.value;
  Difficulty get difficulty => _level.value?.difficulty ?? Difficulty.easy;

  /// Number of filled hearts to display in the UI (0 to 3).
  /// Players have 4 attempts: 4->3 hearts, 3->2 hearts, 2->1 heart, 1->0 hearts (last chance danger state).
  int get displayHearts => (lives.value - 1).clamp(0, 3);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _syncTheme();
    _ensureStartingHints();
  }

  void _ensureStartingHints() {
    if (_economy.hints.value < AppConstants.startingHints) {
      _economy.addHints(AppConstants.startingHints - _economy.hints.value);
    }
  }

  void _syncTheme() {
    currentTheme.value = ThemeRepository.getById(
      _progress.progress.currentThemeId,
    );
  }

  void loadLevel(int lvl) {
    isComplete.value = false;
    isCompleting.value = false;
    isGameOver.value = false;
    _syncTheme();
    _ensureStartingHints();
    final level = LevelRepository.getLevel(lvl);
    _level.value = level;
    levelNumber.value = lvl;

    final saved = _storage.getSavedGame(lvl);
    if (saved != null) {
      final removed = (saved['removedArrowIds'] as List?)?.cast<String>() ?? [];
      final moves = saved['moves'] as int? ?? 0;
      final mistakes = saved['mistakes'] as int? ?? 0;
      final lives = saved['lives'] as int? ?? AppConstants.startingLives;

      if (removed.isNotEmpty && removed.length < level.arrows.length) {
        _engine.restoreLevel(
          level: level,
          removedArrowIds: removed,
          moves: moves,
          mistakes: mistakes,
          lives: lives,
        );
      } else {
        _engine.loadLevel(level);
      }
    } else {
      _engine.loadLevel(level);
    }

    _syncState();
    newlyAvailableArrowIds.clear();
    isTutorialLevel.value = lvl == 1;

    _analytics.logEvent(
      AnalyticsEvent.levelStarted,
      params: {'level': lvl, 'difficulty': level.difficulty.name},
    );
  }

  void loadLevelModel(LevelModel level) {
    _syncTheme();
    _ensureStartingHints();
    _level.value = level;
    levelNumber.value = level.levelNumber;

    final saved = _storage.getSavedGame(level.levelNumber);
    if (saved != null) {
      final removed = (saved['removedArrowIds'] as List?)?.cast<String>() ?? [];
      final moves = saved['moves'] as int? ?? 0;
      final mistakes = saved['mistakes'] as int? ?? 0;
      final lives = saved['lives'] as int? ?? AppConstants.startingLives;

      if (removed.isNotEmpty && removed.length < level.arrows.length) {
        _engine.restoreLevel(
          level: level,
          removedArrowIds: removed,
          moves: moves,
          mistakes: mistakes,
          lives: lives,
        );
      } else {
        _engine.loadLevel(level);
      }
    } else {
      _engine.loadLevel(level);
    }

    _syncState();
    isComplete.value = false;
    isCompleting.value = false;
    isGameOver.value = false;
    newlyAvailableArrowIds.clear();
    isTutorialLevel.value = false;
  }

  /// Saves the current in-progress puzzle state to storage.
  void saveCurrentGame() {
    if (isComplete.value || _level.value == null) return;
    final removed = _engine.removedArrowIds;
    // Don't overwrite if untouched initial state
    if (removed.isEmpty && moves.value == 0 && mistakes.value == 0) return;

    _storage.saveGame(
      levelNumber: currentLevelNumber,
      removedArrowIds: removed,
      moves: moves.value,
      mistakes: mistakes.value,
      lives: lives.value,
    );
  }

  /// Clears the saved state for the current level (on win or reset).
  void clearSavedGame() {
    _storage.clearSavedGame(currentLevelNumber);
  }

  // ── Player Actions ────────────────────────────────────────────────────────

  void onArrowTap(String arrowId) {
    // A snake animation owns the board until its tail has exited. Starting a
    // second path mid-animation would make occupancy and visual motion diverge.
    if (isComplete.value ||
        isGameOver.value ||
        animatingArrowId.value.isNotEmpty ||
        lives.value <= 0)
      return;

    // Immediately dismiss any active hint when the user taps an arrow
    hintedArrowId.value = '';
    newlyAvailableArrowIds.clear();

    final arrowLength = _engine.arrowLength(arrowId);
    final result = _engine.tapArrow(arrowId);
    _syncState();

    switch (result) {
      case TapResult.valid:
        _audio.playArrowEscape();
        animatingArrowId.value = arrowId;
        _analytics.logEvent(
          AnalyticsEvent.arrowTapped,
          params: {'arrowId': arrowId},
        );

        // After animation duration, mark removed and check win
        Future.delayed(
          Duration(
            milliseconds: AppConstants.arrowEscapeDurationForLength(
              arrowLength,
            ),
          ),
          () {
            _engine.markArrowRemoved(arrowId);
            animatingArrowId.value = '';
            hintedArrowId.value = '';
            newlyAvailableArrowIds.clear();
            _syncState();
            if (!_engine.isComplete()) {
              saveCurrentGame();
            }
            _checkWin();
          },
        );
        break;

      case TapResult.blocked:
        _audio.playBlocked();
        _analytics.logEvent(AnalyticsEvent.arrowBlocked);
        _haptic.lightTap();
        saveCurrentGame();

        if (_engine.lives <= 0) {
          Future.delayed(
            const Duration(
              milliseconds: AppConstants.blockedAnimDurationMs + 100,
            ),
            () {
              if (_engine.lives <= 0 && !isComplete.value) {
                isGameOver.value = true;
              }
            },
          );
        }

        // Reset the blocked state after subtle bump animation
        Future.delayed(
          const Duration(milliseconds: AppConstants.blockedAnimDurationMs + 50),
          () {
            _engine.resetBlockedArrow(arrowId);
            _syncState();
          },
        );
        break;

      case TapResult.ignored:
        break;
    }
  }

  void onUndo() {
    if (!_engine.canUndo) return;
    _engine.undo();
    hintedArrowId.value = '';
    animatingArrowId.value = '';
    newlyAvailableArrowIds.clear();
    _syncState();
    saveCurrentGame();
    _analytics.logEvent(AnalyticsEvent.undoUsed);
  }

  bool onHint() {
    if (!_economy.useHint()) return false;

    final hintId = _engine.getHintArrowId();
    if (hintId == null) return false;

    hintedArrowId.value = hintId;
    _analytics.logEvent(AnalyticsEvent.hintUsed);

    // Clear hint highlight after 2s
    Future.delayed(const Duration(seconds: 2), () {
      if (hintedArrowId.value == hintId) hintedArrowId.value = '';
    });
    return true;
  }

  void onReset() {
    clearSavedGame();
    _engine.reset();
    hintedArrowId.value = '';
    animatingArrowId.value = '';
    newlyAvailableArrowIds.clear();
    isComplete.value = false;
    isCompleting.value = false;
    isGameOver.value = false;
    _syncState();
  }

  /// Shows a rewarded ad. If the user watches it fully, grants lives and
  /// clears the game-over state so play can resume.
  Future<bool> watchAdContinue() async {
    final granted = await _adService.showRewardedLife();
    if (granted) {
      _engine.restoreLives(AppConstants.startingLives);
      isGameOver.value = false;
      _syncState();
      _haptic.lightTap();
      saveCurrentGame();
    }
    return granted;
  }

  /// Shows a rewarded ad for a hint. If watched, awards 1 hint to the player.
  Future<bool> watchAdForHint() async {
    final granted = await _adService.showRewardedHint();
    if (granted) {
      _economy.addHints(1);
      _haptic.lightTap();
    }
    return granted;
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _syncState() {
    arrows.value = _engine.allArrows;
    lives.value = _engine.lives;
    moves.value = _engine.moves;
    mistakes.value = _engine.mistakes;
  }

  void _checkWin() {
    if (_engine.isComplete()) {
      clearSavedGame();
      isCompleting.value = true;
      _haptic.heavyTap();

      final stars = _engine.calculateStars();
      _economy.awardLevelComplete(stars: stars);

      if (_level.value != null) {
        _progress.markLevelCompleted(
          levelNumber: _level.value!.levelNumber,
          stars: stars,
        );
      }

      _analytics.logEvent(
        AnalyticsEvent.levelCompleted,
        params: {
          'level': currentLevelNumber,
          'stars': stars,
          'moves': _engine.moves,
        },
      );

      // Let the board glow and the reward travel before the dialog arrives.
      Future.delayed(const Duration(milliseconds: 650), () {
        if (isCompleting.value) {
          isComplete.value = true;
          _adService.showInterstitial();
        }
      });
    }
  }

  int get calculatedStars => _engine.calculateStars();

  void markTutorialSeen() => _progress.markTutorialSeen();
}
