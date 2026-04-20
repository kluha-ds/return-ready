import 'package:ai_life_admin/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AI Life Admin home renders core MVP shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AiLifeAdminApp());

    expect(find.text('AI Life Admin'), findsWidgets);
    expect(find.text('Capture'), findsWidgets);
    expect(find.text('Inbox'), findsWidgets);
    expect(find.text('Archive'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
