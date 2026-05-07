import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_data.dart';
import 'models.dart';
import 'planner.dart';

void main() {
  runApp(const FoodPlannerApp());
}

class FoodPlannerApp extends StatelessWidget {
  const FoodPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Home Food Planner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F7A33)),
        useMaterial3: true,
      ),
      home: const PlannerHomePage(),
    );
  }
}

class PlannerHomePage extends StatefulWidget {
  const PlannerHomePage({super.key});

  @override
  State<PlannerHomePage> createState() => _PlannerHomePageState();
}

class _PlannerHomePageState extends State<PlannerHomePage> {
  static const _prefsKey = 'food_planner_state_v1';

  PlannerState _state = seedPlannerState();
  bool _loading = true;
  PlanBundle? _bundle;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    setState(() {
      _state = saved == null ? seedPlannerState() : PlannerState.decode(saved);
      _bundle = _state.plan.isEmpty
          ? null
          : buildPlan(preferences: _state.preferences, pantry: _state.pantry);
      _loading = false;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _state.encode());
  }

  Future<void> _generatePlan() async {
    final bundle = buildPlan(
      preferences: _state.preferences,
      pantry: _state.pantry,
    );
    setState(() {
      _bundle = bundle;
      _state = _state.copyWith(plan: bundle.meals, lastPlanSummary: bundle.summary);
      _tab = 2;
    });
    await _persist();
  }

  Future<void> _reroll(PlannedMeal meal, MealAdjustmentType adjustment, {String? argument}) async {
    if (_bundle == null) return;
    final updated = _state.plan.map((existing) {
      if (existing.templateId != meal.templateId) return existing;
      return rerollMeal(
        currentMeal: meal,
        pantry: _state.pantry,
        preferences: _state.preferences,
        existingMeals: _state.plan,
        adjustment: adjustment,
        argument: argument,
      );
    }).toList();
    final summaryBundle = PlanBundle(
      meals: updated,
      shoppingList: buildShoppingList(updated),
      leftovers: buildLeftoverSummary(updated, _state.pantry),
      clarifiers: suggestClarifiers(_state.pantry, updated),
      summary: 'Updated one meal and refreshed your shopping list.',
    );
    setState(() {
      _bundle = summaryBundle;
      _state = _state.copyWith(plan: updated, lastPlanSummary: summaryBundle.summary);
    });
    await _persist();
  }

  void _addPantryItem(PantryItem item) {
    setState(() {
      _state = _state.copyWith(pantry: [..._state.pantry, item]);
    });
    _persist();
  }

