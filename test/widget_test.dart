import 'package:ai_home_food_planner/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots into AI Home Food Planner', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FoodPlannerApp());
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('AI Home Food Planner'), findsOneWidget);
    expect(
      find.text('Plan 3 to 5 realistic dinners in under 5 minutes.'),
      findsOneWidget,
    );
  });
}
