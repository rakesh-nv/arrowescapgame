import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrowescapegame/modules/gameplay/widgets/hint_ad_dialog.dart';

void main() {
  group('HintAdDialog Tests', () {
    testWidgets('Displays Need a Hint prompt and Watch Ad button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HintAdDialog(
              onWatchAd: () async => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Need a Hint?'), findsOneWidget);
      expect(find.textContaining('You have used all 3 hints'), findsOneWidget);
      expect(find.text('Watch Ad (+1 Hint)'), findsOneWidget);
      expect(find.text('Not Now'), findsOneWidget);
    });

    testWidgets('Watching ad successfully displays 1 Hint Added and Use Hint Now', (tester) async {
      bool adRequested = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HintAdDialog(
              onWatchAd: () async {
                adRequested = true;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Watch Ad
      await tester.tap(find.text('Watch Ad (+1 Hint)'));
      await tester.pumpAndSettle();

      expect(adRequested, isTrue);
      expect(find.text('1 Hint Added!'), findsOneWidget);
      expect(find.text('Use Hint Now'), findsOneWidget);
      expect(find.text('Keep for Later'), findsOneWidget);
    });

    testWidgets('Tapping Not Now closes dialog', (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await showDialog<bool>(
                    context: context,
                    builder: (_) => HintAdDialog(
                      onWatchAd: () async => true,
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Need a Hint?'), findsOneWidget);

      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(find.text('Need a Hint?'), findsNothing);
      expect(dialogResult, isFalse);
    });
  });
}