  void _removePantryItem(PantryItem item) {
    setState(() {
      _state = _state.copyWith(
        pantry: _state.pantry.where((candidate) => candidate.id != item.id).toList(),
      );
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      SetupScreen(
        preferences: _state.preferences,
        onChanged: (preferences) {
          setState(() => _state = _state.copyWith(preferences: preferences));
          _persist();
        },
        onContinue: () => setState(() => _tab = 1),
      ),
      PantryScreen(
        pantry: _state.pantry,
        onAdd: _addPantryItem,
        onRemove: _removePantryItem,
        onGenerate: _generatePlan,
      ),
      PlanScreen(
        plan: _state.plan,
        summary: _state.lastPlanSummary,
        clarifiers: _bundle?.clarifiers ?? const [],
        onViewMeal: _showMealDetails,
      ),
      ShoppingScreen(bundle: _bundle),
      LeftoversScreen(bundle: _bundle),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Home Food Planner'),
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.tune), label: 'Setup'),
          NavigationDestination(icon: Icon(Icons.kitchen), label: 'Pantry'),
          NavigationDestination(icon: Icon(Icons.calendar_view_week), label: 'Plan'),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Shop'),
          NavigationDestination(icon: Icon(Icons.eco), label: 'Leftovers'),
        ],
      ),
    );
  }

  Future<void> _showMealDetails(PlannedMeal meal) async {
    final action = await showModalBottomSheet<_MealAction>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MealDetailSheet(meal: meal),
    );
    if (action == null) return;
    await _reroll(meal, action.type, argument: action.argument);
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.preferences,
    required this.onChanged,
    required this.onContinue,
  });

  final Preferences preferences;
  final ValueChanged<Preferences> onChanged;
  final VoidCallback onContinue;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final TextEditingController _exclusionsController;
  late final TextEditingController _dislikesController;

  @override
  void initState() {
    super.initState();
    _exclusionsController = TextEditingController(text: widget.preferences.exclusions.join(', '));
    _dislikesController = TextEditingController(text: widget.preferences.dislikes.join(', '));
  }

  @override
  void dispose() {
    _exclusionsController.dispose();
    _dislikesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.preferences;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plan 3 to 5 realistic dinners in under 5 minutes.', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Pantry-first planning, conservative shopping lists, and simple leftovers guidance.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          title: Text('Household size: ${p.householdSize}'),
          subtitle: Slider(
            min: 1,
            max: 6,
            divisions: 5,
            value: p.householdSize.toDouble(),
            onChanged: (value) => widget.onChanged(p.copyWith(householdSize: value.round())),
          ),
        ),
        ListTile(
          title: Text('Dinners this week: ${p.dinnerCount}'),
          subtitle: Slider(
            min: 3,
            max: 5,
            divisions: 2,
            value: p.dinnerCount.toDouble(),
            onChanged: (value) => widget.onChanged(p.copyWith(dinnerCount: value.round())),
          ),
        ),
        DropdownButtonFormField<PlanMode>(
          initialValue: p.planMode,
          decoration: const InputDecoration(labelText: 'Planning mode'),
          items: PlanMode.values.map((mode) => DropdownMenuItem(value: mode, child: Text(mode.name))).toList(),
          onChanged: (value) => widget.onChanged(p.copyWith(planMode: value)),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<DietType>(
          initialValue: p.dietType,
          decoration: const InputDecoration(labelText: 'Diet'),
          items: DietType.values.map((diet) => DropdownMenuItem(value: diet, child: Text(diet.name))).toList(),
          onChanged: (value) => widget.onChanged(p.copyWith(dietType: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: p.likesLeftovers,
          title: const Text('Prefer leftovers'),
          onChanged: (value) => widget.onChanged(p.copyWith(likesLeftovers: value)),
        ),
        TextField(
          controller: _exclusionsController,
          decoration: const InputDecoration(labelText: 'Allergies/exclusions', hintText: 'peanuts, shellfish'),
          onChanged: (value) => widget.onChanged(p.copyWith(exclusions: _splitCsv(value))),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dislikesController,
          decoration: const InputDecoration(labelText: 'Dislikes', hintText: 'mushrooms, olives'),
          onChanged: (value) => widget.onChanged(p.copyWith(dislikes: _splitCsv(value))),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: widget.onContinue, child: const Text('Continue to pantry')),
      ],
    );
  }
}

class PantryScreen extends StatelessWidget {
  const PantryScreen({
    super.key,
    required this.pantry,
    required this.onAdd,
    required this.onRemove,
    required this.onGenerate,
  });

