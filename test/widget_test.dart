
import 'package:flutter_test/flutter_test.dart';
import 'package:medishield1/main.dart';

void main() {
  testWidgets('MediShield app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const MediShieldApp());

    expect(find.text('MediShield'), findsOneWidget);
  });
}
