import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:arrowescapegame/services/app_initialization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    AppInitializationService.resetForTesting();
    Get.reset();
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    Get.reset();
  });

  group('AppInitializationService Tests', () {
    test('Executes initialization steps sequentially and reaches complete state', () async {
      final stepsObserved = <InitStep>[];

      final success = await AppInitializationService.initialize(
        onProgress: (progress) {
          stepsObserved.add(progress.step);
        },
      );

      expect(success, isTrue);
      expect(AppInitializationService.isInitialized, isTrue);
      expect(stepsObserved, contains(InitStep.storage));
      expect(stepsObserved, contains(InitStep.progress));
      expect(stepsObserved, contains(InitStep.audio));
      expect(stepsObserved, contains(InitStep.ads));
      expect(stepsObserved, contains(InitStep.levelSystem));
      expect(stepsObserved.last, equals(InitStep.complete));
    });

    test('Second initialization call returns immediately as already initialized', () async {
      var callCount = 0;

      final success = await AppInitializationService.initialize(
        onProgress: (progress) {
          callCount++;
        },
      );

      expect(success, isTrue);

      final secondSuccess = await AppInitializationService.initialize(
        onProgress: (progress) {
          callCount++;
          expect(progress.step, equals(InitStep.complete));
        },
      );

      expect(secondSuccess, isTrue);
      expect(callCount, greaterThanOrEqualTo(2));
    });
  });
}
