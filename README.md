# Kurabe

Kurabe is a Flutter app for price comparison. Snap a price tag, let Gemini parse the details, and save to Supabase. Browse your own records or nearby community finds by category with best-price hints.

## ✨ Design

Premium, modern UI inspired by Airbnb, Headspace, and Japanese fintech apps (PayPay, Kyash).

- **Design System**: Custom `KurabeColors` palette with teal primary, warm cream surfaces, Noto Sans JP typography
- **Navigation**: Symmetric bottom nav with animated pill indicators, gradient FAB with layered shadows
- **Iconography**: Phosphor Icons (navigation, categories), Lucide (beef), Material Symbols (bento)
- **Shopping List**: Japanese-only tab with add/toggle/delete and Supabase sync

## Features

- **Smart Add/Edit**: Camera capture, AI tag parsing (Gemini 1.5), discounts, quantity, unit price, taxed total, best-price check
- **Supabase Backend**: `price_records` table with user_id scoping, image uploads to `price_tags` bucket
- **Auth**: Guest, Google, Apple, email; guest-to-user data migration
- **Catalog**: Categories grid with glassmorphism cards, category detail with "My Records" vs "Community Nearby" toggle, confirmation counts, cheapest badge per product
- **Search**: Fuzzy product search RPC, community search gated for registered users
- **Profile**: Gradient header, stats dashboard, grouped settings
- **Shopping List**: Personal買い物リスト with add/toggle/delete and swipe-to-delete; guest users see login prompt

## Getting Started

1) Copy env file  
```bash
cp .env.example .env
```

2) Fill secrets in `.env`  
- `SUPABASE_URL`, `SUPABASE_ANON_KEY` (from Supabase Project Settings → API)  
- `GEMINI_API_KEY` (Google Generative AI)  
- `GOOGLE_PLACES_API_KEY` (for shop lookup/location assist)

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

## Supabase Notes

- Required tables/RPCs: `price_records` (see progress.md for columns) and RPCs `get_nearby_cheapest`, `search_products_fuzzy`, `get_nearby_records_by_category`, `transfer_guest_data`
- Shopping list: add table `shopping_list_items` (id bigserial PK, user_id uuid FK auth.users not null, title text not null, is_done bool default false, created_at timestamptz default now()) with RLS allowing select/insert/update/delete when `auth.uid() = user_id`.
- Community endpoints expect authenticated users (anon is blocked in-app). Ensure RLS matches your privacy needs
- Storage bucket `price_tags` must allow authenticated uploads; public read is used for image URLs

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
