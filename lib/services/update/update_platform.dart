import 'dart:async';

import 'package:flutter/services.dart';

import 'app_update_models.dart';

/// A failed call into Play's update API. [playErrorCode] is Play's
/// InstallErrorCode when it gave one (for example -10 ERROR_APP_NOT_OWNED for
/// a build that was not installed from Google Play).
class UpdateException implements Exception {
  final String code;
  final String? message;
  final int? playErrorCode;

  const UpdateException(this.code, {this.message, this.playErrorCode});

  @override
  String toString() => 'UpdateException($code, $playErrorCode): $message';
}

/// Access to the platform's update mechanism.
abstract class UpdatePlatform {
  /// False where Play in-app updates cannot exist (iOS, desktop, tests).
  bool get isSupported;

  Future<String?> packageName();

  /// Throws [UpdateException] when Play cannot answer.
  Future<AppUpdateInfoData> checkForUpdate();

  /// Shows Play's update UI. Throws [UpdateException] if it cannot start.
  Future<UpdateFlowResult> startUpdate(UpdateType type);

  /// Installs a downloaded flexible update; Android restarts the app.
  Future<void> completeUpdate();

  Stream<InstallStateData> get installStates;
}

/// Talks to InAppUpdateHandler.kt.
class PlayUpdatePlatform implements UpdatePlatform {
  static const _methods =
      MethodChannel('com.arrowescape.arrowescapegame/update');
  static const _events =
      EventChannel('com.arrowescape.arrowescapegame/update_events');

  Stream<InstallStateData>? _states;

  @override
  bool get isSupported => true;

  @override
  Future<String?> packageName() async {
    try {
      return await _methods.invokeMethod<String>('packageName');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<AppUpdateInfoData> checkForUpdate() async {
    final map = await _invoke<Map<dynamic, dynamic>>('checkForUpdate');
    if (map == null) throw const UpdateException('EMPTY_RESPONSE');
    return AppUpdateInfoData.fromMap(map);
  }

  @override
  Future<UpdateFlowResult> startUpdate(UpdateType type) async {
    final outcome = await _invoke<String>('startUpdate', {'type': type.name});
    return switch (outcome) {
      'accepted' => UpdateFlowResult.accepted,
      'canceled' => UpdateFlowResult.canceled,
      _ => UpdateFlowResult.failed,
    };
  }

  @override
  Future<void> completeUpdate() => _invoke<Object?>('completeUpdate');

  @override
  Stream<InstallStateData> get installStates =>
      _states ??= _events
          .receiveBroadcastStream()
          .where((e) => e is Map)
          .map((e) => InstallStateData.fromMap(e as Map))
          .asBroadcastStream();

  Future<T?> _invoke<T>(String method, [Object? args]) async {
    try {
      return await _methods.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw UpdateException(
        e.code,
        message: e.message,
        playErrorCode: e.details is int ? e.details as int : null,
      );
    } on MissingPluginException catch (e) {
      throw UpdateException('UNSUPPORTED', message: e.message);
    }
  }
}

/// No in-app updates on this platform.
class NoOpUpdatePlatform implements UpdatePlatform {
  @override
  bool get isSupported => false;

  @override
  Future<String?> packageName() async => null;

  @override
  Future<AppUpdateInfoData> checkForUpdate() async =>
      throw const UpdateException('UNSUPPORTED');

  @override
  Future<UpdateFlowResult> startUpdate(UpdateType type) async =>
      throw const UpdateException('UNSUPPORTED');

  @override
  Future<void> completeUpdate() async =>
      throw const UpdateException('UNSUPPORTED');

  @override
  Stream<InstallStateData> get installStates => const Stream.empty();
}
