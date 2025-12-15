# Kurabe

カイログ is a Flutter app for price comparison. Snap a price tag, let Gemini parse the details, and save to Supabase. Browse your own records or nearby community finds by category with best-price hints. RevenueCat powers subscriptions for “カイログ Pro” to unlock community data and paywalls.

## ✨ Design

Premium, modern UI inspired by Airbnb, Headspace, and Japanese fintech apps (PayPay, Kyash).

- **Design System**: Custom `KurabeColors` palette with teal primary, warm cream surfaces, Noto Sans JP typography
- **Navigation**: Symmetric bottom nav with animated pill indicators, gradient FAB with layered shadows
- **Iconography**: Phosphor Icons (navigation, categories), Lucide (beef), Material Symbols (bento)
- **Shopping List**: Japanese-only tab with add/toggle/delete and Supabase sync
- **Branding**: App/bundle ID `com.cc100053.kurabe`, app name 「カイログ」, custom icon and splash using `assets/images/icon_square.png`

## Features

- **Smart Add/Edit**: Camera capture, AI tag parsing (Gemini 1.5), discounts, quantity, unit price, taxed total, best-price check
- **Supabase Backend**: `price_records` table with user_id scoping, image uploads to `price_tags` bucket
- **Auth**: Guest, Google, Apple, email; guest-to-user data migration (existing-email login keeps you in-app and merges guest data)
- **Shopping List**: Available to guests; items synced in Supabase using anonymous user id and carry over when you link/login
- **Recovery**: Forgot-password email triggers in-app reset dialog via Supabase deep link; existing-email login for guests to merge data
- **Catalog**: Categories grid with glassmorphism cards, category detail with "My Records" vs "Community Nearby" toggle, confirmation counts, cheapest badge per product
- **Search**: Fuzzy product search RPC, community search gated for registered users
- **Shop assist**: Location-biased Places nearby fetch plus Autocomplete (New) suggestions sorted by distance; Place Details populates lat/lng on selection
- **Profile**: Gradient header, stats dashboard, grouped settings
- **Shopping List**: Personal買い物リスト with add/toggle/delete and swipe-to-delete; guest users see login prompt
- **Subscriptions**: RevenueCat integration (paywall + Customer Center) with entitlement `カイログ Pro`; non-Pro see community counts, Pro see full data

## Getting Started

1) Copy env file  
```bash
cp .env.example .env
```

2) Fill secrets in `.env`  
- `SUPABASE_URL`, `SUPABASE_ANON_KEY` (from Supabase Project Settings → API)  
- `GEMINI_API_KEY` (Google Generative AI)  
- `GOOGLE_PLACES_API_KEY` (for shop lookup/location assist)
- `REVENUECAT_API_KEY` (RevenueCat public SDK key; test key works for sandbox: `test_RVGeIzWYzfusuOXUuNwueYEhskf`)

3) Install deps and run  
```bash
flutter pub get
flutter run
```

## Dependencies

Key packages:
- `supabase_flutter` - Backend & auth
- `google_fonts` - Noto Sans JP typography
- `phosphor_flutter` - Modern iconography
- `cached_network_image` - Image caching
- `geolocator` - Location services
- `image_picker` - Camera/gallery access
- `purchases_flutter`, `purchases_ui_flutter` - RevenueCat subscriptions, paywalls, Customer Center

## Supabase Notes

- Required tables/RPCs: `price_records` (see progress.md for columns) and RPCs `get_nearby_cheapest`, `search_products_fuzzy`, `get_nearby_records_by_category`, `transfer_guest_data`
- Shopping list: add table `shopping_list_items` (id bigserial PK, user_id uuid FK auth.users not null, title text not null, is_done bool default false, created_at timestamptz default now()) with RLS allowing select/insert/update/delete when `auth.uid() = user_id`. Anonymous users also write with their auth.uid (Supabase anonymous session), so keep the same policy.
- Auth redirect setup: keep `io.supabase.flutter://login-callback/` and the Supabase hosted callback in Supabase Auth → Redirect URLs; iOS Info.plist registers the `io.supabase.flutter` scheme for handoff. Password recovery uses the same redirect and is handled in-app.
- Community endpoints expect authenticated users (anon is blocked in-app). RLS (price_records) allows insert all; select if user_id = auth.uid() or profiles.is_pro; update/delete only if user_id = auth.uid(). `profiles` table (id uuid FK auth.users, is_pro bool default false) has self-only select/insert/update.
- Storage bucket `price_tags` must allow authenticated uploads; public read is used for image URLs
- Tax: app sends `is_tax_included` and `tax_rate` (0.08 for 飲食料品, 0.10 otherwise). Add `tax_rate real not null default 0.10` to `price_records` to persist it.

## RevenueCat Setup

- Dashboard: Create entitlement `カイログ Pro`. Create products `monthly`, `yearly`, `lifetime` in App Store/Play, add them to an offering (e.g., “default”), attach a Paywall if you want prebuilt UI.
- App: Set `REVENUECAT_API_KEY` in `.env`. The app initializes RevenueCat early, syncs `is_pro` to Supabase `profiles`, and gates community views. Paywall screen includes:
  - Subscribe/Restore
  - Open RevenueCat Paywall (prebuilt)
  - Customer Center (manage/cancel/restore)
- Gating: non-Pro sees only their data plus a “locked” card with community counts; Pro unlocks full community records and insights.

## Troubleshooting

- **Auth key errors**: Verify `.env` uses the current Supabase anon key and correct URL; restart the app after edits
- **Location issues**: Community view requires location permission; cheapest badge uses per-product grouping client-side
- **Build issues**: Ensure Flutter SDK 3.9.x+ and run `flutter pub get` after pulling

## Screenshots

| Timeline | Catalog | Profile |
|----------|---------|---------|
| Emoji greeting, date badge | Glassmorphism categories | Gradient header, stats card |

## License

MIT
