import 'dart:convert';

enum QuantityState { full, some, low }

enum ItemUrgency { useSoon, shelfStable, unknown }

enum PlanMode { balanced, cheapest, fastest, healthier }

enum DietType { anything, vegetarian }

enum MealAdjustmentType {
  swap,
  cheaper,
  faster,
  avoidIngredient,
  useMoreOfItem,
}

enum Aisle { produce, dairy, protein, pantry, frozen, bakery, other }

class Preferences {
  const Preferences({
    required this.householdSize,
    required this.dinnerCount,
    required this.planMode,
    required this.dietType,
    required this.likesLeftovers,
    required this.exclusions,
    required this.dislikes,
  });

  final int householdSize;
  final int dinnerCount;
  final PlanMode planMode;
  final DietType dietType;
  final bool likesLeftovers;
  final List<String> exclusions;
  final List<String> dislikes;

  Preferences copyWith({
    int? householdSize,
    int? dinnerCount,
    PlanMode? planMode,
    DietType? dietType,
    bool? likesLeftovers,
    List<String>? exclusions,
    List<String>? dislikes,
  }) {
    return Preferences(
      householdSize: householdSize ?? this.householdSize,
      dinnerCount: dinnerCount ?? this.dinnerCount,
      planMode: planMode ?? this.planMode,
      dietType: dietType ?? this.dietType,
      likesLeftovers: likesLeftovers ?? this.likesLeftovers,
      exclusions: exclusions ?? this.exclusions,
      dislikes: dislikes ?? this.dislikes,
    );
  }

  Map<String, dynamic> toJson() => {
    'householdSize': householdSize,
    'dinnerCount': dinnerCount,
    'planMode': planMode.name,
    'dietType': dietType.name,
    'likesLeftovers': likesLeftovers,
    'exclusions': exclusions,
    'dislikes': dislikes,
  };

