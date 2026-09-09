/// Visual and logical state of an arrow on the board
enum ArrowState {
  /// Default — on board, not highlighted
  normal,

  /// Tapped by player, briefly highlighted before animation starts
  selected,

  /// Tapped but blocked — shows shake + error feedback
  blocked,

  /// Currently animating off the board
  escaping,

  /// Fully removed from board (not rendered)
  removed,
}
