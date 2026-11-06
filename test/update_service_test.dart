import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:arrowescapegame/services/update/app_update_models.dart';
import 'package:arrowescapegame/services/update/update_platform.dart';
import 'package:arrowescapegame/services/update/update_service.dart';

/// Stands in for InAppUpdateHandler.kt: answers each call with the next
/// queued response (the last one repeats).
class _FakePlatform implements UpdatePlatform {
  final List<Object> responses; // UpdateAttempt | UpdateException
  final calls = <bool>[]; // allowNewUpdate per call
  Completer<UpdateAttempt>? hold;

  _FakePlatform(this.responses);

  @override
  bool get isSupported => true;

  @override
  Future<UpdateAttempt> startImmediateUpdate({
    required bool allowNewUpdate,
  }) async {
    calls.add(allowNewUpdate);
    if (hold != null) return hold!.future;
    final r = responses.length > 1 ? responses.removeAt(0) : responses.first;
    if (r is UpdateException) throw r;
    return r as UpdateAttempt;
  }
}

class _Clock {
  DateTime now = DateTime(2026, 11, 6, 12);
  void advance(Duration d) => now = now.add(d);
}

const _noUpdate = UpdateAttempt(UpdateOutcome.noUpdate);
const _accepted = UpdateAttempt(UpdateOutcome.accepted, availableVersionCode: 16);
const _canceledNew = UpdateAttempt(UpdateOutcome.canceled, availableVersionCode: 16);
const _canceledResumed =
    UpdateAttempt(UpdateOutcome.canceled, resumed: true, availableVersionCode: 16);
const _failed = UpdateAttempt(UpdateOutcome.failed, availableVersionCode: 16);

void main() {
  late _Clock clock;

  UpdateService make(_FakePlatform p) => UpdateService(p, clock: () => clock.now);

  setUp(() => clock = _Clock());

  group('UpdateAttempt.fromMap', () {
    test('parses the Kotlin response', () {
      final a = UpdateAttempt.fromMap({
        'outcome': 'canceled',
        'resumed': true,
        'availableVersionCode': 16,
      });
      expect(a.outcome, UpdateOutcome.canceled);
      expect(a.resumed, isTrue);
      expect(a.availableVersionCode, 16);
    });

    test('unknown outcome is treated as failed', () {
      expect(UpdateAttempt.fromMap({'outcome': 'weird'}).outcome,
          UpdateOutcome.failed);
    });

    test('flowShown only for outcomes after Play UI was shown', () {
      expect(UpdateOutcome.accepted.flowShown, isTrue);
      expect(UpdateOutcome.canceled.flowShown, isTrue);
      expect(UpdateOutcome.failed.flowShown, isTrue);
      expect(UpdateOutcome.noUpdate.flowShown, isFalse);
      expect(UpdateOutcome.busy.flowShown, isFalse);
      expect(UpdateOutcome.notStarted.flowShown, isFalse);
    });
  });

  group('UpdateService', () {
    test('startup asks Play once and allows a new immediate update', () async {
      final p = _FakePlatform([_accepted]);
      final s = make(p);
      await s.checkOnStartup();
      await s.checkOnStartup();
      expect(p.calls, [true]);
      expect(s.lastAttempt?.outcome, UpdateOutcome.accepted);
    });

    test('resume before the startup check does nothing', () async {
      final p = _FakePlatform([_accepted]);
      await make(p).onAppResumed();
      expect(p.calls, isEmpty);
    });

    test('after updating, Play reports no update and nothing is shown',
        () async {
      final p = _FakePlatform([_noUpdate]);
      final s = make(p);
      await s.checkOnStartup();
      clock.advance(const Duration(minutes: 1));
      await s.onAppResumed();
      expect(p.calls, [true, true]);
      expect(s.lastAttempt?.outcome, UpdateOutcome.noUpdate);
    });

    test('overlapping triggers share one request', () async {
      final p = _FakePlatform([_accepted])..hold = Completer<UpdateAttempt>();
      final s = make(p);
      final first = s.checkOnStartup();
      final second = s.onAppResumed();
      final third = s.onAppResumed();
      expect(p.calls.length, 1);
      p.hold!.complete(_accepted);
      await Future.wait([first, second, third]);
      expect(p.calls.length, 1);
    });

    test('resume caused by Play screen closing is ignored', () async {
      final p = _FakePlatform([_canceledResumed, _noUpdate]);
      final s = make(p);
      await s.checkOnStartup();
      clock.advance(const Duration(seconds: 1));
      await s.onAppResumed();
      expect(p.calls.length, 1);

      clock.advance(UpdateService.flowCloseGrace);
      await s.onAppResumed();
      expect(p.calls.length, 2);
    });

    test('a canceled new update is not offered again this session', () async {
      final p = _FakePlatform([_canceledNew, _noUpdate]);
      final s = make(p);
      await s.checkOnStartup();
      clock.advance(const Duration(minutes: 1));
      await s.onAppResumed();
      // Still asks Play (to resume an interrupted update), but not to start
      // a new one.
      expect(p.calls, [true, false]);
    });

    test('a canceled interrupted update is resumed on the next return',
        () async {
      final p = _FakePlatform([_canceledResumed, _accepted]);
      final s = make(p);
      await s.checkOnStartup();
      clock.advance(const Duration(minutes: 1));
      await s.onAppResumed();
      expect(p.calls, [true, true]);
    });

    test('stops after repeated failures', () async {
      final p = _FakePlatform([_failed]);
      final s = make(p);
      await s.checkOnStartup();
      for (var i = 0; i < 5; i++) {
        clock.advance(const Duration(minutes: 1));
        await s.onAppResumed();
      }
      expect(p.calls.length, UpdateService.maxFailuresPerSession);
    });

    test('an install Play cannot update disables the service', () async {
      final p = _FakePlatform(
          [const UpdateException('CHECK_FAILED', playErrorCode: -10)]);
      final s = make(p);
      await s.checkOnStartup();
      clock.advance(const Duration(minutes: 1));
      await s.onAppResumed();
      expect(p.calls.length, 1);
    });

    test('an offline check is retried on the next resume', () async {
      final p = _FakePlatform([
        const UpdateException('CHECK_FAILED', playErrorCode: -2),
        _accepted,
      ]);
      final s = make(p);
      await s.checkOnStartup();
      await s.onAppResumed();
      expect(p.calls, [true, true]);
      expect(s.lastAttempt?.outcome, UpdateOutcome.accepted);
    });

    test('unexpected errors never escape', () async {
      final p = _FakePlatform([StateError('boom')]);
      final s = make(p);
      await expectLater(s.checkOnStartup(), completes);
    });

    test('no-op platform does nothing', () async {
      final s = UpdateService(NoOpUpdatePlatform());
      expect(s.isSupported, isFalse);
      await s.checkOnStartup();
      await s.onAppResumed();
      expect(s.lastAttempt, isNull);
    });
  });
}
