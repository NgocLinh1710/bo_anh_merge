import 'package:flutter_test/flutter_test.dart';
import 'package:bo_anh/main.dart';

void main() {
  testWidgets('BơAnh app starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const BoAnhApp());

    expect(find.text('BơAnh Alliance'), findsOneWidget);
    expect(find.text('BẮT ĐẦU CHƠI'), findsOneWidget);
    expect(
      find.text('Xu và tiến độ tự lưu trên trình duyệt này.'),
      findsOneWidget,
    );
    expect(find.text('Đăng nhập với Google'), findsNothing);
  });
}
