import 'models.dart';
import 'demo_data.dart';

class PlanBundle {
  const PlanBundle({
    required this.meals,
    required this.shoppingList,
    required this.leftovers,
    required this.clarifiers,
    required this.summary,
  });

  final List<PlannedMeal> meals;
  final Map<Aisle, List<ShoppingListItem>> shoppingList;
  final LeftoverSummary leftovers;
  final List<Clarifier> clarifiers;
  final String summary;
}

PlanBundle buildPlan({
  required Preferences preferences,
  required List<PantryItem> pantry,
}) {
  final templates = buildMealTemplates();
  final filtered = templates.where((template) {
    if (preferences.dietType == DietType.vegetarian && !template.vegetarian) {
      return false;
    }
    final banned = {
      ...preferences.exclusions,
      ...preferences.dislikes,
    }.map(_normalize).toSet();
    return !template.ingredients.any(
      (item) => banned.contains(_normalize(item.name)),
    );
  }).toList();

  filtered.sort(
    (a, b) => _scoreTemplate(
      b,
      pantry,
      preferences,
    ).compareTo(_scoreTemplate(a, pantry, preferences)),
  );

  final selected = <MealTemplate>[];
  final usedPatterns = <String, int>{};
  for (final template in filtered) {
    if (selected.length == preferences.dinnerCount) break;
    final count = usedPatterns[template.pattern] ?? 0;
    if (count > 0 && selected.length < preferences.dinnerCount - 1) {
      final hasAlternative = filtered.any(
        (candidate) =>
            !selected.contains(candidate) &&
            candidate.pattern != template.pattern,
      );
      if (hasAlternative) continue;
    }
    selected.add(template);
    usedPatterns[template.pattern] = count + 1;
  }

  final meals = selected
      .map((template) => _toPlannedMeal(template, pantry, preferences))
      .toList();
  final shopping = buildShoppingList(meals);
  final leftovers = buildLeftoverSummary(meals, pantry);
  final clarifiers = suggestClarifiers(pantry, meals);
  final summary = meals.isEmpty
      ? 'Add a few pantry items to unlock better pantry-first plans.'
      : 'Built a ${preferences.dinnerCount}-dinner plan around ${_topPantryHits(meals)}.';

  return PlanBundle(
    meals: meals,
    shoppingList: shopping,
    leftovers: leftovers,
    clarifiers: clarifiers,
    summary: summary,
  );
}

int _scoreTemplate(
  MealTemplate template,
  List<PantryItem> pantry,
  Preferences preferences,
) {
  final pantryNames = pantry.map((item) => _normalize(item.name)).toSet();
  final useSoonNames = pantry
      .where((item) => item.urgency == ItemUrgency.useSoon)
      .map((item) => _normalize(item.name))
      .toSet();
  final reuseCount = template.ingredients
      .where((item) => pantryNames.contains(_normalize(item.name)))
      .length;
  final useSoonCount = template.ingredients
      .where((item) => useSoonNames.contains(_normalize(item.name)))
      .length;
  final missingCount = template.ingredients
      .where(
        (item) =>
            !pantryNames.contains(_normalize(item.name)) &&
            !item.optionalStaple,
      )
      .length;

  var score = reuseCount * 12 + useSoonCount * 8 - missingCount * 5;
  switch (preferences.planMode) {
    case PlanMode.cheapest:
      score += (6 - template.costRank) * 4;
      break;
    case PlanMode.fastest:
      score += (40 - template.minutes);
      break;
    case PlanMode.healthier:
      score += template.healthRank * 4;
      break;
    case PlanMode.balanced:
      score += template.healthRank * 2 + (6 - template.costRank) * 2;
      break;
  }
  if (preferences.likesLeftovers && template.tags.contains('leftovers')) {
    score += 3;
  }
  return score;
}

