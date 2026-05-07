# AI Home Food Planner

Mobile-first Flutter MVP for pantry-first dinner planning.

## What it does
- collects lightweight household setup and dinner-planning preferences
- captures a rough pantry snapshot with loose quantity and urgency states
- generates a realistic 3 to 5 dinner weekly plan from constrained meal templates
- explains why each meal was chosen
- builds a conservative gap-only shopping list grouped by aisle
- supports single-meal rerolls for swap, cheaper, faster, avoid-ingredient, and use-more-of-item flows
- shows a simple leftover and use-soon summary
- keeps optional photo suggestions clearly suggestion-only

## Product notes
- Pantry tracking is intentionally approximate.
- Staples such as oil and soy sauce may appear as `check if you have` instead of assumed-present.
- The planner uses deterministic template scoring instead of freeform recipe generation.
- State persists locally with `shared_preferences`.

## Run locally
```bash
flutter pub get
flutter run
```

## Verify
```bash
flutter analyze
flutter test
```