  final List<PantryItem> pantry;
  final ValueChanged<PantryItem> onAdd;
  final ValueChanged<PantryItem> onRemove;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pantry snapshot', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Add 3 to 10 items for the strongest pantry-first plan. Quantities stay loose on purpose.'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kPantrySuggestions.map((item) {
                    return ActionChip(
                      label: Text(item),
                      onPressed: pantry.any((existing) => existing.name == item)
                          ? null
                          : () => onAdd(PantryItem(
                              id: DateTime.now().microsecondsSinceEpoch.toString(),
                              name: item,
                              quantityState: QuantityState.some,
                              urgency: const {'spinach', 'broccoli', 'chicken'}.contains(item)
                                  ? ItemUrgency.useSoon
                                  : ItemUrgency.unknown,
                            )),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showPhotoSuggestionSheet(context, onAdd),
                  icon: const Icon(Icons.photo_camera_back_outlined),
                  label: const Text('Photo suggestions only'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...pantry.map(
          (item) => Card(
            child: ListTile(
              title: Text(item.name),
              subtitle: Text('${item.quantityState.name} • ${item.urgency.name}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onRemove(item),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: onGenerate, child: const Text('Generate plan')),
      ],
    );
  }

  Future<void> _showPhotoSuggestionSheet(BuildContext context, ValueChanged<PantryItem> onAdd) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Suggested from photo', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Prototype behavior: these are suggestions only, nothing is added until you confirm it.'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['spinach', 'yogurt', 'carrots'].map((name) {
                  return FilledButton.tonal(
                    onPressed: () {
                      onAdd(PantryItem(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        name: name,
                        quantityState: QuantityState.some,
                        urgency: name == 'spinach' ? ItemUrgency.useSoon : ItemUrgency.unknown,
                      ));
                      Navigator.pop(context);
                    },
                    child: Text('Add $name'),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlanScreen extends StatelessWidget {
  const PlanScreen({
    super.key,
    required this.plan,
    required this.summary,
    required this.clarifiers,
    required this.onViewMeal,
  });

  final List<PlannedMeal> plan;
  final String summary;
  final List<Clarifier> clarifiers;
  final ValueChanged<PlannedMeal> onViewMeal;

  @override
  Widget build(BuildContext context) {
    if (plan.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(child: ListTile(title: Text('No plan yet'), subtitle: Text('Generate your weekly dinners from the pantry tab.'))),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(child: ListTile(title: const Text('Weekly plan'), subtitle: Text(summary))),
        if (clarifiers.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Planned with current pantry info', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...clarifiers.map((clarifier) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.help_outline),
                        title: Text(clarifier.question),
                        subtitle: Text(clarifier.impact),
                      )),
                ],
              ),
            ),
          ),
        ...plan.map((meal) => Card(
              child: ListTile(
                title: Text(meal.title),
                subtitle: Text('${meal.rationale}\n${meal.minutes} min • ${meal.pattern}'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onViewMeal(meal),
              ),
            )),
      ],
    );
  }
}

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key, required this.bundle});

  final PlanBundle? bundle;

  @override
  Widget build(BuildContext context) {
    if (bundle == null) {
      return const Center(child: Text('Generate a plan to see the gap-only shopping list.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: bundle!.shoppingList.entries.map((entry) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key.name.toUpperCase(), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...entry.value.map((item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name),
                      subtitle: Text(item.quantity),
                      trailing: item.isCheckIfHave ? const Chip(label: Text('check if you have')) : null,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class LeftoversScreen extends StatelessWidget {
  const LeftoversScreen({super.key, required this.bundle});

  final PlanBundle? bundle;

  @override
  Widget build(BuildContext context) {
    if (bundle == null) {
      return const Center(child: Text('Generate a plan to see leftovers guidance.'));
    }
    final leftovers = bundle!.leftovers;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Likely used up', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(leftovers.likelyUsedUp.isEmpty ? 'Nothing clearly used up yet.' : leftovers.likelyUsedUp.join(', ')),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Likely remaining', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(leftovers.likelyRemaining.join(', ')),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Follow-on ideas', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...leftovers.suggestions.map((tip) => ListTile(contentPadding: EdgeInsets.zero, title: Text(tip))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MealDetailSheet extends StatelessWidget {
  const MealDetailSheet({super.key, required this.meal});

  final PlannedMeal meal;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meal.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(meal.rationale),
              const SizedBox(height: 12),
              Text('Pantry used: ${meal.pantryUsed.join(', ')}'),
              const SizedBox(height: 8),
              Text('Buy needed: ${meal.buyNeeded.map((item) => item.name).join(', ')}'),
              if (meal.checkIfYouHave.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Check if you have: ${meal.checkIfYouHave.map((item) => item.name).join(', ')}'),
              ],
              const SizedBox(height: 12),
              Text('Simple steps', style: Theme.of(context).textTheme.titleMedium),
              ...meal.steps.asMap().entries.map((entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(radius: 12, child: Text('${entry.key + 1}')),
                    title: Text(entry.value),
                  )),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _actionButton(context, 'Swap this meal', MealAdjustmentType.swap),
                  _actionButton(context, 'Make cheaper', MealAdjustmentType.cheaper),
                  _actionButton(context, 'Make faster', MealAdjustmentType.faster),
                  _actionButton(context, 'Avoid spinach', MealAdjustmentType.avoidIngredient, argument: 'spinach'),
                  _actionButton(context, 'Use more rice', MealAdjustmentType.useMoreOfItem, argument: 'rice'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext context, String label, MealAdjustmentType type, {String? argument}) {
    return FilledButton.tonal(
      onPressed: () => Navigator.pop(context, _MealAction(type, argument)),
      child: Text(label),
    );
  }
}

class _MealAction {
  const _MealAction(this.type, this.argument);

  final MealAdjustmentType type;
  final String? argument;
}

List<String> _splitCsv(String value) => value
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();
