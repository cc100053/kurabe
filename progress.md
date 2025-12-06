Project: Flutter price-comparison app backed by Supabase with AI tag parsing, personal diary views, and community search. UI icons upgraded to Phosphor (nav + categories), Lucide beef for meat, and Material Symbols bento for惣菜.

What’s wired up
- Supabase bootstrap: `supabase_flutter` init in `main.dart` after dotenv; image upload to `price_tags`; inserts into `price_records`.
- Add/Edit flow: Gemini 1.5 prompt extracts product/ raw_price / quantity / discount_info / price_type / category. UI supports quantity, original price, discount type/value, price type, shows unit price + taxed total (pre-tax discounts, 8% tax floor), and saves all new fields; best-price checks use unit price.
- Community insight/search: RPCs for nearby cheapest and fuzzy product search; unit-price sort via updated `get_nearby_cheapest`.
- Auth & profile: Welcome gate with guest, Google, Apple, email. ProfileTab shows user info, hides logout for guests, offers link-with Google/Apple/email; email linking handles “email exists” by signing in and migrating guest data via `transfer_guest_data` RPC; guest reset button added.
- Privacy controls: Timeline and catalog category view filter by `user_id` on the client; community search/nearby cheapest blocked for guests (app-side); guest users prompted to link instead of logout.
- UI/UX: ProductDetailSheet with community insight (gated for guests), catalog tab with categories and gated search, saving dialogs, error SnackBars, and suggestion chips.
 - Category detail community view groups nearby records by product/shop/price/unit price/location, counts confirmations, returns latest record per group via `get_nearby_records_by_category`; UI shows confirmation badge when count > 1 and only marks cheapest per product.

Database/RPC notes
- price_records schema (expected): id (bigint, PK), product_name text, price numeric (stored final taxed total), original_price numeric, quantity integer default 1, price_type text default 'standard', discount_type text default 'none', discount_value numeric default 0, is_tax_included boolean, shop_name text, shop_lat double precision, shop_lng double precision, image_url text, category_tag text, is_best_price boolean, user_id uuid (required for user-scoped reads), created_at timestamptz default now().
- price_records columns added (idempotent): quantity integer default 1, original_price numeric, price_type text default 'standard', discount_type text default 'none', discount_value numeric default 0. Ensure `user_id uuid` exists; app filters on this column.
- get_nearby_cheapest recreated to ORDER BY price / GREATEST(quantity, 1) ASC then distance; fully qualified columns to avoid ambiguity.
- transfer_guest_data(record_ids bigint[]) SECURITY DEFINER updates price_records.user_id = auth.uid() for provided ids.
- RLS currently open for SELECT (USING true) to enable community search; app enforces user-scoped reads for private views.

Remaining
- Confirm `user_id` column exists and is populated on price_records; set RLS policies to enforce user-only reads/writes if desired.
- Re-run Supabase migrations in prod and verify guest-to-user linking + data migration end to end.

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
