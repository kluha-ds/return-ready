# ReturnReady

ReturnReady is a mobile-first Flutter MVP for shoppers who do not want to miss return deadlines or forget unfinished refunds.

## MVP included here

- responsive dashboard with urgency-first triage
- orders inbox with All, Action Needed, Waiting for Refund, and Refunded filters
- manual order entry and editing
- Gmail onboarding flow with sample imported orders
- order-level lifecycle from Tracked to Refunded
- confirmed, estimated, and unknown deadline states
- refund follow-up timing guidance and optional proof attachment
- local persistence with SharedPreferences

## Product message

**Never miss a return window, and do not forget unfinished refunds.**

## Run

```bash
flutter pub get
flutter run
```

## Notes

This repo implements the final product spec as a self-contained Flutter MVP prototype. Gmail import is represented as an onboarding/demo flow rather than a live API integration, which keeps the build aligned to MVP trust and manual fallback requirements.
