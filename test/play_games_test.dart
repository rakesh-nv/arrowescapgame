import 'dart:async';

import 'package:arrowescapegame/data/models/player_progress.dart';
import 'package:arrowescapegame/data/repositories/progress_repository.dart';
import 'package:arrowescapegame/modules/home/home_controller.dart';
import 'package:arrowescapegame/services/economy_service.dart';
import 'package:arrowescapegame/services/play_games_service.dart';
import 'package:arrowescapegame/services/storage_service.dart';
import 'package:arrowescapegame/widgets/player_welcome_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:games_services/games_services.dart';
import 'package:get/get.dart';

/// A 1×1 PNG, as the plugin sends it (base64, possibly with line breaks).
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChw\n'
    'GA60e6kgAAAABJRU5ErkJggg==';

const _channel = MethodChannel('test/play_games_device');

void _deviceReady(Object? answer) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
        if (call.method != 'playGamesReady') return null;
        if (answer is Exception) throw answer;
        return answer;
      });
}

GooglePlayGamesService _service({
  required Stream<PlayerData?> Function() players,
  Future<String?> Function()? signIn,
}) => GooglePlayGamesService(
  deviceChannel: _channel,
  playerStream: players,
  signInCall: signIn ?? () async => 'success',
  timeout: const Duration(milliseconds: 200),
);

class _FakeStorage extends StorageService {
  _FakeStorage(this._progress);
  PlayerProgress _progress;

  @override
  PlayerProgress get progress => _progress;

  @override
  Future<void> saveProgress(PlayerProgress p) async => _progress = p;
}

class _FakePlayGames extends IPlayGamesService {
  @override
  final Rx<PlayGamesStatus> status;
  @override
  final Rxn<PlayGamesPlayer> player = Rxn<PlayGamesPlayer>();
  @override
  final bool canSignIn;
  int signInCalls = 0;