PlannedMeal _toPlannedMeal(
  MealTemplate template,
  List<PantryItem> pantry,
  Preferences preferences,
) {
  final pantryNames = pantry.map((item) => _normalize(item.name)).toSet();
  final useSoonNames = pantry
      .where((item) => item.urgency == ItemUrgency.useSoon)
      .map((item) => _normalize(item.name))
      .toSet();
  final pantryUsed = <String>[];
  final buyNeeded = <MealIngredient>[];
  final checkIfYouHave = <MealIngredient>[];
  final usedSoonItems = <String>[];

  for (final ingredient in template.ingredients) {
    final scaledIngredient = _scaleIngredientForHousehold(
      ingredient,
      preferences.householdSize,
    );
    final normalized = _normalize(ingredient.name);
    if (pantryNames.contains(normalized)) {
      pantryUsed.add(scaledIngredient.name);
      if (useSoonNames.contains(normalized)) {
        usedSoonItems.add(scaledIngredient.name);
      }
    } else if (ingredient.optionalStaple ||
        kStapleIngredients.contains(normalized)) {
      checkIfYouHave.add(scaledIngredient);
    } else {
      buyNeeded.add(scaledIngredient);
    }
  }

  final scaledIngredients = template.ingredients
      .map(
        (ingredient) =>
            _scaleIngredientForHousehold(ingredient, preferences.householdSize),
      )
      .toList();

  final reasonBits = <String>[];
  if (pantryUsed.isNotEmpty) {
    reasonBits.add('uses your ${pantryUsed.take(2).join(' and ')}');
  }
  if (usedSoonItems.isNotEmpty) {
    reasonBits.add('helps use ${usedSoonItems.join(' and ')} soon');
  }
  switch (preferences.planMode) {
    case PlanMode.cheapest:
      reasonBits.add('keeps new purchases modest');
      break;
    case PlanMode.fastest:
      reasonBits.add('ready in ${template.minutes} min');
      break;
    case PlanMode.healthier:
      reasonBits.add('leans lighter for the week');
      break;
    case PlanMode.balanced:
      reasonBits.add('${template.minutes} min weeknight option');
      break;
  }
  reasonBits.add('scaled for ${preferences.householdSize}');

  return PlannedMeal(
    templateId: template.id,
    title: template.title,
    pattern: template.pattern,
    rationale: reasonBits.join(', '),
    minutes: template.minutes,
    ingredients: scaledIngredients,
    steps: template.steps,
    pantryUsed: pantryUsed,
    buyNeeded: buyNeeded,
    checkIfYouHave: checkIfYouHave,
    usedSoonItems: usedSoonItems,
  );
}

MealIngredient _scaleIngredientForHousehold(
  MealIngredient ingredient,
  int householdSize,
) {
  final scaledQuantity = _scaleQuantity(ingredient.quantity, householdSize);
  if (scaledQuantity == ingredient.quantity) {
    return ingredient;
  }
  return MealIngredient(
    name: ingredient.name,
    quantity: scaledQuantity,
    aisle: ingredient.aisle,
    optionalStaple: ingredient.optionalStaple,
  );
}

String _scaleQuantity(String quantity, int householdSize) {
  if (householdSize <= 2) return quantity;
  final match = RegExp(r'^(\d+)\s+(.+)$').firstMatch(quantity.trim());
  if (match == null) return quantity;
  final baseCount = int.tryParse(match.group(1)!);
  final unit = match.group(2)!;
  if (baseCount == null) return quantity;
  final multiplier = householdSize / 2;
  final scaledCount = (baseCount * multiplier).ceil();
  return '$scaledCount $unit';
}

Map<Aisle, List<ShoppingListItem>> buildShoppingList(List<PlannedMeal> meals) {
  final grouped = <Aisle, Map<String, _ShoppingAccumulator>>{};
  void addItem(MealIngredient ingredient, {required bool check}) {
    final aisleMap = grouped.putIfAbsent(ingredient.aisle, () => {});
    final key = _normalize(ingredient.name);
    final accumulator = aisleMap.putIfAbsent(
      key,
      () => _ShoppingAccumulator(
        name: canonicalizeIngredient(ingredient.name),
        aisle: ingredient.aisle,
      ),
    );
    accumulator.add(ingredient.quantity, check: check);
  }

  for (final meal in meals) {
    for (final item in meal.buyNeeded) {
      addItem(item, check: false);
    }
    for (final item in meal.checkIfYouHave) {
      addItem(item, check: true);
    }
  }

  final result = <Aisle, List<ShoppingListItem>>{};
  for (final aisle in grouped.keys) {
    result[aisle] = grouped[aisle]!.values.map((item) => item.build()).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }
  return result;
}

