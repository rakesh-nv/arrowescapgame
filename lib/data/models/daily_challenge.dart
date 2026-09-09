/// Represents the daily challenge state
class DailyChallenge {
  final String dateKey; // 'YYYY-MM-DD'
  final int seed;
  final bool completed;
  final int? starsEarned;

  const DailyChallenge({
    required this.dateKey,
    required this.seed,
    this.completed = false,
    this.starsEarned,
  });

  DailyChallenge copyWith({
    bool? completed,
    int? starsEarned,
  }) {
    return DailyChallenge(
      dateKey: dateKey,
      seed: seed,
      completed: completed ?? this.completed,
      starsEarned: starsEarned ?? this.starsEarned,
    );
  }

  /// Generate a deterministic seed from a date string 'YYYY-MM-DD'
  static int seedFromDate(String dateKey) {
    // Simple hash: multiply components to get a stable int
    final parts = dateKey.split('-');
    final year = int.tryParse(parts[0]) ?? 2026;
    final month = int.tryParse(parts[1]) ?? 1;
    final day = int.tryParse(parts[2]) ?? 1;
    return year * 10000 + month * 100 + day;
  }

  static String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
