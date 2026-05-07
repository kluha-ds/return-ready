import 'package:ai_home_food_planner/demo_data.dart';
import 'package:ai_home_food_planner/models.dart';
import 'package:ai_home_food_planner/planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('planner prefers pantry reuse and builds grouped shopping list', () {
    final state = seedPlannerState();
    final bundle = buildPlan(
      preferences: state.preferences,
      pantry: state.pantry,
    );

    expect(bundle.meals, hasLength(4));
    expect(
      bundle.meals.any((meal) => meal.pantryUsed.contains('spinach')),
      isTrue,
    );
    expect(bundle.shoppingList.keys, isNotEmpty);
  });

  test('shopping list consolidates overlapping ingredients across meals', () {
    final meals = [
      const PlannedMeal(
        templateId: 'a',
        title: 'Meal A',
        pattern: 'Tacos',
        rationale: 'test',
        minutes: 20,
        ingredients: [],
        steps: [],
        pantryUsed: [],
        buyNeeded: [
          MealIngredient(
            name: 'onion',
            quantity: '1 onion',
            aisle: Aisle.produce,
          ),
        ],
        checkIfYouHave: [],
        usedSoonItems: [],
      ),
      const PlannedMeal(
        templateId: 'b',
        title: 'Meal B',
        pattern: 'Soup',
        rationale: 'test',
        minutes: 20,
        ingredients: [],
        steps: [],
        pantryUsed: [],
        buyNeeded: [
          MealIngredient(
            name: 'onion',
            quantity: '1 onion',
            aisle: Aisle.produce,
          ),
        ],
        checkIfYouHave: [],
        usedSoonItems: [],
      ),
    ];

    final shopping = buildShoppingList(meals);
    final onions = shopping[Aisle.produce]!.firstWhere(
      (item) => item.name == 'onion',
    );

    expect(onions.quantity, '2 onions');
  });

  test('reroll use more of item biases toward that ingredient', () {
    final state = seedPlannerState();
    final bundle = buildPlan(
      preferences: state.preferences,
      pantry: state.pantry,
    );
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

  test('planner scales ingredient quantities for larger households', () {
    final state = seedPlannerState().copyWith(
      preferences: seedPlannerState().preferences.copyWith(householdSize: 4),
    );

    final bundle = buildPlan(
      preferences: state.preferences,
      pantry: state.pantry,
    );

    final stirFry = bundle.meals.firstWhere(
      (meal) => meal.templateId == 'chicken_stir_fry',
    );
    final chicken = stirFry.ingredients.firstWhere(
      (item) => item.name == 'chicken',
    );

    expect(chicken.quantity, '2 lb');
    expect(stirFry.rationale, contains('scaled for 4'));
  });
}
