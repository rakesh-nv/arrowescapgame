import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/arrow_model.dart';
import '../../data/models/arrow_state.dart';
import '../../data/models/daily_challenge.dart';
import '../../data/models/difficulty.dart';
import '../../data/models/level_model.dart';
import '../../data/models/theme_model.dart';
import '../../data/repositories/level_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/theme_repository.dart';
import '../../game/engine/game_engine.dart';
import '../../game/models/tap_result.dart';
import '../../game/solver/level_solver.dart';
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

  /// Whether the how-to-play overlay is showing.
  final RxBool isTutorialLevel = false.obs;
  final RxString hintedArrowId = ''.obs;
  final RxString animatingArrowId = ''.obs;

  /// True while the next board is generated off the UI thread.
  final RxBool isLoadingLevel = false.obs;

  /// The arrow that stopped the last blocked tap, briefly highlighted.
  final RxString blockerArrowId = ''.obs;
  Timer? _blockerTimer;

  /// Increments on every load so a slow, superseded load is dropped.
  int _loadToken = 0;

  /// Short glow given to moves unlocked by the most recent escape.
  final RxSet<String> newlyAvailableArrowIds = <String>{}.obs;

  final Rx<LevelModel?> _level = Rx<LevelModel?>(null);
  final RxInt levelNumber = 1.obs;
  final Rx<ThemeModel> currentTheme = ThemeRepository.getById('classic').obs;

  /// True while playing a daily challenge (loaded via [loadLevelModel]).
  /// Daily runs are saved separately and never touch campaign progress.
  final RxBool isDailyChallenge = false.obs;
  String? _dailyDateKey;

  /// Coins the completion dialog should show for the last win.
  int lastCoinsEarned = 0;

  /// Pending "escape finished" callback; cancelled whenever the board is
  /// replaced (undo, reset, level load, dispose) so it cannot act on stale state.
  Timer? _escapeTimer;

  // ── Analytics ─────────────────────────────────────────────────────────────
  /// Attempts per level in this app run, for `attempt_number`.
  static final Map<String, int> _attemptCounts = {};

  /// The attempt being played; [_attemptOpen] is cleared once it is reported
  /// as completed, failed or quit, so each outcome is logged at most once.
  LevelAnalytics? _attempt;
  bool _attemptOpen = false;
  int _attemptHints = 0;
  int _attemptContinues = 0;

  /// Play time of the attempt; paused in the background and the pause menu.
  final Stopwatch _attemptClock = Stopwatch();
  bool _pauseMenuOpen = false;
  bool _inBackground = false;

  /// One game session = one visit to the gameplay screen.
  final Stopwatch _sessionClock = Stopwatch();
  bool _sessionOpen = false;
  int _sessionLevelsStarted = 0;
  int _sessionLevelsCompleted = 0;

  /// Source of the how-to-play overlay currently showing, if any.
  String? _tutorialSource;

  ThemeModel get theme => currentTheme.value;

  int get gridSize => _engine.gridSize;
  int get currentLevelNumber => levelNumber.value;
  LevelModel? get currentLevel => _level.value;
  Difficulty get difficulty => _level.value?.difficulty ?? Difficulty.easy;

  /// Picture the arrows form ("Cat"), and its outline for the board backdrop.
  String? get shapeName => _level.value?.shapeName;
  Set<(int, int)> get shapeCells => _level.value?.shapeCells ?? const {};

  /// Number of filled hearts to display in the UI (0 to 3).
  /// Players have 4 attempts: 4->3 hearts, 3->2 hearts, 2->1 heart, 1->0 hearts (last chance danger state).
  int get displayHearts => (lives.value - 1).clamp(0, 3);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _syncTheme();
    _ensureStartingHints();
    _sessionOpen = true;
    _sessionClock.start();
    _analytics.gameSessionStart();
  }

  @override
  void onClose() {
    _cancelPendingEscape();
    _blockerTimer?.cancel();
    _endSession();
    super.onClose();
  }

  int get totalArrows => arrows.length;
  int get clearedArrows =>
      arrows.where((a) => a.state == ArrowState.removed).length;

  void _cancelPendingEscape() {
    _escapeTimer?.cancel();
    _escapeTimer = null;
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

  /// Loads campaign level [lvl]. A board that is not cached yet is generated
  /// on a background isolate while [isLoadingLevel] is set.
  Future<void> loadLevel(int lvl) async {
    final token = ++_loadToken;
    _cancelPendingEscape();
    _clearBlocker();
    animatingArrowId.value = '';
    hintedArrowId.value = '';
    isComplete.value = false;
    isCompleting.value = false;
    isGameOver.value = false;
    isDailyChallenge.value = false;
    _dailyDateKey = null;
    levelNumber.value = lvl;
    _syncTheme();
    _ensureStartingHints();

    if (LevelRepository.cachedLevel(lvl) == null) {
      isLoadingLevel.value = true;
      arrows.clear();
      try {
        await LevelRepository.prepareLevels(lvl, requireFirst: true);
      } catch (_) {
        // Falls through to synchronous generation below.
      }
      if (isClosed || token != _loadToken) return;
    }
    isLoadingLevel.value = false;

    final level = LevelRepository.getLevel(lvl);
    _level.value = level;

    var resumed = false;
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
        resumed = true;
      } else {
        _engine.loadLevel(level);
      }
    } else {
      _engine.loadLevel(level);
    }

    _syncState();
    newlyAvailableArrowIds.clear();
    isTutorialLevel.value = lvl == 1 && !_progress.progress.hasSeenTutorial;

    _beginAttempt(resumed: resumed);
    if (isTutorialLevel.value) _beginTutorial('first_level');
  }

  /// Loads a daily challenge board. [dailyDateKey] ('YYYY-MM-DD') identifies
  /// the challenge's date; it defaults to today.
  void loadLevelModel(LevelModel level, {String? dailyDateKey}) {
    _loadToken++;
    isLoadingLevel.value = false;
    _cancelPendingEscape();
    _clearBlocker();
    animatingArrowId.value = '';
    hintedArrowId.value = '';
    isDailyChallenge.value = true;
    _dailyDateKey = dailyDateKey ?? DailyChallenge.todayKey();
    _syncTheme();
    _ensureStartingHints();
    _level.value = level;
    levelNumber.value = level.levelNumber;

    var resumed = false;
    final saved = _storage.getDailySavedGame(_dailyDateKey!);
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
        resumed = true;
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
    _beginAttempt(resumed: resumed);
  }

  /// Saves the current in-progress puzzle state to storage.
  void saveCurrentGame() {
    if (isComplete.value || _level.value == null) return;
    final removed = _engine.removedArrowIds;
    // Don't overwrite if untouched initial state
    if (removed.isEmpty && moves.value == 0 && mistakes.value == 0) return;

    if (isDailyChallenge.value) {
      _storage.saveDailyGame(
        dateKey: _dailyDateKey!,
        removedArrowIds: removed,
        moves: moves.value,
        mistakes: mistakes.value,
        lives: lives.value,
      );
      return;
    }

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
    if (isDailyChallenge.value) {
      _storage.clearDailySavedGame(_dailyDateKey!);
      return;
    }
    _storage.clearSavedGame(currentLevelNumber);
  }

  // ── Player Actions ────────────────────────────────────────────────────────

  void onArrowTap(String arrowId) {
    // A snake animation owns the board until its tail has exited. Starting a
    // second path mid-animation would make occupancy and visual motion diverge.
    if (isComplete.value ||
        isGameOver.value ||
        isLoadingLevel.value ||
        animatingArrowId.value.isNotEmpty ||
        lives.value <= 0) {
      return;
    }

    // Immediately dismiss any active hint when the user taps an arrow
    hintedArrowId.value = '';
    newlyAvailableArrowIds.clear();
    _clearBlocker();

    final arrowLength = _engine.arrowLength(arrowId);
    final result = _engine.tapArrow(arrowId);
    _syncState();

    switch (result) {
      case TapResult.valid:
        _audio.playArrowEscape();
        _haptic.selectionClick();
        animatingArrowId.value = arrowId;

        // After animation duration, mark removed and check win
        _cancelPendingEscape();
        _escapeTimer = Timer(
          Duration(
            milliseconds: AppConstants.arrowEscapeDurationForLength(
              arrowLength,
            ),
          ),
          () {
            _escapeTimer = null;
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
        _haptic.lightTap();
        _showBlocker(arrowId);
        saveCurrentGame();

        if (_engine.lives <= 0) {
          Future.delayed(
            const Duration(
              milliseconds: AppConstants.blockedAnimDurationMs + 100,
            ),
            () {
              if (_engine.lives <= 0 && !isComplete.value) {
                isGameOver.value = true;
                _reportFail();
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
    _clearBlocker();
    _cancelPendingEscape();
    _engine.undo();
    hintedArrowId.value = '';
    animatingArrowId.value = '';
    newlyAvailableArrowIds.clear();
    _syncState();
    saveCurrentGame();
    if (_attempt != null) _analytics.undoUsed(_attempt!);
  }

  bool onHint() {
    if (!_economy.useHint()) return false;

    final hintId = _engine.getHintArrowId();
    if (hintId == null) return false;

    hintedArrowId.value = hintId;
    _attemptHints++;
    if (_attempt != null) _analytics.hintUsed(_attempt!);

    // Clear hint highlight after 2s
    Future.delayed(const Duration(seconds: 2), () {
      if (hintedArrowId.value == hintId) hintedArrowId.value = '';
    });
    return true;
  }

  void onReset() {
    final reason = isGameOver.value
        ? 'retry'
        : (isComplete.value || isCompleting.value)
        ? 'replay'
        : 'restart';
    if (_attempt != null) _analytics.levelRestart(_attempt!, reason: reason);
    // A restart replaces the running attempt; it is not a quit.
    _attemptOpen = false;
    _clearBlocker();
    _cancelPendingEscape();
    clearSavedGame();
    _engine.reset();
    hintedArrowId.value = '';
    animatingArrowId.value = '';
    newlyAvailableArrowIds.clear();
    isComplete.value = false;
    isCompleting.value = false;
    isGameOver.value = false;
    _syncState();
    _beginAttempt(resumed: false);
  }

  /// Campaign "Next Level" from the completion dialog.
  void loadNextLevel() {
    final from = currentLevelNumber;
    _analytics.nextLevel(fromLevel: from);
    loadLevel(from + 1);
  }

  /// Shows a rewarded ad. If the user watches it fully, grants lives and
  /// clears the game-over state so play can resume.
  Future<bool> watchAdContinue() async {
    final granted = await _adService.showRewardedLife();
    if (granted) {
      _engine.restoreLives(AppConstants.startingLives);
      isGameOver.value = false;
      // Play goes on in the same attempt after a continue.
      _attemptContinues++;
      _attemptOpen = _attempt != null;
      _resumeClock();
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

  /// Shows the how-to-play overlay again (pause menu, settings).
  void showTutorial() {
    isTutorialLevel.value = true;
    _beginTutorial('pause_menu');
  }

  /// Closes the how-to-play overlay after its last step.
  void dismissTutorial() {
    final source = _tutorialSource;
    if (source != null) _analytics.tutorialComplete(source: source);
    skipTutorial();
  }

  /// Closes the how-to-play overlay early (no tutorial_complete).
  void skipTutorial() {
    _tutorialSource = null;
    isTutorialLevel.value = false;
    _progress.markTutorialSeen();
  }

  /// Pause menu opened / closed. [resumed] is false when the player left the
  /// menu through another action (restart, how to play, leaving the level).
  void onPauseOpened() {
    _pauseMenuOpen = true;
    _attemptClock.stop();
    if (_attempt != null) _analytics.pauseGame(_attempt!);
  }

  void onPauseClosed({required bool resumed}) {
    _pauseMenuOpen = false;
    _resumeClock();
    if (resumed && _attempt != null) _analytics.resumeGame(_attempt!);
  }

  /// App moved to or from the background while this level is open.
  void onAppLifecycleChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _inBackground = true;
        _attemptClock.stop();
        _sessionClock.stop();
      case AppLifecycleState.resumed:
        _inBackground = false;
        if (_sessionOpen) _sessionClock.start();
        _resumeClock();
      case AppLifecycleState.detached:
        _endSession();
      default:
        break;
    }
  }

  // ── Private ───────────────────────────────────────────────────────────────

  /// Briefly highlights the arrow standing in the tapped arrow's exit lane.
  void _showBlocker(String tappedId) {
    final active = _engine.activeArrows;
    final tapped = active.where((a) => a.id == tappedId).firstOrNull;
    if (tapped == null) return;
    final blocker = LevelSolver.firstBlocker(tapped, active, _engine.gridSize);
    if (blocker == null) return;
    blockerArrowId.value = blocker;
    _blockerTimer?.cancel();
    _blockerTimer = Timer(const Duration(milliseconds: 700), _clearBlocker);
  }

  void _clearBlocker() {
    _blockerTimer?.cancel();
    _blockerTimer = null;
    blockerArrowId.value = '';
  }

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

      if (isDailyChallenge.value) {
        // A daily win never touches campaign stars, unlocks or level coins.
        // DailyChallengeController records the streak and pays the daily
        // reward, once per date.
        final last = _progress.progress.lastDailyCompletedDate;
        final alreadyDone = last != null && last.compareTo(_dailyDateKey!) >= 0;
        lastCoinsEarned = alreadyDone ? 0 : AppConstants.coinsDailyChallenge;
      } else {
        lastCoinsEarned = AppConstants.coinsPerLevelComplete +
            (stars == 3 ? AppConstants.coinsFor3Stars : 0);
        _economy.awardLevelComplete(stars: stars);

        if (_level.value != null) {
          _progress.markLevelCompleted(
            levelNumber: _level.value!.levelNumber,
            stars: stars,
          );
        }
      }

      if (_attemptOpen) {
        _attemptOpen = false;
        _attemptClock.stop();
        _sessionLevelsCompleted++;
        _analytics.levelComplete(_attempt!, _attemptStats(), stars: stars);
      }

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

  // ── Analytics helpers ─────────────────────────────────────────────────────

  /// Starts a new attempt on the loaded board and logs level_start. A still
  /// running attempt that gets replaced is reported as quit first.
  void _beginAttempt({required bool resumed}) {
    _reportQuit();
    final level = _level.value;
    if (level == null) return;
    final daily = isDailyChallenge.value;
    final key = daily ? 'daily_$_dailyDateKey' : 'level_${level.levelNumber}';
    final attempt = (_attemptCounts[key] ?? 0) + 1;
    _attemptCounts[key] = attempt;
    _attempt = LevelAnalytics(
      levelNumber: level.levelNumber,
      gameMode: daily ? GameMode.daily : GameMode.campaign,
      difficulty: level.difficulty.name,
      attemptNumber: attempt,
      dailyDate: daily ? _dailyDateKey : null,
    );
    _attemptOpen = true;
    _attemptHints = 0;
    _attemptContinues = 0;
    _attemptClock
      ..stop()
      ..reset();
    _resumeClock();
    _sessionLevelsStarted++;
    _analytics.levelStart(_attempt!, resumed: resumed);
  }

  void _resumeClock() {
    if (_attemptOpen && !_pauseMenuOpen && !_inBackground) {
      _attemptClock.start();
    }
  }

  LevelStats _attemptStats() => LevelStats(
    moves: _engine.moves,
    mistakes: _engine.mistakes,
    hints: _attemptHints,
    continues: _attemptContinues,
    arrowsCleared: _engine.removedArrowIds.length,
    arrowsTotal: arrows.length,
    seconds: _attemptClock.elapsed.inSeconds,
  );

  void _reportFail() {
    if (!_attemptOpen) return;
    _attemptOpen = false;
    _attemptClock.stop();
    _analytics.levelFail(_attempt!, _attemptStats());
  }

  /// Leaving (or replacing) a level that was neither completed nor failed.
  void _reportQuit() {
    if (!_attemptOpen) return;
    _attemptOpen = false;
    _attemptClock.stop();
    _analytics.levelQuit(_attempt!, _attemptStats());
  }

  void _beginTutorial(String source) {
    if (_tutorialSource != null) return;
    _tutorialSource = source;
    _analytics.tutorialBegin(source: source);
  }

  void _endSession() {
    if (!_sessionOpen) return;
    _reportQuit();
    _sessionOpen = false;
    _sessionClock.stop();
    _analytics.gameSessionEnd(
      durationSeconds: _sessionClock.elapsed.inSeconds,
      levelsStarted: _sessionLevelsStarted,
      levelsCompleted: _sessionLevelsCompleted,
    );
  }

  void markTutorialSeen() => _progress.markTutorialSeen();
}
