import 'package:bo_anh/main.dart';
import 'package:bo_anh/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
    const Size(844, 390),
  ]) {
    testWidgets(
      'home stays centered and scrollable at ${size.width}x${size.height}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const BoAnhApp());
        expect(tester.takeException(), isNull);
        final content = tester.getRect(find.byKey(const Key('home-content')));
        final title = tester.getRect(find.text('BơAnh Alliance'));
        final play = tester.getRect(find.byType(ElevatedButton));
        final backup = tester.getRect(find.byType(OutlinedButton));
        for (final rect in [content, title, play, backup]) {
          expect(rect.center.dx, closeTo(size.width / 2, 1));
          expect(rect.left, greaterThanOrEqualTo(24));
          expect(rect.right, lessThanOrEqualTo(size.width - 24));
        }
        expect(play.width, closeTo(backup.width, 1));
        expect(
          tester.widget<Text>(find.text('BơAnh Alliance')).textAlign,
          TextAlign.center,
        );
        if (content.height + 48 <= size.height - 58) {
          expect(content.center.dy, closeTo((24 + size.height - 34) / 2, 1));
        }
        await tester.ensureVisible(find.byType(OutlinedButton));
        await tester.pumpAndSettle();
        expect(find.byType(OutlinedButton).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('small phone supports large text without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const HomeScreen(),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Sao lưu / Khôi phục'));
    await tester.pumpAndSettle();
    expect(find.text('Sao lưu / Khôi phục').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
