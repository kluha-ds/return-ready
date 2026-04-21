# AI Life Admin Inbox

Flutter MVP prototype for the AI Life Admin Inbox spec.

## Implemented MVP behaviors
- mobile-first capture for pasted text, uploaded PDFs/images, paper scan entry, and forwarded-email simulation
- AI-style intake that classifies captures, extracts key facts, shows confidence, and includes source snippets
- trust-first review flow with user confirmation for critical high-confidence fields
- core workflow views: Needs review, Inbox, Urgent, Upcoming, Waiting, and archived record search
- item detail with plain-language explanation, extracted facts, evidence, and quick actions for reminder, follow-up, archive, and done
- privacy controls for export, source deletion, and local reset

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
