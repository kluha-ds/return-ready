import 'package:ai_life_admin/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AI Life Admin app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const AiLifeAdminApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(AiLifeAdminApp), findsOneWidget);
    expect(find.byType(WidgetsApp), findsOneWidget);
  });
}
