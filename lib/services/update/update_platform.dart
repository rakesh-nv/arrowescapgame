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

  /// Asks Play (with fresh update info) to resume an interrupted immediate
  /// update, or, when [allowNewUpdate], to start one for an available
  /// version. Completes when Play's update screen closes (or right away when
  /// nothing was shown). Throws [UpdateException] when Play cannot answer.
  Future<UpdateAttempt> startImmediateUpdate({required bool allowNewUpdate});
}

/// Talks to InAppUpdateHandler.kt.
class PlayUpdatePlatform implements UpdatePlatform {
  static const _methods =
      MethodChannel('com.arrowescape.arrowescapegame/update');

  @override
  bool get isSupported => true;

  @override
  Future<UpdateAttempt> startImmediateUpdate({
    required bool allowNewUpdate,
  }) async {
    try {
      final map = await _methods.invokeMethod<Map<dynamic, dynamic>>(
        'startImmediateUpdate',
        {'allowNewUpdate': allowNewUpdate},
      );
      if (map == null) throw const UpdateException('EMPTY_RESPONSE');
      return UpdateAttempt.fromMap(map);
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
  Future<UpdateAttempt> startImmediateUpdate({
    required bool allowNewUpdate,
  }) async =>
      throw const UpdateException('UNSUPPORTED');
}
