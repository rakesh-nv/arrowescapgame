/// Plain-Dart mirror of Google Play's AppUpdateInfo / InstallState, plus the
/// rules that decide how to offer an update. No Flutter or platform imports,
/// so it is unit-testable.
library;

/// Play's UpdateAvailability.
enum UpdateAvailability {
  unknown,
  notAvailable,
  available,

  /// An update flow the app started is still running (for example, an
  /// immediate update the player left by switching apps).
  inProgress;

  static UpdateAvailability fromCode(int? code) => switch (code) {
        1 => notAvailable,
        2 => available,
        3 => inProgress,
        _ => unknown,
      };
}

/// Play's InstallStatus.
enum InstallStatus {
  unknown,
  pending,
  downloading,
  downloaded,
  installing,
  installed,
  failed,
  canceled;

  static InstallStatus fromCode(int? code) => switch (code) {
        1 => pending,
        2 => downloading,
        3 => installing,
        4 => installed,
        5 => failed,
        6 => canceled,
        11 => downloaded,
        _ => unknown,
      };
}

enum UpdateType { flexible, immediate }

/// What the Play update dialog reported.
enum UpdateFlowResult { accepted, canceled, failed }

class AppUpdateInfoData {
  final UpdateAvailability availability;
  final InstallStatus installStatus;
  final int availableVersionCode;

  /// 0–5, set per release through the Play Developer API (0 by default).
  final int priority;

  /// Days since Play learned of the update; null when unknown.
  final int? stalenessDays;
  final bool immediateAllowed;
  final bool flexibleAllowed;
  final int bytesDownloaded;
  final int totalBytesToDownload;
  final String? packageName;

  const AppUpdateInfoData({
    required this.availability,
    this.installStatus = InstallStatus.unknown,
    this.availableVersionCode = 0,
    this.priority = 0,
    this.stalenessDays,
    this.immediateAllowed = false,
    this.flexibleAllowed = false,
    this.bytesDownloaded = 0,
    this.totalBytesToDownload = 0,
    this.packageName,
  });

  factory AppUpdateInfoData.fromMap(Map<dynamic, dynamic> map) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    return AppUpdateInfoData(
      availability: UpdateAvailability.fromCode(asInt(map['updateAvailability'])),
      installStatus: InstallStatus.fromCode(asInt(map['installStatus'])),
      availableVersionCode: asInt(map['availableVersionCode']),
      priority: asInt(map['updatePriority']).clamp(0, 5),
      stalenessDays: map['clientVersionStalenessDays'] is num
          ? (map['clientVersionStalenessDays'] as num).toInt()
          : null,
      immediateAllowed: map['immediateAllowed'] == true,
      flexibleAllowed: map['flexibleAllowed'] == true,
      bytesDownloaded: asInt(map['bytesDownloaded']),
      totalBytesToDownload: asInt(map['totalBytesToDownload']),
      packageName: map['packageName'] as String?,
    );
  }
}

class InstallStateData {
  final InstallStatus status;
  final int bytesDownloaded;
  final int totalBytesToDownload;
  final int errorCode;

  const InstallStateData({
    required this.status,
    this.bytesDownloaded = 0,
    this.totalBytesToDownload = 0,
    this.errorCode = 0,
  });

  factory InstallStateData.fromMap(Map<dynamic, dynamic> map) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    return InstallStateData(
      status: InstallStatus.fromCode(asInt(map['installStatus'])),
      bytesDownloaded: asInt(map['bytesDownloaded']),
      totalBytesToDownload: asInt(map['totalBytesToDownload']),
      errorCode: asInt(map['installErrorCode']),
    );
  }

  /// 0–1, or null while the size is unknown.
  double? get progress => totalBytesToDownload > 0
      ? (bytesDownloaded / totalBytesToDownload).clamp(0.0, 1.0)
      : null;
}

/// How an available update should be offered.
class UpdateDecision {
  final UpdateType type;

  /// True when the player must update before continuing.
  final bool required;

  const UpdateDecision({required this.type, required this.required});
}

class UpdatePolicy {
  UpdatePolicy._();

  /// Play priority from which an update is required (immediate flow).
  static const int requiredPriority = 4;

  /// Priority 3 updates become required once this old.
  static const int requiredAfterDaysAtPriority3 = 14;

  /// How long "Later" silences the automatic prompt for one version.
  static const Duration snoozeDuration = Duration(days: 3);

  /// Picks the flow for [info], or null when nothing can be offered. Uses
  /// only what Play reports; never assumes an update exists.
  static UpdateDecision? decide(AppUpdateInfoData info) {
    if (info.availability != UpdateAvailability.available) return null;
    final stale = info.stalenessDays ?? 0;
    final urgent = info.priority >= requiredPriority ||
        (info.priority >= 3 && stale >= requiredAfterDaysAtPriority3);
    if (urgent && info.immediateAllowed) {
      return const UpdateDecision(type: UpdateType.immediate, required: true);
    }
    if (info.flexibleAllowed) {
      return const UpdateDecision(type: UpdateType.flexible, required: false);
    }
    if (info.immediateAllowed) {
      return const UpdateDecision(type: UpdateType.immediate, required: false);
    }
    return null;
  }

  /// Whether to show the automatic (unrequested) optional prompt.
  static bool shouldAutoPrompt({
    required UpdateDecision decision,
    required int versionCode,
    required bool promptedThisSession,
    int? snoozedVersionCode,
    DateTime? snoozedAt,
    required DateTime now,
  }) {
    if (decision.required) return true;
    if (promptedThisSession) return false;
    if (snoozedVersionCode == versionCode && snoozedAt != null) {
      return now.difference(snoozedAt) >= snoozeDuration;
    }
    return true;
  }
}

/// Play Store listing for [packageName].
Uri playStoreUri(String packageName) => Uri.https(
      'play.google.com',
      '/store/apps/details',
      {'id': packageName},
    );