  factory Preferences.fromJson(Map<String, dynamic> json) {
    return Preferences(
      householdSize: json['householdSize'] as int? ?? 2,
      dinnerCount: json['dinnerCount'] as int? ?? 4,
      planMode: PlanMode.values.byName(
        json['planMode'] as String? ?? PlanMode.balanced.name,
      ),
      dietType: DietType.values.byName(
        json['dietType'] as String? ?? DietType.anything.name,
      ),
      likesLeftovers: json['likesLeftovers'] as bool? ?? true,
      exclusions: ((json['exclusions'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      dislikes: ((json['dislikes'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  static const seed = Preferences(
    householdSize: 2,
    dinnerCount: 4,
    planMode: PlanMode.balanced,
    dietType: DietType.anything,
    likesLeftovers: true,
    exclusions: <String>[],
    dislikes: <String>[],
  );
}

class PantryItem {
  const PantryItem({
    required this.id,
    required this.name,
    required this.quantityState,
    required this.urgency,
  });

  final String id;
  final String name;
  final QuantityState quantityState;
  final ItemUrgency urgency;

  PantryItem copyWith({
    String? id,
    String? name,
    QuantityState? quantityState,
    ItemUrgency? urgency,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantityState: quantityState ?? this.quantityState,
      urgency: urgency ?? this.urgency,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantityState': quantityState.name,
    'urgency': urgency.name,
  };

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    return PantryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      quantityState: QuantityState.values.byName(
        json['quantityState'] as String? ?? QuantityState.some.name,
      ),
      urgency: ItemUrgency.values.byName(
        json['urgency'] as String? ?? ItemUrgency.unknown.name,
      ),
    );
  }
}

class MealIngredient {
  const MealIngredient({
    required this.name,
    required this.quantity,
    required this.aisle,
    this.optionalStaple = false,
  });

  final String name;
  final String quantity;
  final Aisle aisle;
  final bool optionalStaple;

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'aisle': aisle.name,
    'optionalStaple': optionalStaple,
  };

  factory MealIngredient.fromJson(Map<String, dynamic> json) {
    return MealIngredient(
      name: json['name'] as String,
      quantity: json['quantity'] as String,
      aisle: Aisle.values.byName(json['aisle'] as String),
      optionalStaple: json['optionalStaple'] as bool? ?? false,
    );
  }
}

class MealTemplate {
  const MealTemplate({
    required this.id,
    required this.title,
    required this.pattern,
    required this.minutes,
    required this.costRank,
    required this.healthRank,
    required this.ingredients,
    required this.steps,
    required this.tags,
    this.vegetarian = false,
  });

  final String id;
  final String title;
  final String pattern;
  final int minutes;
  final int costRank;
  final int healthRank;
  final List<MealIngredient> ingredients;
  final List<String> steps;
  final List<String> tags;
  final bool vegetarian;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'pattern': pattern,
    'minutes': minutes,
    'costRank': costRank,
    'healthRank': healthRank,
    'ingredients': ingredients.map((item) => item.toJson()).toList(),
    'steps': steps,
    'tags': tags,
    'vegetarian': vegetarian,
  };

  factory MealTemplate.fromJson(Map<String, dynamic> json) {
    return MealTemplate(
      id: json['id'] as String,
      title: json['title'] as String,
      pattern: json['pattern'] as String,
      minutes: json['minutes'] as int,
      costRank: json['costRank'] as int,
      healthRank: json['healthRank'] as int,
      ingredients: ((json['ingredients'] as List?) ?? const [])
          .map((item) => MealIngredient.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      steps: ((json['steps'] as List?) ?? const []).map((item) => item.toString()).toList(),
      tags: ((json['tags'] as List?) ?? const []).map((item) => item.toString()).toList(),
      vegetarian: json['vegetarian'] as bool? ?? false,
    );
  }
}

class PlannedMeal {
  const PlannedMeal({
    required this.templateId,
    required this.title,
    required this.pattern,
    required this.rationale,
    required this.minutes,
    required this.ingredients,
    required this.steps,
    required this.pantryUsed,
    required this.buyNeeded,
    required this.checkIfYouHave,
    required this.usedSoonItems,
  });

  final String templateId;
  final String title;
  final String pattern;
  final String rationale;
  final int minutes;
  final List<MealIngredient> ingredients;
  final List<String> steps;
  final List<String> pantryUsed;
  final List<MealIngredient> buyNeeded;
  final List<MealIngredient> checkIfYouHave;
  final List<String> usedSoonItems;

  Map<String, dynamic> toJson() => {
    'templateId': templateId,
    'title': title,
    'pattern': pattern,
    'rationale': rationale,
    'minutes': minutes,
    'ingredients': ingredients.map((item) => item.toJson()).toList(),
    'steps': steps,
    'pantryUsed': pantryUsed,
    'buyNeeded': buyNeeded.map((item) => item.toJson()).toList(),
    'checkIfYouHave': checkIfYouHave.map((item) => item.toJson()).toList(),
    'usedSoonItems': usedSoonItems,
  };

  factory PlannedMeal.fromJson(Map<String, dynamic> json) {
    return PlannedMeal(
      templateId: json['templateId'] as String,
      title: json['title'] as String,
      pattern: json['pattern'] as String,
      rationale: json['rationale'] as String,
      minutes: json['minutes'] as int,
      ingredients: ((json['ingredients'] as List?) ?? const [])
          .map((item) => MealIngredient.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      steps: ((json['steps'] as List?) ?? const []).map((item) => item.toString()).toList(),
      pantryUsed: ((json['pantryUsed'] as List?) ?? const []).map((item) => item.toString()).toList(),
      buyNeeded: ((json['buyNeeded'] as List?) ?? const [])
          .map((item) => MealIngredient.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      checkIfYouHave: ((json['checkIfYouHave'] as List?) ?? const [])
          .map((item) => MealIngredient.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      usedSoonItems: ((json['usedSoonItems'] as List?) ?? const []).map((item) => item.toString()).toList(),
    );
  }
}

class ShoppingListItem {
  const ShoppingListItem({
    required this.name,
    required this.quantity,
    required this.aisle,
    required this.isCheckIfHave,
  });

  final String name;
  final String quantity;
  final Aisle aisle;
  final bool isCheckIfHave;
}

class LeftoverSummary {
  const LeftoverSummary({
    required this.likelyUsedUp,
    required this.likelyRemaining,
    required this.suggestions,
  });

  final List<String> likelyUsedUp;
  final List<String> likelyRemaining;
  final List<String> suggestions;
}

class Clarifier {
  const Clarifier({required this.question, required this.impact});

  final String question;
  final String impact;
}

class PlannerState {
  const PlannerState({
    required this.preferences,
    required this.pantry,
    required this.plan,
    required this.lastPlanSummary,
  });

  final Preferences preferences;
  final List<PantryItem> pantry;
  final List<PlannedMeal> plan;
  final String lastPlanSummary;

  PlannerState copyWith({
    Preferences? preferences,
    List<PantryItem>? pantry,
    List<PlannedMeal>? plan,
    String? lastPlanSummary,
  }) {
    return PlannerState(
      preferences: preferences ?? this.preferences,
      pantry: pantry ?? this.pantry,
      plan: plan ?? this.plan,
      lastPlanSummary: lastPlanSummary ?? this.lastPlanSummary,
    );
  }

  Map<String, dynamic> toJson() => {
    'preferences': preferences.toJson(),
    'pantry': pantry.map((item) => item.toJson()).toList(),
    'plan': plan.map((item) => item.toJson()).toList(),
    'lastPlanSummary': lastPlanSummary,
  };

  factory PlannerState.fromJson(Map<String, dynamic> json) {
    return PlannerState(
      preferences: Preferences.fromJson(
        Map<String, dynamic>.from(json['preferences'] as Map? ?? const {}),
      ),
      pantry: ((json['pantry'] as List?) ?? const [])
          .map((item) => PantryItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      plan: ((json['plan'] as List?) ?? const [])
          .map((item) => PlannedMeal.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      lastPlanSummary: json['lastPlanSummary'] as String? ?? '',
    );
  }

  String encode() => jsonEncode(toJson());

  factory PlannerState.decode(String source) =>
      PlannerState.fromJson(Map<String, dynamic>.from(jsonDecode(source) as Map));
}
