/// Direction an arrow points and moves toward
enum ArrowDirection {
  up,
  down,
  left,
  right;

  /// Returns the opposite direction
  ArrowDirection get opposite {
    switch (this) {
      case ArrowDirection.up:
        return ArrowDirection.down;
      case ArrowDirection.down:
        return ArrowDirection.up;
      case ArrowDirection.left:
        return ArrowDirection.right;
      case ArrowDirection.right:
        return ArrowDirection.left;
    }
  }

  /// Row delta when moving in this direction
  int get dRow {
    switch (this) {
      case ArrowDirection.up:
        return -1;
      case ArrowDirection.down:
        return 1;
      case ArrowDirection.left:
        return 0;
      case ArrowDirection.right:
        return 0;
    }
  }

  /// Col delta when moving in this direction
  int get dCol {
    switch (this) {
      case ArrowDirection.up:
        return 0;
      case ArrowDirection.down:
        return 0;
      case ArrowDirection.left:
        return -1;
      case ArrowDirection.right:
        return 1;
    }
  }

  bool get isHorizontal =>
      this == ArrowDirection.left || this == ArrowDirection.right;

  bool get isVertical =>
      this == ArrowDirection.up || this == ArrowDirection.down;
}
