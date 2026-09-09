import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrowescapegame/data/models/difficulty.dart';
import 'package:arrowescapegame/widgets/coin_badge.dart';
import 'package:arrowescapegame/widgets/difficulty_badge.dart';
import 'package:arrowescapegame/widgets/heart_display.dart';
import 'package:arrowescapegame/widgets/primary_button.dart';
import 'package:arrowescapegame/widgets/secondary_button.dart';

void main() {
  group('Shared Widgets Smoke Tests', () {
    testWidgets('CoinBadge displays coin count formatted', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CoinBadge(coins: 450),
          ),
        ),
      );

      expect(find.text('450'), findsOneWidget);
      expect(find.byIcon(Icons.monetization_on_rounded), findsOneWidget);
    });

    testWidgets('DifficultyBadge displays correct text for difficulty', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DifficultyBadge(difficulty: Difficulty.hard),
          ),
        ),
      );

      expect(find.text('HARD'), findsOneWidget);
    });

    testWidgets('HeartDisplay renders full and empty hearts according to lives', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeartDisplay(lives: 2, maxLives: 3),
          ),
        ),
      );

      // With lives=2 and maxLives=3: 2 filled hearts and 1 empty outline heart
      expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.favorite_outline_rounded), findsOneWidget);
    });

    testWidgets('PrimaryButton displays label and fires callback on tap', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              label: 'PLAY NOW',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('PLAY NOW'), findsOneWidget);
      await tester.tap(find.text('PLAY NOW'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('SecondaryButton displays label and handles tap', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecondaryButton(
              label: 'CANCEL',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('CANCEL'), findsOneWidget);
      await tester.tap(find.text('CANCEL'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
