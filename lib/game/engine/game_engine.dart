import '../../data/models/arrow_model.dart';
import '../../data/models/arrow_state.dart';
import '../../data/models/level_model.dart';
import '../models/tap_result.dart';
import '../solver/level_solver.dart';

/// Snapshot of game state for undo stack
class _GameSnapshot {
  final Map<String, ArrowModel> arrows;
  final int lives;
  final int moves;
  final int mistakes;

  _GameSnapshot({
    required this.arrows,
    required this.lives,
    required this.moves,
    required this.mistakes,
  });
}

/// Core game logic — completely separated from UI/rendering.
///
/// The engine handles:
/// - Loading levels
/// - Validating arrow escape conditions
/// - Processing player taps
/// - Undo/reset
/// - Win detection
/// - Score calculation
class GameEngine {
  LevelModel? _level;
  Map<String, ArrowModel> _arrows = {};
  int _gridSize = 4;

  int _lives = 3;
  int _moves = 0;
  int _mistakes = 0;

  final List<_GameSnapshot> _undoStack = [];
  static const int _maxUndoStack = 50;

  // ── Public getters ────────────────────────────────────────────────────────

  LevelModel? get level => _level;
  int get gridSize => _gridSize;
  int get lives => _lives;
  int get moves => _moves;
  int get mistakes => _mistakes;

  List<ArrowModel> get allArrows => _arrows.values.toList();

  int arrowLength(String arrowId) => _arrows[arrowId]?.length ?? 1;

  List<ArrowModel> get activeArrows => _arrows.values
      .where((a) =>
          a.state != ArrowState.removed && a.state != ArrowState.escaping)
      .toList();

  bool get canUndo => _undoStack.isNotEmpty;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Load a level and reset all state
  void loadLevel(LevelModel level) {
    _level = level;
    _gridSize = level.gridSize;
    _lives = 3;
    _moves = 0;
    _mistakes = 0;
    _undoStack.clear();

    // Deep copy arrows so original level is not mutated
    _arrows = {
      for (final a in level.copyWithFreshArrows().arrows) a.id: a,
    };
  }

  /// Reset the current level to its initial state
  void reset() {
    if (_level != null) loadLevel(_level!);
  }

  // ── Core logic ────────────────────────────────────────────────────────────

  /// Returns true if the given arrow can escape in the current board state
  bool canEscape(String arrowId) {
    final arrow = _arrows[arrowId];
    if (arrow == null) return false;
    if (arrow.state == ArrowState.removed ||
        arrow.state == ArrowState.escaping) {
      return false;
    }

    final active = activeArrows;
    return LevelSolver.canEscape(arrow, active, _gridSize);
  }

  /// Returns all arrows currently able to escape
  List<ArrowModel> getAvailableArrows() {
    return activeArrows
        .where((a) => LevelSolver.canEscape(a, activeArrows, _gridSize))
        .toList();
  }

  /// Returns the remaining (non-removed) arrows count
  int get remainingCount =>
      _arrows.values.where((a) => a.state != ArrowState.removed).length;

  /// Process a player's tap on the given arrow.
  ///
  /// Returns [TapResult.valid] if the arrow can escape and starts the animation.
  /// Returns [TapResult.blocked] if it cannot escape.
  /// Returns [TapResult.ignored] if the arrow does not exist or is already gone.
  TapResult tapArrow(String arrowId) {
    final arrow = _arrows[arrowId];
    if (arrow == null) return TapResult.ignored;
    if (arrow.state == ArrowState.removed ||
        arrow.state == ArrowState.escaping) {
      return TapResult.ignored;
    }

    if (canEscape(arrowId)) {
      // Push undo snapshot before mutating
      _pushUndo();

      // Mark as escaping
      _arrows[arrowId] = arrow.copyWith(state: ArrowState.escaping);
      _moves++;
      return TapResult.valid;
    } else {
      // Mark as blocked temporarily (UI will shake then reset)
      _arrows[arrowId] = arrow.copyWith(state: ArrowState.blocked);
      _mistakes++;
      if (_mistakes > 0 && _mistakes % 3 == 0) {
        // Lose a life every 3 mistakes
        _lives = (_lives - 1).clamp(0, 3);
      }
      return TapResult.blocked;
    }
  }

  /// Called after the escape animation completes — mark arrow as removed
  void markArrowRemoved(String arrowId) {
    final arrow = _arrows[arrowId];
    if (arrow == null) return;
    _arrows[arrowId] = arrow.copyWith(state: ArrowState.removed);
  }

  /// Reset a blocked arrow back to normal (called after shake animation)
  void resetBlockedArrow(String arrowId) {
    final arrow = _arrows[arrowId];
    if (arrow == null) return;
    if (arrow.state == ArrowState.blocked) {
      _arrows[arrowId] = arrow.copyWith(state: ArrowState.normal);
    }
  }

  /// Returns true when all arrows have been removed
  bool isComplete() {
    return _arrows.values
        .every((a) => a.state == ArrowState.removed);
  }

  // ── Undo ──────────────────────────────────────────────────────────────────

  /// Undo the last valid move. Returns true if successful.
  bool undo() {
    if (_undoStack.isEmpty) return false;
    final snapshot = _undoStack.removeLast();
    _arrows = {
      for (final entry in snapshot.arrows.entries) entry.key: entry.value,
    };
    _lives = snapshot.lives;
    _moves = snapshot.moves;
    _mistakes = snapshot.mistakes;
    return true;
  }

  void _pushUndo() {
    if (_undoStack.length >= _maxUndoStack) {
      _undoStack.removeAt(0);
    }
    _undoStack.add(_GameSnapshot(
      arrows: {
        for (final entry in _arrows.entries)
          entry.key: entry.value.copyWith(),
      },
      lives: _lives,
      moves: _moves,
      mistakes: _mistakes,
    ));
  }

  // ── Hint ──────────────────────────────────────────────────────────────────

  /// Returns the ID of a recommended arrow to tap next, or null
  String? getHintArrowId() {
    return LevelSolver.hint(activeArrows, _gridSize);
  }

  // ── Score ─────────────────────────────────────────────────────────────────

  /// Calculate stars based on current performance
  int calculateStars() {
    return _level == null
        ? 1
        : _calculateStarsInternal(
            mistakes: _mistakes,
            moves: _moves,
            moveTarget: _level!.moveTarget,
          );
  }

  static int _calculateStarsInternal({
    required int mistakes,
    required int moves,
    int? moveTarget,
  }) {
    if (mistakes == 0 && (moveTarget == null || moves <= moveTarget)) return 3;
    if (mistakes <= 2) return 2;
    return 1;
  }

  // ── Debug ─────────────────────────────────────────────────────────────────

  /// Force complete the level (debug only)
  void debugComplete() {
    for (final id in _arrows.keys.toList()) {
      _arrows[id] = _arrows[id]!.copyWith(state: ArrowState.removed);
    }
  }
}