String canonicalizeIngredient(String name) {
  final normalized = _normalize(name);
  switch (normalized) {
    case 'scallions':
      return 'green onions';
    default:
      return name;
  }
}

LeftoverSummary buildLeftoverSummary(
  List<PlannedMeal> meals,
  List<PantryItem> pantry,
) {
  final used = meals.expand((meal) => meal.pantryUsed).map(_normalize).toSet();
  final likelyUsedUp = pantry
      .where(
        (item) =>
            item.urgency == ItemUrgency.useSoon &&
            used.contains(_normalize(item.name)),
      )
      .map((item) => item.name)
      .toList();
  final likelyRemaining = pantry
      .where(
        (item) =>
            !used.contains(_normalize(item.name)) ||
            item.quantityState == QuantityState.full,
      )
      .map((item) => item.name)
      .toSet()
      .toList();

  final suggestions = <String>[];
  if (likelyRemaining.contains('rice')) {
    suggestions.add(
      'Turn leftover rice into quick fried rice later in the week.',
    );
  }
  if (likelyRemaining.contains('spinach')) {
    suggestions.add(
      'Blend extra spinach into eggs or pasta for one more easy meal.',
    );
  }
  if (suggestions.isEmpty) {
    suggestions.add(
      'Use remaining vegetables in a simple soup, omelet, or grain bowl.',
    );
  }

  return LeftoverSummary(
    likelyUsedUp: likelyUsedUp,
    likelyRemaining: likelyRemaining,
    suggestions: suggestions.take(2).toList(),
  );
}

List<Clarifier> suggestClarifiers(
  List<PantryItem> pantry,
  List<PlannedMeal> meals,
) {
  final names = pantry.map((item) => _normalize(item.name)).toSet();
  final clarifiers = <Clarifier>[];
  if (meals.any(
    (meal) =>
        meal.checkIfYouHave.any((item) => _normalize(item.name) == 'soy sauce'),
  )) {
    clarifiers.add(
      const Clarifier(
        question: 'Do you still have soy sauce?',
        impact: 'It changes whether the stir-fry and fried rice stay gap-only.',
      ),
    );
  }
  if (names.contains('spinach')) {
    final spinach = pantry.firstWhere(
      (item) => _normalize(item.name) == 'spinach',
    );
    if (spinach.urgency != ItemUrgency.shelfStable) {
      clarifiers.add(
        const Clarifier(
          question: 'Is your spinach fresh and needs using soon?',
          impact:
              'If yes, keep the spinach meals pinned near the start of the week.',
        ),
      );
    }
  }
  return clarifiers.take(2).toList();
}

PlannedMeal rerollMeal({
  required PlannedMeal currentMeal,
  required List<PantryItem> pantry,
  required Preferences preferences,
  required List<PlannedMeal> existingMeals,
  required MealAdjustmentType adjustment,
  String? argument,
}) {
  final usedIds = existingMeals.map((meal) => meal.templateId).toSet()
    ..remove(currentMeal.templateId);
  final templates = buildMealTemplates().where((template) {
    if (usedIds.contains(template.id)) {
      return false;
    }
    if (preferences.dietType == DietType.vegetarian && !template.vegetarian) {
      return false;
    }
    return true;
  }).toList();

  templates.sort((a, b) {
    final scoreA = _rerollScore(a, pantry, preferences, adjustment, argument);
    final scoreB = _rerollScore(b, pantry, preferences, adjustment, argument);
    return scoreB.compareTo(scoreA);
  });

  final chosen = templates.firstWhere(
    (template) => template.id != currentMeal.templateId,
    orElse: () => buildMealTemplates().firstWhere(
      (template) => template.id == currentMeal.templateId,
    ),
  );
  return _toPlannedMeal(chosen, pantry, preferences);
}

