import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'app_update_models.dart';
import 'update_platform.dart';

/// Google Play In-App Updates, IMMEDIATE flow only. The app shows no update
/// UI of its own: Play shows its update screen and progress, installs, and
/// restarts the app.
///
/// When it runs:
///  - once after startup ([checkOnStartup]);
///  - on every return to the foreground, mainly to resume an interrupted
///    update (Play reports DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS).
///
/// Loop and duplicate protection:
///  - one attempt at a time; overlapping triggers share it (Kotlin also
///    refuses a second update screen);
///  - the "resumed" event caused by Play's own screen closing is ignored
///    ([flowCloseGrace]);
///  - after the player cancels a new update, it is not offered again this
///    session (interrupted updates are still resumed); the next cold start
///    offers it again;
///  - after [maxFailuresPerSession] failed flows, nothing more is started
///    this session;
///  - an install that cannot use Play's API (sideloaded, no Play Store)
///    disables the service for the session.
/// Every attempt fetches fresh AppUpdateInfo on the Kotlin side.
class UpdateService extends GetxService with WidgetsBindingObserver {
  final UpdatePlatform _platform;
  final DateTime Function() _now;

  UpdateService(this._platform, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  /// A resume this soon after Play's screen closed is that screen closing,
  /// not the player coming back.
  static const Duration flowCloseGrace = Duration(seconds: 3);
  static const int maxFailuresPerSession = 2;

  /// Play InstallErrorCodes meaning "this install cannot use the API".
  static const Set<int> _apiUnavailableCodes = {
    -3, // ERROR_API_NOT_AVAILABLE
    -5, // ERROR_INSTALL_UNAVAILABLE
    -6, // ERROR_INSTALL_NOT_ALLOWED
    -9, // ERROR_PLAY_STORE_NOT_FOUND
    -10, // ERROR_APP_NOT_OWNED (sideloaded / debug build)
  };

  Future<void>? _inFlight;
  bool _started = false;
  bool _disabled = false;
  bool _declinedThisSession = false;
  int _failures = 0;
  DateTime? _flowClosedAt;

  /// The last answer from Play (for debugging and tests).
  UpdateAttempt? lastAttempt;

  bool get isSupported => _platform.isSupported;

  @override
  void onInit() {
    super.onInit();
    if (isSupported) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    if (isSupported) WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  /// The startup check. Runs once per process; later calls do nothing.
  Future<void> checkOnStartup() {
    if (_started || !isSupported) return Future.value();
    _started = true;
    return _run();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(onAppResumed());
  }

  @visibleForTesting
  Future<void> onAppResumed() {
    if (!_started) return Future.value();
    if (_inFlight != null) return _inFlight!;
    final closedAt = _flowClosedAt;
    if (closedAt != null && _now().difference(closedAt) < flowCloseGrace) {
      return Future.value();
    }
    return _run();
  }

  Future<void> _run() =>
      _inFlight ??= _attempt().whenComplete(() => _inFlight = null);

  Future<void> _attempt() async {
    if (!isSupported || _disabled || _failures >= maxFailuresPerSession) {
      return;
    }
    try {
      final attempt = await _platform.startImmediateUpdate(
        allowNewUpdate: !_declinedThisSession,
      );
      lastAttempt = attempt;
      if (attempt.outcome.flowShown) _flowClosedAt = _now();
      switch (attempt.outcome) {
        case UpdateOutcome.canceled:
          if (!attempt.resumed) _declinedThisSession = true;
        case UpdateOutcome.failed:
        case UpdateOutcome.notStarted:
          _failures++;
        case UpdateOutcome.accepted:
        // Play installs and restarts the app; nothing to do here.
        case UpdateOutcome.noUpdate:
        case UpdateOutcome.notAllowed:
        case UpdateOutcome.busy:
          break;
      }
    } on UpdateException catch (e) {
      if (e.code == 'UNSUPPORTED' ||
          _apiUnavailableCodes.contains(e.playErrorCode)) {
        _disabled = true;
      }
      // Anything else (usually offline): try again on the next resume.
    } catch (_) {
      // Never let an update problem reach the game.
    }
  }
}
