import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:games_services/games_services.dart';
import 'package:get/get.dart';

/// The signed-in Google Play Games player.
class PlayGamesPlayer {
  final String displayName;

  /// Play Games player ID; can be null because of the player's privacy
  /// settings.
  final String? playerId;

  /// Profile picture (PNG/JPEG bytes), or null when there is none or it could
  /// not be loaded.
  final Uint8List? avatar;

  const PlayGamesPlayer({
    required this.displayName,
    this.playerId,
    this.avatar,
  });
}

/// Where Play Games sign-in stands.
enum PlayGamesStatus {
  /// Checking for a signed-in player in the background.
  checking,

  /// Signed in; [IPlayGamesService.player] holds the player.
  signedIn,

  /// Playing as a guest: not signed in, offline, Play Games unavailable or
  /// not configured. The game works the same.
  guest,
}

/// Google Play Games sign-in. Never required to play: every failure ends in
/// [PlayGamesStatus.guest].
abstract class IPlayGamesService extends GetxService {
  Rx<PlayGamesStatus> get status;
  Rxn<PlayGamesPlayer> get player;

  /// Whether a manual sign-in can be offered (Play Games is set up on this
  /// device and build).
  bool get canSignIn;

  /// Looks for the player signed in automatically at launch. Runs in the
  /// background; never throws.
  Future<void> start();

  /// Shows Play Games' sign-in for a guest who asks for it. Never throws.
  Future<void> signIn();
}

/// Tests, iOS and builds without Play Games: always a guest.
class NoOpPlayGamesService extends IPlayGamesService {
  @override
  final Rx<PlayGamesStatus> status = PlayGamesStatus.guest.obs;
  @override
  final Rxn<PlayGamesPlayer> player = Rxn<PlayGamesPlayer>();
  @override
  bool get canSignIn => false;
  @override
  Future<void> start() async {}
  @override
  Future<void> signIn() async {}
}

/// Play Games Services v2 through the games_services plugin.
///
/// ArrowEscapeApplication (Android) initialises the SDK only when the build
/// has a Play Games project ID; the SDK then signs returning players in
/// automatically at launch. This service reads that result, so launching the game never shows
/// a sign-in prompt. Offline, unconfigured, signed-out or failing cases all
/// leave the player as a guest.
class GooglePlayGamesService extends IPlayGamesService {
  GooglePlayGamesService({
    this.deviceChannel = const MethodChannel(
      'com.arrowescape.arrowescapegame/device',
    ),
    Stream<PlayerData?> Function()? playerStream,
    Future<String?> Function()? signInCall,
    this.timeout = const Duration(seconds: 20),
  }) : _playerStream = playerStream ?? (() => GameAuth.player),
       _signInCall = signInCall ?? GameAuth.signIn;

  /// MainActivity's channel; reports whether ArrowEscapeApplication started
  /// the Play Games SDK.
  final MethodChannel deviceChannel;
  final Stream<PlayerData?> Function() _playerStream;
  final Future<String?> Function() _signInCall;

  /// How long to wait for Play Games before settling on guest.
  final Duration timeout;

  @override
  final Rx<PlayGamesStatus> status = PlayGamesStatus.checking.obs;
  @override
  final Rxn<PlayGamesPlayer> player = Rxn<PlayGamesPlayer>();

  bool _ready = false;
  bool _signingIn = false;

  @override
  bool get canSignIn => _ready && status.value != PlayGamesStatus.signedIn;

  @override
  Future<void> start() async {
    try {
      _ready =
          await deviceChannel
              .invokeMethod<bool>('playGamesReady')
              .timeout(const Duration(seconds: 5)) ??
          false;
    } catch (_) {
      _ready = false;
    }
    if (!_ready) {
      _setGuest();
      return;
    }
    await _readPlayer();
  }

  @override
  Future<void> signIn() async {
    if (!_ready || _signingIn) return;
    _signingIn = true;
    status.value = PlayGamesStatus.checking;
    try {
      await _signInCall().timeout(const Duration(minutes: 2));
    } catch (e) {
      if (kDebugMode) debugPrint('[PlayGames] sign-in failed: $e');
    } finally {
      _signingIn = false;
    }
    await _readPlayer();
  }

  /// One event from the plugin's player stream: the player, or null/error
  /// when nobody is signed in.
  Future<void> _readPlayer() async {
    PlayerData? data;
    try {
      data = await _playerStream().first.timeout(timeout);
    } catch (e) {
      if (kDebugMode) debugPrint('[PlayGames] not signed in: $e');
    }
    final name = data?.displayName.trim() ?? '';
    if (data == null || name.isEmpty) {
      _setGuest();
      return;
    }
    player.value = PlayGamesPlayer(
      displayName: name,
      playerId: data.playerID,
      avatar: decodeAvatar(data.iconImage),
    );
    status.value = PlayGamesStatus.signedIn;
  }

  void _setGuest() {
    player.value = null;
    status.value = PlayGamesStatus.guest;
  }

  /// The plugin sends the picture as base64 (possibly with line breaks), or
  /// an empty string when it could not load it.
  @visibleForTesting
  static Uint8List? decodeAvatar(String? base64Image) {
    final clean = base64Image?.replaceAll(RegExp(r'\s'), '') ?? '';
    if (clean.isEmpty) return null;
    try {
      final bytes = base64Decode(clean);
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }
}
