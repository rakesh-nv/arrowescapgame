import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../storage_service.dart';
import 'app_update_models.dart';
import 'update_platform.dart';

enum UpdateStatus {
  /// Not checked yet this session.
  idle,
  checking,
  upToDate,

  /// Play reports an update the player has not started.
  available,

  /// A flexible update is downloading in the background.
  downloading,

  /// A flexible update finished downloading and waits for a restart.
  downloaded,

  /// The player confirmed installation; Android is about to restart the app.
  installing,

  /// Play could not be reached or the flow failed (often offline).
  failed,

  /// Play's update API cannot serve this install (not installed from Google
  /// Play, no Play Store, and so on).
  unavailable,

  /// The platform has no in-app updates (iOS, desktop, tests).
  unsupported,
}

/// Google Play In-App Updates: checks, flexible and immediate flows,
/// download progress, restart-to-install, and recovery after the app is
/// restarted mid-update. UI lives in modules/update; this class only keeps
/// state and talks to [UpdatePlatform].
class UpdateService extends GetxService with WidgetsBindingObserver {
  final UpdatePlatform _platform;
  final StorageService _storage;
  final DateTime Function() _now;

  UpdateService(this._platform, this._storage, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  static const String _kSnoozedVersion = 'update.snoozedVersionCode';
  static const String _kSnoozedAt = 'update.snoozedAtMs';
  static const String _kFlowType = 'update.flowType';
  static const Duration checkTimeout = Duration(seconds: 20);

  /// Play InstallErrorCodes meaning "this install cannot use the API".
  static const Set<int> _apiUnavailableCodes = {
    -3, // ERROR_API_NOT_AVAILABLE
    -5, // ERROR_INSTALL_UNAVAILABLE
    -6, // ERROR_INSTALL_NOT_ALLOWED
    -9, // ERROR_PLAY_STORE_NOT_FOUND
    -10, // ERROR_APP_NOT_OWNED (sideloaded / debug build)
  };

  final Rx<UpdateStatus> status = UpdateStatus.idle.obs;
  final Rxn<AppUpdateInfoData> info = Rxn<AppUpdateInfoData>();

  /// 0–1 while a flexible update downloads; null when the size is unknown.
  final RxnDouble downloadProgress = RxnDouble();

  int? lastPlayErrorCode;

  StreamSubscription<InstallStateData>? _installSub;
  Future<void>? _checking;
  bool _autoChecked = false;
  bool _promptedThisSession = false;
  bool _restartPrompted = false;
  bool _flowActive = false;

  bool get isSupported => _platform.isSupported;

  UpdateDecision? get decision {
    final i = info.value;
    return i == null ? null : UpdatePolicy.decide(i);
  }

  bool get isRequired => decision?.required ?? false;

  @override
  void onInit() {
    super.onInit();
    if (!isSupported) {
      status.value = UpdateStatus.unsupported;
      return;
    }
    _installSub = _platform.installStates.listen(
      _onInstallState,
      onError: (_) {},
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    _installSub?.cancel();
    if (isSupported) WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  // ── Checking ──────────────────────────────────────────────────────────────

  /// Asks Play for the current update state. Concurrent calls share one
  /// request. Never throws.
  Future<void> checkForUpdate() {
    if (!isSupported) {
      status.value = UpdateStatus.unsupported;
      return Future.value();
    }
    return _checking ??= _check().whenComplete(() => _checking = null);
  }

  Future<void> _check() async {
    final busy = _isBusy;
    if (!busy) status.value = UpdateStatus.checking;
    try {
      final result = await _platform.checkForUpdate().timeout(checkTimeout);
      lastPlayErrorCode = null;
      _apply(result);
    } on UpdateException catch (e) {
      lastPlayErrorCode = e.playErrorCode;
      if (!busy) {
        status.value = e.code == 'UNSUPPORTED'
            ? UpdateStatus.unsupported
            : (_apiUnavailableCodes.contains(e.playErrorCode)
                ? UpdateStatus.unavailable
                : UpdateStatus.failed);
      }
    } catch (_) {
      // Timeout or anything unexpected: treat as a failed (likely offline) check.
      if (!busy) status.value = UpdateStatus.failed;
    }
  }

  /// The automatic check: once per session, then resumes an immediate update
  /// that was interrupted (Play requires the app to resume it).
  Future<void> autoCheck() async {
    if (_autoChecked || !isSupported) return;
    _autoChecked = true;
    await checkForUpdate();
    if (needsImmediateResume) await startUpdate(type: UpdateType.immediate);
  }

  bool get _isBusy =>
      status.value == UpdateStatus.downloading ||
      status.value == UpdateStatus.downloaded ||
      status.value == UpdateStatus.installing;

  String? get _savedFlowType => _storage.getMeta(_kFlowType) as String?;

  /// An immediate update this app started is still pending in Play.
  bool get needsImmediateResume =>
      !_flowActive &&
      info.value?.availability == UpdateAvailability.inProgress &&
      _savedFlowType == UpdateType.immediate.name;

  void _apply(AppUpdateInfoData i) {
    info.value = i;
    switch (i.installStatus) {
      case InstallStatus.downloaded:
        downloadProgress.value = 1;
        status.value = UpdateStatus.downloaded;
        return;
      case InstallStatus.pending:
      case InstallStatus.downloading:
        downloadProgress.value = i.totalBytesToDownload > 0
            ? (i.bytesDownloaded / i.totalBytesToDownload).clamp(0.0, 1.0)
            : null;
        status.value = UpdateStatus.downloading;
        return;
      case InstallStatus.installing:
        status.value = UpdateStatus.installing;
        return;
      default:
        break;
    }
    switch (i.availability) {
      case UpdateAvailability.available:
        status.value = UpdateStatus.available;
      case UpdateAvailability.inProgress:
        status.value = _savedFlowType == UpdateType.immediate.name
            ? UpdateStatus.available
            : UpdateStatus.downloading;
      case UpdateAvailability.notAvailable:
      case UpdateAvailability.unknown:
        _storage.setMeta(_kFlowType, null);
        status.value = UpdateStatus.upToDate;
    }
  }

  // ── Prompting rules (UI asks; it never decides on its own) ───────────────

  bool get shouldAutoPrompt {
    final d = decision;
    final i = info.value;
    if (d == null || i == null || status.value != UpdateStatus.available) {
      return false;
    }
    final snoozedMs = _storage.getMeta(_kSnoozedAt) as int?;
    return UpdatePolicy.shouldAutoPrompt(
      decision: d,
      versionCode: i.availableVersionCode,
      promptedThisSession: _promptedThisSession,
      snoozedVersionCode: _storage.getMeta(_kSnoozedVersion) as int?,
      snoozedAt: snoozedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(snoozedMs),
      now: _now(),
    );
  }

  bool get shouldPromptRestart =>
      status.value == UpdateStatus.downloaded && !_restartPrompted;

  void markPrompted() => _promptedThisSession = true;

  void markRestartPrompted() => _restartPrompted = true;

  /// "Later": silences the automatic prompt for this version for a while.
  Future<void> snooze() async {
    _promptedThisSession = true;
    final version = info.value?.availableVersionCode;
    if (version == null) return;
    await _storage.setMeta(_kSnoozedVersion, version);
    await _storage.setMeta(_kSnoozedAt, _now().millisecondsSinceEpoch);
  }

  // ── Flows ─────────────────────────────────────────────────────────────────

  /// Starts Play's update UI with [type] (default: the policy's choice).
  /// Returns what the player chose; never reports an install by itself.
  Future<UpdateFlowResult> startUpdate({UpdateType? type}) async {
    if (_flowActive) return UpdateFlowResult.canceled;
    final t = type ??
        decision?.type ??
        (needsImmediateResume ? UpdateType.immediate : null);
    if (t == null || !isSupported) return UpdateFlowResult.failed;

    _flowActive = true;
    _promptedThisSession = true;
    await _storage.setMeta(_kFlowType, t.name);
    try {
      final result = await _platform.startUpdate(t);
      switch (result) {
        case UpdateFlowResult.accepted:
          if (t == UpdateType.flexible) {
            // Real progress arrives through install-state events.
            if (status.value != UpdateStatus.downloaded) {
              downloadProgress.value = null;
              status.value = UpdateStatus.downloading;
            }
          } else {
            status.value = UpdateStatus.installing;
          }
        case UpdateFlowResult.canceled:
          await _storage.setMeta(_kFlowType, null);
          if (t == UpdateType.flexible && !isRequired) await snooze();
          status.value = UpdateStatus.available;
        case UpdateFlowResult.failed:
          await _storage.setMeta(_kFlowType, null);
          status.value = UpdateStatus.failed;
      }
      return result;
    } on UpdateException catch (e) {
      lastPlayErrorCode = e.playErrorCode;
      await _storage.setMeta(_kFlowType, null);
      status.value = UpdateStatus.failed;
      return UpdateFlowResult.failed;
    } finally {
      _flowActive = false;
    }
  }

  /// Installs a downloaded flexible update. Android restarts the app on
  /// success, so a true result only means the install was handed to Play.
  Future<bool> completeUpdate() async {
    if (status.value != UpdateStatus.downloaded) return false;
    status.value = UpdateStatus.installing;
    try {
      await _platform.completeUpdate();
      return true;
    } on UpdateException catch (e) {
      lastPlayErrorCode = e.playErrorCode;
      status.value = UpdateStatus.downloaded;
      return false;
    }
  }

  void _onInstallState(InstallStateData s) {
    switch (s.status) {
      case InstallStatus.pending:
      case InstallStatus.downloading:
        downloadProgress.value = s.progress;
        status.value = UpdateStatus.downloading;
      case InstallStatus.downloaded:
        downloadProgress.value = 1;
        status.value = UpdateStatus.downloaded;
      case InstallStatus.installing:
        status.value = UpdateStatus.installing;
      case InstallStatus.installed:
        _storage.setMeta(_kFlowType, null);
        downloadProgress.value = null;
        status.value = UpdateStatus.upToDate;
      case InstallStatus.failed:
        lastPlayErrorCode = s.errorCode;
        _storage.setMeta(_kFlowType, null);
        downloadProgress.value = null;
        status.value = UpdateStatus.failed;
      case InstallStatus.canceled:
        _storage.setMeta(_kFlowType, null);
        downloadProgress.value = null;
        status.value = UpdateStatus.available;
      case InstallStatus.unknown:
        break;
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onAppResumed();
  }

  /// Re-syncs a running update after the app returns to the foreground, and
  /// resumes an interrupted immediate update.
  @visibleForTesting
  Future<void> onAppResumed() async {
    if (!_autoChecked || _flowActive) return;
    if (!_isBusy && _savedFlowType == null) return;
    await checkForUpdate();
    if (needsImmediateResume) await startUpdate(type: UpdateType.immediate);
  }

  // ── Play Store fallback ───────────────────────────────────────────────────

  /// The package to open on the Play Store: as reported by Play or Android,
  /// with the build's applicationId as the last resort.
  Future<String> storePackageName() async {
    final fromInfo = info.value?.packageName;
    if (fromInfo != null && fromInfo.isNotEmpty) return fromInfo;
    final fromPlatform = await _platform.packageName();
    if (fromPlatform != null && fromPlatform.isNotEmpty) return fromPlatform;
    return AppConstants.androidApplicationId;
  }
}
