Progress snapshot

- Wired up
  - Supabase bootstrap with PKCE auth, price record inserts, storage uploads to `price_tags`, and stream-based timeline for `user_id`.
  - Add/Edit flow with smart camera, Gemini 1.5 parsing (product/price/discount/category), tax rate inference, unit/taxed total display, best-price insight via `get_nearby_cheapest`, and Google Places nearby/autocomplete for shops.
  - Community search/insight RPCs (`search_community_prices`, `count_nearby_community_prices`, `get_nearby_records_by_category`) with guest/non-Pro gating; personal search by `user_id`.
  - Auth flows: guest/Google/Apple/email, guest-to-user merge (identity_already_exists handled), in-app password reset dialog via deep link; login prompt guards community/shopping list.
  - Subscriptions: RevenueCat configured with entitlement `カイログ Pro`, fallback API key, purchase/restore/paywall/Customer Center entry points; `profiles.is_pro` sync for RLS.
  - Shopping list: Japanese-only list UI with add/toggle/delete and swipe-to-delete; backend `shopping_list_items` with user-scoped RLS supports guests via anonymous uid.
  - UI/UX overhaul: premium teal/cream system, animated bottom nav + gradient FAB, glassmorphism category cards, rich empty/error states, product detail sheet with community chips.
  - Places/shops: Nearby store fetch with custom filtering plus Autocomplete + Place Details to capture lat/lng; cached location/shop hints via `LocationService`.

- Database state
  - Tables: `price_records` (includes quantity, original_price, price_type, discount_type/value, tax_rate, user_id), `profiles` (is_pro), `shopping_list_items`.
  - Policies: price_records insert all; select own or Pro; update/delete own. Shopping list CRUD scoped to auth.uid (works for anonymous). Storage `price_tags` allows public upload/read. RPCs deployed as SQL functions.

- Outstanding / next checks
  - Confirm `price_records.user_id` and `tax_rate` columns exist in all environments; backfill null tax_rate to 0.10 and rerun migrations as needed.
  - Ensure Supabase RLS and triggers match production (user_id defaults, guest-to-user transfer function).
  - Deploy/verify `shopping_list_items` table + policies in production and smoke test list CRUD for guests and signed-in users.
  - Keep RevenueCat package identifiers (`monthly`, `quarterly`, `annual`) aligned with dashboard offerings; run purchase/restore/paywall regression.
  - Run `flutter analyze` and `flutter test` before release; perform end-to-end capture → save → community search → paywall flows after backend changes.
