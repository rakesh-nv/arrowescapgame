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
    );
  }
}
