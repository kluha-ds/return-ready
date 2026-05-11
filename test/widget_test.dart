import 'package:flutter_test/flutter_test.dart';
import 'package:return_ready/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots into ReturnReady dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ReturnReadyApp());
    await tester.pumpAndSettle();

    expect(find.text('ReturnReady'), findsWidgets);
    expect(find.text('Money at risk'), findsOneWidget);
    expect(find.text('Launch wedge'), findsOneWidget);
  });
}
