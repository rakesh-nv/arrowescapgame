/// Results of one Google Play immediate-update attempt (see
/// InAppUpdateHandler.kt). No Flutter or platform imports, so it is
/// unit-testable.
library;

enum UpdateOutcome {
  /// Play reports no newer version.
  noUpdate,

  /// A newer version exists but was not started (immediate not allowed by
  /// Play, or the caller asked to only resume an existing flow).
  notAllowed,

  /// An update screen is already open.
  busy,

  /// Play refused to show its update screen.
  notStarted,

  /// The player accepted; Play installs and restarts the app.
  accepted,

  /// The player closed Play's update screen.
  canceled,

  /// Play reported that the update failed.
  failed;

  static UpdateOutcome fromName(Object? name) => switch (name) {
        'noUpdate' => noUpdate,
        'notAllowed' => notAllowed,
        'busy' => busy,
        'notStarted' => notStarted,
        'accepted' => accepted,
        'canceled' => canceled,
        _ => failed,
      };

  /// True when Play's update screen was shown and has now closed.
  bool get flowShown =>
      this == accepted || this == canceled || this == failed;
}

class UpdateAttempt {
  final UpdateOutcome outcome;

  /// True when an interrupted update (DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS)
  /// was resumed rather than a new one started.
  final bool resumed;
  final int availableVersionCode;

  const UpdateAttempt(
    this.outcome, {
    this.resumed = false,
    this.availableVersionCode = 0,
  });

  factory UpdateAttempt.fromMap(Map<dynamic, dynamic> map) => UpdateAttempt(
        UpdateOutcome.fromName(map['outcome']),
        resumed: map['resumed'] == true,
        availableVersionCode: map['availableVersionCode'] is num
            ? (map['availableVersionCode'] as num).toInt()
            : 0,
      );
}