  _FakePlayGames(
    PlayGamesStatus s, {
    this.canSignIn = false,
    PlayGamesPlayer? p,
  }) : status = s.obs {
    player.value = p;
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> signIn() async => signInCalls++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    Get.reset();
  });

  group('GooglePlayGamesService', () {
    test('not configured on this build: guest, no sign-in offered', () async {
      _deviceReady(false);
      var asked = false;
      final s = _service(
        players: () {
          asked = true;
          return const Stream.empty();
        },
      );
      await s.start();
      expect(s.status.value, PlayGamesStatus.guest);
      expect(s.player.value, isNull);
      expect(s.canSignIn, isFalse);
      // Play Games is never touched when the SDK did not start.
      expect(asked, isFalse);
    });

    test('channel missing (old build, tests): guest', () async {
      _deviceReady(MissingPluginException());
      final s = _service(players: () => const Stream.empty());
      await s.start();
      expect(s.status.value, PlayGamesStatus.guest);
    });

    test('signed in automatically: real name, id and picture', () async {
      _deviceReady(true);
      final s = _service(
        players: () => Stream.value(
          const PlayerData(
            playerID: 'g123',
            displayName: '  Asha  ',
            iconImage: _pngBase64,
          ),
        ),
      );
      await s.start();
      expect(s.status.value, PlayGamesStatus.signedIn);
      expect(s.player.value!.displayName, 'Asha');
      expect(s.player.value!.playerId, 'g123');
      expect(s.player.value!.avatar, isNotNull);
      expect(s.player.value!.avatar!.sublist(1, 4), 'PNG'.codeUnits);
      expect(s.canSignIn, isFalse);
    });

    test('no picture or a broken one: player without avatar', () async {
      _deviceReady(true);
      for (final icon in [null, '', 'not base64 @@']) {
        final s = _service(
          players: () => Stream.value(
            PlayerData(playerID: null, displayName: 'Ravi', iconImage: icon),
          ),
        );
        await s.start();
        expect(s.status.value, PlayGamesStatus.signedIn);
        expect(s.player.value!.avatar, isNull, reason: '$icon');
        expect(s.player.value!.playerId, isNull);
      }
    });

    test(
      'not signed in (stream error) offers sign-in; sign-in works',
      () async {
        _deviceReady(true);
        var signedIn = false;
        var signInCalls = 0;
        final s = _service(
          players: () => signedIn
              ? Stream.value(
                  const PlayerData(playerID: 'p1', displayName: 'Mina'),
                )
              : Stream.error(PlatformException(code: 'failed_to_authenticate')),
          signIn: () async {
            signInCalls++;
            signedIn = true;
            return 'success';
          },
        );
        await s.start();
        expect(s.status.value, PlayGamesStatus.guest);
        expect(s.canSignIn, isTrue);

        await s.signIn();
        expect(signInCalls, 1);
        expect(s.status.value, PlayGamesStatus.signedIn);
        expect(s.player.value!.displayName, 'Mina');
      },
    );

    test('a failed manual sign-in stays guest without throwing', () async {
      _deviceReady(true);
      final s = _service(
        players: () => Stream.error(PlatformException(code: 'x')),
        signIn: () async => throw PlatformException(code: 'canceled'),
      );
      await s.start();
      await s.signIn();
      expect(s.status.value, PlayGamesStatus.guest);
    });

    test(
      'offline / no answer from Play Games: guest after the timeout',
      () async {
        _deviceReady(true);
        final never = StreamController<PlayerData?>();
        addTearDown(never.close);
        final s = _service(players: () => never.stream);
        await s.start();
        expect(s.status.value, PlayGamesStatus.guest);
      },
    );

    test('an empty display name is treated as not signed in', () async {
      _deviceReady(true);
      final s = _service(
        players: () =>
            Stream.value(const PlayerData(playerID: 'p', displayName: ' ')),
      );
      await s.start();
      expect(s.status.value, PlayGamesStatus.guest);
    });
  });

  group('PlayerWelcomeBanner', () {
    Widget host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 340, child: child)),
      ),
    );

    testWidgets('level comes from saved progress and follows it', (
      tester,
    ) async {
      final storage = _FakeStorage(PlayerProgress(highestUnlockedLevel: 37));
      Get.put<StorageService>(storage);
      final progress = Get.put(ProgressRepository(storage));
      Get.put(EconomyService(storage));
      final home = Get.put(HomeController());
      Get.put<IPlayGamesService>(
        _FakePlayGames(
          PlayGamesStatus.signedIn,
          p: const PlayerGamesPlayerName('Asha'),
        ),
      );

      await tester.pumpWidget(
        host(
          Obx(
            () => PlayerWelcomeBanner(level: home.highestUnlockedLevel.value),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hey there, Asha'), findsOneWidget);
      expect(find.text('Level 37'), findsOneWidget);

      // Clearing level 37 unlocks 38; Home reloads progress on return.
      await progress.markLevelCompleted(levelNumber: 37, stars: 3);
      home.loadProgress();
      await tester.pump();
      expect(find.text('Level 38'), findsOneWidget);
    });

    testWidgets('signed-in player: name, picture, no sign-in button', (
      tester,
    ) async {
      Get.put<IPlayGamesService>(
        _FakePlayGames(
          PlayGamesStatus.signedIn,
          p: PlayGamesPlayer(
            displayName: 'Asha',
            playerId: 'g1',
            avatar: GooglePlayGamesService.decodeAvatar(_pngBase64),
          ),
        ),
      );
      await tester.pumpWidget(host(const PlayerWelcomeBanner(level: 12)));
      await tester.pumpAndSettle();
      expect(find.text('Hey there, Asha'), findsOneWidget);
      expect(find.text('Level 12'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
    });

    testWidgets('a picture that fails to decode falls back to the initial', (
      tester,
    ) async {
      Get.put<IPlayGamesService>(
        _FakePlayGames(
          PlayGamesStatus.signedIn,
          p: PlayGamesPlayer(
            displayName: 'ravi',
            avatar: Uint8List.fromList([1, 2, 3, 4]),
          ),
        ),
      );
      await tester.pumpWidget(host(const PlayerWelcomeBanner(level: 3)));
      await tester.pumpAndSettle();
      expect(find.text('R'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing is shown unless a player is signed in', (
      tester,
    ) async {
      // No Play Games service at all (tests, iOS).
      await tester.pumpWidget(host(const PlayerWelcomeBanner(level: 5)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hey there'), findsNothing);
      expect(tester.getSize(find.byType(PlayerWelcomeBanner)).height, 0);

      // Guest, or still checking at launch: nothing either.
      for (final status in [PlayGamesStatus.guest, PlayGamesStatus.checking]) {
        Get.reset();
        Get.put<IPlayGamesService>(_FakePlayGames(status, canSignIn: true));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(host(const PlayerWelcomeBanner(level: 5)));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Hey there'),
          findsNothing,
          reason: '$status',
        );
        expect(find.textContaining('Level'), findsNothing, reason: '$status');
      }
    });

    testWidgets('appears once the automatic sign-in finishes', (tester) async {
      final service = _FakePlayGames(PlayGamesStatus.checking);
      Get.put<IPlayGamesService>(service);
      await tester.pumpWidget(host(const PlayerWelcomeBanner(level: 9)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hey there'), findsNothing);

      service.player.value = const PlayerGamesPlayerName('Mina');
      service.status.value = PlayGamesStatus.signedIn;
      await tester.pumpAndSettle();
      expect(find.text('Hey there, Mina'), findsOneWidget);
      expect(find.text('Level 9'), findsOneWidget);
    });

    testWidgets('long names and large text stay on one line, no overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      Get.put<IPlayGamesService>(
        _FakePlayGames(
          PlayGamesStatus.signedIn,
          p: const PlayerGamesPlayerName('A very long Play Games display name'),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 288,
                child: const PlayerWelcomeBanner(level: 1000),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Level 1000'), findsOneWidget);
    });
  });
}

/// Shorthand for a signed-in player with only a name.
class PlayerGamesPlayerName extends PlayGamesPlayer {
  const PlayerGamesPlayerName(String name) : super(displayName: name);
}
