import 'arrow_model.dart';
import 'difficulty.dart';

/// Immutable level definition used to initialize the game engine
class LevelModel {
  final int levelNumber;
  final int seed;
  final int gridSize;
  final Difficulty difficulty;
  final int arrowCount;
  final int maxMistakes;
  final int? moveTarget;
  final int? timeTargetSeconds;
  final List<ArrowModel> arrows;

  /// Name of the silhouette the arrows form ("Cat", "Bus"…), if any.
  final String? shapeName;

  /// Cells of the silhouette (the picture the arrows fill). The view is
  /// framed on it and grid dots outside it are dimmed; empty when the level
  /// has no silhouette.
  final Set<(int, int)> shapeCells;

  const LevelModel({
    required this.levelNumber,
    required this.seed,
    required this.gridSize,
    required this.difficulty,
    required this.arrowCount,
    required this.maxMistakes,
    this.moveTarget,
    this.timeTargetSeconds,
    required this.arrows,
    this.shapeName,
    this.shapeCells = const {},
  });

  /// Creates a deep copy with fresh arrow instances (so game state is isolated)
  LevelModel copyWithFreshArrows() {
    return LevelModel(
      levelNumber: levelNumber,
      seed: seed,
      gridSize: gridSize,
      difficulty: difficulty,
      arrowCount: arrowCount,
      maxMistakes: maxMistakes,
      moveTarget: moveTarget,
      timeTargetSeconds: timeTargetSeconds,
      arrows: arrows.map((a) => a.copyWith()).toList(),
      shapeName: shapeName,
      shapeCells: shapeCells,
    );
  }
}
