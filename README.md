# AI Life Admin Copilot

Flutter mobile MVP for the final spec.

## What changed in this QA fix
- added a real Gmail OAuth path via `google_sign_in` plus Gmail API read-only scopes
- added recent-window inbox scanning and refresh flows
- added active-session monitoring that refreshes a live Gmail inbox every 6 hours while the app remains open
- added an extraction/classification pipeline that turns Gmail messages into the closed v1 task taxonomy
- added deduplication across related renewal/service emails
- added native reminder scheduling and weekly digest notification scheduling, plus runtime notification permission requests
- promoted the mobile app off the default scaffold package ids to `com.kluhads.ai_life_admin` and `com.kluhads.aiLifeAdmin`
- expanded tests beyond app boot to cover extraction, ranking, and explicit demo-mode fallback behavior

## Notes
- Demo inbox mode is now explicit. If Google auth is unavailable locally, the app stays visibly disconnected from live Gmail and labels the queue as demo data instead of pretending a real inbox is connected.
- Outbound actions remain draft-first and every queue item keeps evidence visible before action.
- Replace the placeholder iOS URL scheme in `ios/Runner/Info.plist` with the real reversed client ID from your Google OAuth setup before shipping.

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
