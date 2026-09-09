/// Result of tapping an arrow
enum TapResult {
  /// Arrow successfully started escaping
  valid,

  /// Arrow is blocked — cannot escape yet
  blocked,

  /// Arrow is already removed or escaping (ignore)
  ignored,
}

/// Result of the solver
class SolveResult {
  final bool solvable;

  /// Ordered list of arrow IDs representing the solution sequence
  final List<String> solution;

  const SolveResult({required this.solvable, required this.solution});

  static const SolveResult unsolvable =
      SolveResult(solvable: false, solution: []);
}
