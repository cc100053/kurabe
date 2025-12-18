# Repository Guidelines

## Important:
# Read memory-bank/architecture.md (complete database structure) before writing any code
# Read memory-bank/app-design-document.md before writing any code
# Read memory-bank/schema-diagrams.md for DB schema/RLS context before writing any code
# Update memory-bank/progress.md after completing a major feature or milestone
# Update memory-bank/schema-diagrams.md whenever DB/schema changes

## Project Structure & Module Organization
- App source lives in `lib/` with screens, widgets, services, and providers (Riverpod) split by concern. Platform code is under `android/`, `ios/`.
- Tests are in `test/`. Assets (images, splash) live in `assets/` and platform-specific `android/app/src/main/res/`.
- Key business logic: subscriptions in `lib/services/subscription_service.dart` and `lib/providers/subscription_provider.dart`; paywall UI in `lib/screens/paywall_screen.dart`; location and Supabase RPC helpers in `lib/services/`.

## Build, Test, and Development Commands
- `flutter pub get` — install dependencies.
- `flutter run` — run the app on the attached emulator/device.
- `flutter analyze` — static analysis (clean before submitting).
- `flutter test` — run the Dart test suite.

## Coding Style & Naming Conventions
- Follow standard Dart/Flutter style; analyzer config is minimal (see `analysis_options.yaml`). Prefer descriptive names (`snake_case` files, `camelCase` members, `UpperCamelCase` types).
- Keep UI strings and logic in ASCII unless the file already contains Japanese copy (the app uses both).
- Add comments sparingly; only where intent isn’t obvious. Avoid dead code and unused imports.

## Testing Guidelines
- Place unit/widget tests under `test/`, mirroring `lib/` paths when possible.
- Name tests with clear intent: `it renders paywall card`, `it purchases selected plan`.
- Always run `flutter test` and `flutter analyze` before opening a PR.

## Commit & Pull Request Guidelines
- Use concise, imperative commit messages: `Add package purchase flow`, `Fix location fetch logging`.
- For PRs: include a short summary, testing steps (commands run), and screenshots/gifs for UI changes (e.g., paywall/profile). Link related issues or tasks.

## Security & Configuration Tips
- Secrets/config: set `REVENUECAT_API_KEY` and other keys in `.env`; avoid committing real secrets. Supabase auth is initialized in `lib/main.dart`.
- Android paywall requires `MainActivity` extending `FlutterFragmentActivity` (already in `android/app/src/main/kotlin/com/cc100053/kurabe/MainActivity.kt`).

## Agent-Specific Notes
- When wiring purchases, package IDs currently expected by the custom paywall are `monthly`, `quarterly`, `annual`; keep them in sync with RevenueCat offerings.
- Location/RPC failures can surface as UI fallbacks; check `lib/services/supabase_service.dart` logging before changing UI error states.***
