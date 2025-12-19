Tech stack

- Platform: Flutter (Dart, Material 3), targeting mobile with portrait lock. Fonts via `google_fonts` (Noto Sans JP).
- State: Riverpod for subscription state; legacy Provider/ChangeNotifier for local price history (`AppState`); direct Supabase auth usage in widgets/services.
- Backend: Supabase (PostgreSQL) with RLS on `price_records`, `profiles`, and `shopping_list_items`; RPCs (`get_nearby_cheapest`, `search_community_prices`, `count_nearby_community_prices`, `search_products_fuzzy`, `get_nearby_records_by_category`); storage bucket `price_tags` for public uploads.
- Auth: Supabase email/password + OAuth (Google/Apple) + anonymous sessions; PKCE configured in `main.dart`; guest-to-user migration logic expected backend-side.
- Subscriptions: RevenueCat (`purchases_flutter`, `purchases_ui_flutter`) with entitlement `カイログ Pro`; package IDs expected: `monthly`, `quarterly`, `annual`; syncs to Supabase `profiles.is_pro`.
- AI: Google Gemini 1.5 Flash (`google_generative_ai`) for price-tag OCR and structured extraction.
- Location & maps: `geolocator` for permission/position; Google Places API (REST) for `searchNearby`, Autocomplete, and Place Details via `http`; `LocationRepository` centralizes permission prompts, caching, and nearby shop lookups; custom filtering of store types.
- Data & storage: Supabase `price_records`/`shopping_list_items` CRUD via REST; local SQLite (`sqflite`, `path_provider`) for product/shop/price history cache; image upload to Supabase storage; `cached_network_image` for display.
- Data layer structure: Price flow uses `PriceRepository` + `PriceRemoteDataSource` + `PriceRecordMapper`/`PriceCalculator` for typed payloads, best-price checks, and deduplication; `ShoppingListService` covers list CRUD.
- UI libraries: `phosphor_flutter`, `lucide_icons`, Material Symbols; custom widgets for product tiles, paywall, camera overlay; `flutter_image_compress` + `image_picker` for capture.
- Utilities & config: `flutter_dotenv` for secrets, `intl` for JP date formatting, `path` utilities, `provider` legacy interop. Testing via `flutter test`; linting via `flutter analyze`.
