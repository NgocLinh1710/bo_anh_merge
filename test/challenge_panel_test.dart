import 'package:bo_anh/models/collection_achievement.dart';
import 'package:bo_anh/models/game_state.dart';
import 'package:bo_anh/widgets/challenge_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('goals remain readable on a small phone with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    var chosen = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ChallengePanel(
                achievement: const CollectionAchievement(),
                state: GameState(board: List.filled(9, 1)),
                target: 240,
                choosingRescue: false,
                canRescue: true,
                onRescue: () => chosen = true,
                onCancel: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.byType(OutlinedButton));
    await tester.tap(find.byType(OutlinedButton));
    expect(chosen, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('used rescue stays disabled while earned badges remain visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChallengePanel(
              achievement: const CollectionAchievement(
                bestMoves: 3,
                cleanWinner: true,
              ),
              state: GameState(board: List.filled(9, 1), rescueUsed: true),
              target: 3,
              choosingRescue: false,
              canRescue: false,
              onRescue: () => fail('Used rescue cannot be activated'),
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(find.text('Đã dùng lượt đổi ô'), findsOneWidget);
    expect(find.textContaining('Kỷ lục: 3 lượt'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
  });
}
