Project: Flutter price-comparison app backed by Supabase with AI tag parsing, personal diary views, and community search. UI icons upgraded to Phosphor (nav + categories), Lucide beef for meat, and Material Symbols bento for惣菜.

What's wired up
- Supabase bootstrap: `supabase_flutter` init in `main.dart` after dotenv; image upload to `price_tags`; inserts into `price_records`.
- Add/Edit flow: Gemini 1.5 prompt extracts product/ raw_price / quantity / discount_info / price_type / category. UI supports quantity, original price, discount type/value, price type, shows unit price + taxed total (pre-tax discounts, 8% tax floor), and saves all new fields; best-price checks use unit price.
- Community insight/search: RPCs for nearby cheapest and fuzzy product search; unit-price sort via updated `get_nearby_cheapest`.
- Auth & profile: Guest/Google/Apple/email, guest-to-user data migration (including identity_already_exists), existing-email login with guest merge (now stays in-app and shows errors inline), in-app password reset dialog on Supabase passwordRecovery deep link.
- Privacy controls: Timeline and catalog category view filter by `user_id` on the client; community search/nearby cheapest blocked for guests (app-side); guest users prompted to link instead of logout.
- UI/UX: ProductDetailSheet with community insight (gated for guests), catalog tab with categories and gated search, saving dialogs, error SnackBars, and suggestion chips.
 - Category detail community view groups nearby records by product/shop/price/unit price/location, counts confirmations, returns latest record per group via `get_nearby_records_by_category`; UI shows confirmation badge when count > 1 and only marks cheapest per product.
- Shopping list: available to guests and synced to Supabase using anonymous user id; same backend table `shopping_list_items` used for all users.

## UI/UX Overhaul (December 2024)

Complete visual redesign transforming Kurabe into a premium, modern app inspired by Airbnb, Headspace, and Japanese fintech apps.

### Design System (`main.dart`)
- **Custom Color Palette**: `KurabeColors` class with deeper teal (#1A8D7A), warm cream surfaces (#FAF9F7), and refined text hierarchy
- **Typography**: Google Fonts Noto Sans JP throughout with optimized weights and letter-spacing
- **Component Themes**: Cards (20px radius), inputs (neumorphic style), buttons (gradient-ready), dialogs, and more

### Navigation (`main_scaffold.dart`)
- **Bottom Nav Bar**: Symmetric layout with Expanded sections, animated pill indicators, labels with font weight transitions
- **Floating Action Button**: 68px with dual-layer gradient and premium shadow effect
- **Page Transitions**: Custom fade + slide animations for scan screen

### Tab Screens
- **Timeline Tab**: Emoji greeting based on time of day, badge-styled date header, gradient date section headers, polished empty states
- **Catalog Tab**: Floating search bar with animated focus, glassmorphism category cards with gradient backgrounds
- **Profile Tab**: Gradient header with avatar camera badge, floating stats card with colored icons, grouped settings tiles

### Shared Widgets
- **CommunityProductTile**: Fire icon on cheapest badge, improved metadata chips with Phosphor icons, social proof badges
- **CategoryDetailScreen**: Custom segmented control, community info banner, consistent empty/error states
- **ProductDetailSheet**: Explicit white background, custom drag handle, improved text contrast

Database/RPC notes
- price_records schema (expected): id (bigint, PK), product_name text, price numeric (stored final taxed total), original_price numeric, quantity integer default 1, price_type text default 'standard', discount_type text default 'none', discount_value numeric default 0, is_tax_included boolean, tax_rate real not null default 0.10, shop_name text, shop_lat double precision, shop_lng double precision, image_url text, category_tag text, is_best_price boolean, user_id uuid (required for user-scoped reads), created_at timestamptz default now().
- price_records columns added (idempotent): quantity integer default 1, original_price numeric, price_type text default 'standard', discount_type text default 'none', discount_value numeric default 0, tax_rate real default 0.10. Ensure `user_id uuid` exists; app filters on this column.
- get_nearby_cheapest recreated to ORDER BY price / GREATEST(quantity, 1) ASC then distance; fully qualified columns to avoid ambiguity.
- transfer_guest_data(record_ids bigint[]) SECURITY DEFINER updates price_records.user_id = auth.uid() for provided ids.
- RLS currently open for SELECT (USING true) to enable community search; app enforces user-scoped reads for private views.

Remaining
- Confirm `user_id` column exists and is populated on price_records; set RLS policies to enforce user-only reads/writes if desired.
- Add `tax_rate real not null default 0.10` to price_records and backfill nulls to 0.10; re-run Supabase migrations in prod and verify guest-to-user linking + data migration end to end.
- Deploy shopping list table/policies in Supabase and smoke test the new tab.
- Bottom nav symmetry completed: 4th tab (Shopping List) added with centered FAB gap and 2-1-2 layout.

Shopping list (new)
- UI: Japanese-only Shopping List tab with add/toggle/delete, pull-to-refresh, and swipe-to-delete; guest users see login prompt.
- Data: `shopping_list_items` table (id bigserial, user_id uuid FK auth.users, title text, is_done bool default false, created_at timestamptz default now()); RLS select/insert/update/delete scoped to auth.uid().
- Service/model: `ShoppingListService` handles fetch/add/toggle/delete; `ShoppingListItem` model.
- Status: Requires Supabase table + policies above; no other backend changes.

Branding/launch
- App/bundle ID updated to `com.cc100053.kurabe` across Android/iOS/macOS/Linux.
- App icon and splash configured to use `assets/images/icon_square.png` via flutter_launcher_icons and flutter_native_splash (run the generators locally).

Current Supabase schema snapshot (price_records)
- id bigint
- created_at timestamptz default timezone('utc', now())
- product_name text
- price numeric
- is_tax_included boolean default false
- shop_name text
- shop_lat double precision
- shop_lng double precision
- image_url text
- category_tag text
- is_best_price boolean default false
- quantity integer default 1
- original_price numeric
- price_type text default 'standard'
- discount_type text default 'none'
- discount_value numeric default 0
- user_id uuid
