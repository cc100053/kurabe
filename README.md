# Kurabe

Kurabe is a Flutter app for price comparison. Snap a price tag, let Gemini parse the details, and save to Supabase. Browse your own records or nearby community finds by category with best-price hints. UI iconography now uses Phosphor Icons (navigation, categories) plus a Lucide beef icon and Material Symbols bento for a modern, high-end look.

## Features
- Smart add/edit: camera capture, AI tag parsing (Gemini 1.5), discounts, quantity, unit price, taxed total, best-price check.
- Supabase backend: price_records table with user_id scoping, image uploads to `price_tags` bucket.
- Auth: guest, Google, Apple, email; guest-to-user data migration.
- Catalog: categories grid, category detail with toggle for “My Records” vs “Community Nearby”, confirmation counts, cheapest badge per product.
- Search: fuzzy product search RPC, community search gated for registered users.

## Getting started
1) Copy env file  
`cp .env.example .env`

2) Fill secrets in `.env`  
- `SUPABASE_URL`, `SUPABASE_ANON_KEY` (from Supabase Project Settings → API)  
- `GEMINI_API_KEY` (Google Generative AI)  
- `GOOGLE_PLACES_API_KEY` (for shop lookup/location assist)

3) Install deps and run  
```bash
flutter pub get
flutter run
```

## Supabase notes
- Required tables/RPCs: `price_records` (see progress.md for columns) and RPCs `get_nearby_cheapest`, `search_products_fuzzy`, `get_nearby_records_by_category`, `transfer_guest_data`.
- Community endpoints expect authenticated users (anon is blocked in-app). Ensure RLS matches your privacy needs.
- Storage bucket `price_tags` must allow authenticated uploads; public read is used for image URLs.

## Troubleshooting
- Auth key errors: verify `.env` uses the current Supabase anon key and correct URL; restart the app after edits.
- Location issues: community view requires location permission; cheapest badge uses per-product grouping client-side.
- Build issues: ensure Flutter SDK 3.9.x+ and run `flutter pub get` after pulling.
