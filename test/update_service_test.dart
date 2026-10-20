import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:arrowescapegame/core/constants/app_constants.dart';
import 'package:arrowescapegame/data/models/player_progress.dart';
import 'package:arrowescapegame/services/storage_service.dart';
import 'package:arrowescapegame/services/update/app_update_models.dart';
import 'package:arrowescapegame/services/update/update_platform.dart';
import 'package:arrowescapegame/services/update/update_service.dart';

class _FakeStorage extends StorageService {
  PlayerProgress current = PlayerProgress();

  @override
  PlayerProgress get progress => current;

  @override
  Future<void> saveProgress(PlayerProgress p) async => current = p;
}

class _FakePlatform implements UpdatePlatform {
  AppUpdateInfoData? info;
  UpdateException? checkError;
  UpdateFlowResult flowResult = UpdateFlowResult.accepted;
  UpdateException? completeError;
  final startedTypes = <UpdateType>[];
  int checks = 0;
  int completes = 0;
  final states = StreamController<InstallStateData>.broadcast();

  @override
  bool get isSupported => true;

  @override
  Future<String?> packageName() async => 'com.example.fromplatform';

  @override
  Future<AppUpdateInfoData> checkForUpdate() async {
    checks++;
    if (checkError != null) throw checkError!;
    return info!;
  }

  @override
  Future<UpdateFlowResult> startUpdate(UpdateType type) async {
    startedTypes.add(type);
    return flowResult;
  }

  @override
  Future<void> completeUpdate() async {
    completes++;
    if (completeError != null) throw completeError!;
  }

  @override
  Stream<InstallStateData> get installStates => states.stream;
}

