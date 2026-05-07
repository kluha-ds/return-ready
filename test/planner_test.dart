import 'package:ai_life_admin/demo_data.dart';
import 'package:ai_life_admin/models.dart';
import 'package:ai_life_admin/planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('planner prefers pantry reuse and builds grouped shopping list', () {
    final state = seedPlannerState();
    final bundle = buildPlan(preferences: state.preferences, pantry: state.pantry);

    expect(bundle.meals, hasLength(4));
    expect(bundle.meals.any((meal) => meal.pantryUsed.contains('spinach')), isTrue);
    expect(bundle.shoppingList.keys, isNotEmpty);
  });

  test('reroll use more of item biases toward that ingredient', () {
    final state = seedPlannerState();
    final bundle = buildPlan(preferences: state.preferences, pantry: state.pantry);
    final updated = rerollMeal(
      currentMeal: bundle.meals.first,
      pantry: state.pantry,
      preferences: state.preferences,
      existingMeals: bundle.meals,
      adjustment: MealAdjustmentType.useMoreOfItem,
      argument: 'rice',
    );

    expect(updated.ingredients.any((item) => item.name == 'rice'), isTrue);
  });
}