int _rerollScore(
  MealTemplate template,
  List<PantryItem> pantry,
  Preferences preferences,
  MealAdjustmentType adjustment,
  String? argument,
) {
  var score = _scoreTemplate(template, pantry, preferences);
  switch (adjustment) {
    case MealAdjustmentType.swap:
      break;
    case MealAdjustmentType.cheaper:
      score += (6 - template.costRank) * 10;
      break;
    case MealAdjustmentType.faster:
      score += (40 - template.minutes) * 2;
      break;
    case MealAdjustmentType.avoidIngredient:
      if (argument != null &&
          template.ingredients.any(
            (item) => _normalize(item.name).contains(_normalize(argument)),
          )) {
        score -= 1000;
      }
      break;
    case MealAdjustmentType.useMoreOfItem:
      if (argument != null &&
          template.ingredients.any(
            (item) => _normalize(item.name).contains(_normalize(argument)),
          )) {
        score += 100;
      }
      break;
  }
  return score;
}

String _topPantryHits(List<PlannedMeal> meals) {
  final counts = <String, int>{};
  for (final meal in meals) {
    for (final item in meal.pantryUsed) {
      counts[item] = (counts[item] ?? 0) + 1;
    }
  }
  final top = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return top.take(2).map((entry) => entry.key).join(' and ');
}

class _ShoppingAccumulator {
  _ShoppingAccumulator({required this.name, required this.aisle});

  final String name;
  final Aisle aisle;
  bool _isCheckIfHave = false;
  int? _count;
  String? _unit;
  final List<String> _fallbackQuantities = [];

  void add(String quantity, {required bool check}) {
    _isCheckIfHave = _isCheckIfHave || check;
    final parsed = _parseQuantity(quantity);
    if (parsed == null) {
      _fallbackQuantities.add(quantity);
      return;
    }
    if (_count == null && _unit == null) {
      _count = parsed.count;
      _unit = parsed.unit;
      return;
    }
    if (_unit == parsed.unit) {
      _count = (_count ?? 0) + parsed.count;
      return;
    }
    _fallbackQuantities.add(quantity);
  }

  ShoppingListItem build() {
    final quantity = _count == null || _unit == null
        ? _fallbackQuantities.isEmpty
              ? 'check amount'
              : _fallbackQuantities.toSet().join(', ')
        : '${_count!} ${_pluralize(_unit!, _count!)}';
    return ShoppingListItem(
      name: name,
      quantity: quantity,
      aisle: aisle,
      isCheckIfHave: _isCheckIfHave,
    );
  }
}

class _ParsedQuantity {
  const _ParsedQuantity(this.count, this.unit);

  final int count;
  final String unit;
}

_ParsedQuantity? _parseQuantity(String quantity) {
  final match = RegExp(
    r'^(\d+)\s+(.+)$',
  ).firstMatch(quantity.trim().toLowerCase());
  if (match == null) {
    return null;
  }
  final count = int.tryParse(match.group(1)!);
  final rawUnit = match.group(2)!;
  if (count == null) {
    return null;
  }
  final unit = switch (rawUnit) {
    'onion' || 'onions' => 'onion',
    'pepper' || 'peppers' => 'pepper',
    'head' || 'heads' => 'head',
    'bag' || 'bags' => 'bag',
    'box' || 'boxes' => 'box',
    'pack' || 'packs' => 'pack',
    'can' || 'cans' => 'can',
    'bottle' || 'bottles' => 'bottle',
    'bulb' || 'bulbs' => 'bulb',
    'cucumber' || 'cucumbers' => 'cucumber',
    'bunch' || 'bunches' => 'bunch',
    'tub' || 'tubs' => 'tub',
    _ => rawUnit,
  };
  return _ParsedQuantity(count, unit);
}

String _pluralize(String unit, int count) {
  if (count == 1) return unit;
  return switch (unit) {
    'box' => 'boxes',
    'bunch' => 'bunches',
    _ => '${unit}s',
  };
}

String _normalize(String value) => value.trim().toLowerCase();