AppUpdateInfoData _available({
  int priority = 0,
  int? staleness,
  bool flexible = true,
  bool immediate = true,
  int version = 12,
}) =>
    AppUpdateInfoData(
      availability: UpdateAvailability.available,
      availableVersionCode: version,
      priority: priority,
      stalenessDays: staleness,
      flexibleAllowed: flexible,
      immediateAllowed: immediate,
      packageName: 'com.arrowescape.arrowescapegame',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdatePolicy', () {
    test('no decision unless Play reports an available update', () {
      expect(
        UpdatePolicy.decide(const AppUpdateInfoData(
          availability: UpdateAvailability.notAvailable,
          flexibleAllowed: true,
          immediateAllowed: true,
        )),
        isNull,
      );
      expect(
        UpdatePolicy.decide(_available(flexible: false, immediate: false)),
        isNull,
      );
    });

    test('normal priority is an optional flexible update', () {
      final d = UpdatePolicy.decide(_available())!;
      expect(d.type, UpdateType.flexible);
      expect(d.required, isFalse);
    });

    test('high priority is a required immediate update', () {
      final d = UpdatePolicy.decide(_available(priority: 4))!;
      expect(d.type, UpdateType.immediate);
      expect(d.required, isTrue);
      final stale = UpdatePolicy.decide(_available(priority: 3, staleness: 20))!;
      expect(stale.required, isTrue);
      final fresh = UpdatePolicy.decide(_available(priority: 3, staleness: 2))!;
      expect(fresh.required, isFalse);
    });

    test('required only when Play allows an immediate update', () {
      final d = UpdatePolicy.decide(_available(priority: 5, immediate: false))!;
      expect(d.required, isFalse);
      expect(d.type, UpdateType.flexible);
    });

    test('"Later" snooze lasts three days per version', () {
      const optional =
          UpdateDecision(type: UpdateType.flexible, required: false);
      final now = DateTime(2026, 10, 10);
      bool prompt({int? snoozedVersion, DateTime? at, bool session = false}) =>
          UpdatePolicy.shouldAutoPrompt(
            decision: optional,
            versionCode: 12,
            promptedThisSession: session,
            snoozedVersionCode: snoozedVersion,
            snoozedAt: at,
            now: now,
          );
      expect(prompt(), isTrue);
      expect(prompt(session: true), isFalse);
      expect(prompt(snoozedVersion: 12, at: now.subtract(const Duration(days: 1))),
          isFalse);
      expect(prompt(snoozedVersion: 12, at: now.subtract(const Duration(days: 3))),
          isTrue);
      expect(prompt(snoozedVersion: 11, at: now), isTrue);
    });

    test('parses Play maps', () {
      final info = AppUpdateInfoData.fromMap({
        'updateAvailability': 2,
        'installStatus': 11,
        'availableVersionCode': 10,
        'updatePriority': 9,
        'clientVersionStalenessDays': null,
        'immediateAllowed': true,
        'flexibleAllowed': false,
        'packageName': 'pkg',
      });
      expect(info.availability, UpdateAvailability.available);
      expect(info.installStatus, InstallStatus.downloaded);
      expect(info.priority, 5);
      expect(info.stalenessDays, isNull);
      final state = InstallStateData.fromMap({
        'installStatus': 2,
        'bytesDownloaded': 25,
        'totalBytesToDownload': 100,
      });
      expect(state.status, InstallStatus.downloading);
      expect(state.progress, 0.25);
    });

    test('Play Store link uses the package name', () {
      expect(
        playStoreUri('com.arrowescape.arrowescapegame').toString(),
        'https://play.google.com/store/apps/details?id=com.arrowescape.arrowescapegame',
      );
    });
  });

  group('UpdateService', () {
    late _FakePlatform platform;
    late _FakeStorage storage;
    late UpdateService service;
    var now = DateTime(2026, 10, 10, 12);

    setUp(() {
      platform = _FakePlatform();
      storage = _FakeStorage();
      now = DateTime(2026, 10, 10, 12);
      service = UpdateService(platform, storage, clock: () => now)..onInit();
    });

    tearDown(() => service.onClose());

    test('up to date', () async {
      platform.info =
          const AppUpdateInfoData(availability: UpdateAvailability.notAvailable);
      await service.autoCheck();
      expect(service.status.value, UpdateStatus.upToDate);
      expect(service.shouldAutoPrompt, isFalse);
    });

    test('auto check runs once per session', () async {
      platform.info = _available();
      await service.autoCheck();
      await service.autoCheck();
      expect(platform.checks, 1);
      expect(service.status.value, UpdateStatus.available);
      expect(service.shouldAutoPrompt, isTrue);
      service.markPrompted();
      expect(service.shouldAutoPrompt, isFalse);
    });

    test('sideloaded / debug install is "unavailable", offline is "failed"',
        () async {
      platform.checkError =
          const UpdateException('CHECK_FAILED', playErrorCode: -10);
      await service.checkForUpdate();
      expect(service.status.value, UpdateStatus.unavailable);

      platform.checkError = const UpdateException('CHECK_FAILED');
      await service.checkForUpdate();
      expect(service.status.value, UpdateStatus.failed);
    });

    test('flexible flow: progress, downloaded, restart', () async {
      platform.info = _available();
      await service.autoCheck();
      expect(await service.startUpdate(), UpdateFlowResult.accepted);
      expect(platform.startedTypes, [UpdateType.flexible]);
      expect(service.status.value, UpdateStatus.downloading);

      platform.states.add(const InstallStateData(
        status: InstallStatus.downloading,
        bytesDownloaded: 40,
        totalBytesToDownload: 100,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(service.downloadProgress.value, 0.4);

      platform.states
          .add(const InstallStateData(status: InstallStatus.downloaded));
      await Future<void>.delayed(Duration.zero);
      expect(service.status.value, UpdateStatus.downloaded);
      expect(service.shouldPromptRestart, isTrue);

      expect(await service.completeUpdate(), isTrue);
      expect(platform.completes, 1);
      // Not "installed": only Android restarting the app confirms that.
      expect(service.status.value, UpdateStatus.installing);
    });

    test('failed restart returns to "downloaded"', () async {
      platform.info = const AppUpdateInfoData(
        availability: UpdateAvailability.inProgress,
        installStatus: InstallStatus.downloaded,
      );
      await service.checkForUpdate();
      platform.completeError = const UpdateException('COMPLETE_FAILED');
      expect(await service.completeUpdate(), isFalse);
      expect(service.status.value, UpdateStatus.downloaded);
    });

    test('declining the flexible dialog snoozes that version', () async {
      platform.info = _available(version: 20);
      await service.autoCheck();
      platform.flowResult = UpdateFlowResult.canceled;
      expect(await service.startUpdate(), UpdateFlowResult.canceled);
      expect(service.status.value, UpdateStatus.available);

      // Next session, same version, a day later: no automatic prompt.
      final next = UpdateService(platform, storage, clock: () => now);
      next.info.value = platform.info;
      next.status.value = UpdateStatus.available;
      now = now.add(const Duration(days: 1));
      expect(next.shouldAutoPrompt, isFalse);
      now = now.add(const Duration(days: 3));
      expect(next.shouldAutoPrompt, isTrue);
    });

    test('failed download reports failure', () async {
      platform.info = _available();
      await service.autoCheck();
      await service.startUpdate();
      platform.states.add(
          const InstallStateData(status: InstallStatus.failed, errorCode: -100));
      await Future<void>.delayed(Duration.zero);
      expect(service.status.value, UpdateStatus.failed);
      expect(service.lastPlayErrorCode, -100);
    });

    test('required update always prompts and uses the immediate flow',
        () async {
      platform.info = _available(priority: 5);
      await service.autoCheck();
      expect(service.isRequired, isTrue);
      service.markPrompted();
      expect(service.shouldAutoPrompt, isTrue);
      await service.startUpdate();
      expect(platform.startedTypes, [UpdateType.immediate]);
    });

    test('an interrupted immediate update resumes on the next launch',
        () async {
      platform.info = _available(priority: 5);
      platform.flowResult = UpdateFlowResult.accepted;
      await service.autoCheck();
      // Player accepts, then the process dies before Play finishes.
      await storage.setMeta('update.flowType', 'immediate');
      service.onClose();

      platform.info = const AppUpdateInfoData(
        availability: UpdateAvailability.inProgress,
        immediateAllowed: true,
      );
      platform.startedTypes.clear();
      final relaunched = UpdateService(platform, storage)..onInit();
      await relaunched.autoCheck();
      expect(platform.startedTypes, [UpdateType.immediate]);
      relaunched.onClose();
    });

    test('a flexible download in progress is not turned into immediate',
        () async {
      await storage.setMeta('update.flowType', 'flexible');
      platform.info = const AppUpdateInfoData(
        availability: UpdateAvailability.inProgress,
        installStatus: InstallStatus.downloading,
        bytesDownloaded: 5,
        totalBytesToDownload: 10,
      );
      await service.autoCheck();
      expect(platform.startedTypes, isEmpty);
      expect(service.status.value, UpdateStatus.downloading);
      expect(service.downloadProgress.value, 0.5);
    });

    test('store package comes from Play, then Android, then the build id',
        () async {
      platform.info = _available();
      await service.checkForUpdate();
      expect(await service.storePackageName(),
          'com.arrowescape.arrowescapegame');

      final fresh = UpdateService(platform, storage);
      expect(await fresh.storePackageName(), 'com.example.fromplatform');

      final noOp = UpdateService(NoOpUpdatePlatform(), storage);
      expect(await noOp.storePackageName(), AppConstants.androidApplicationId);
    });

    test('unsupported platform never touches Play', () async {
      final noOp = UpdateService(NoOpUpdatePlatform(), storage)..onInit();
      await noOp.autoCheck();
      expect(noOp.status.value, UpdateStatus.unsupported);
      expect(await noOp.startUpdate(), UpdateFlowResult.failed);
      noOp.onClose();
    });
  });
}
