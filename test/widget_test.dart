import 'package:flutter_test/flutter_test.dart';
import 'package:lsy_m_lotto/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const LottoApp());
    expect(find.text('번호 추천'), findsOneWidget);
  });
}
