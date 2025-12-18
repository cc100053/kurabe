Kurabe app design

- Product vision: Quick price-tag capture in Japanese stores, AI-assisted parsing, and community comparisons that unlock with a Pro subscription. Users snap, confirm details, and build a personal + community-powered catalog.
- Target users: Shoppers in Japan who want fast grocery/household price tracking, with Pro upsell for community insights.
- Core journeys:
  - Onboard & auth: Welcome screen → Supabase auth (guest, Google, Apple, email). Guests can start immediately; linking later migrates data.
  - Capture/edit: FAB opens `AddEditScreen`; smart camera with guided overlay, Gemini 1.5 prompt extracts product/price/discount/category, user confirms quantity, tax inclusion, tax rate, price type, discount, and category. Google Places nearby/Autocomplete powers shop selection; images upload to `price_tags`; Supabase save computes best-price flag via `get_nearby_cheapest`.
  - Timeline: Personal feed streaming `price_records` by `user_id`, grouped by date with community-style tiles and empty/error/login states.
  - Catalog & community: Category grid with glass cards; detail screen splits “My” vs “Community Nearby” (Pro unlock) with confirmation counts and cheapest badges. Search tabs: fuzzy product search (my data vs community) gated for guests/non-Pro.
  - Shopping list: Japanese-only list with add/toggle/delete, swipe actions, pull-to-refresh; works for guests via anonymous Supabase user IDs.
  - Profile & subscriptions: Gradient profile header, stats, settings, paywall entry points; paywall screen offers purchase/restore, RevenueCat Paywall UI, and Customer Center.
- UX pillars: Premium look inspired by Airbnb/Headspace/Japanese fintech; warm cream surfaces, deep teal primary, accent orange; Noto Sans JP typography; glassmorphism cards; animated bottom nav with pill indicator; gradient FAB and headers; rich empty/error states.
- Content rules: Keep strings in Japanese where present; categories fixed to 18-tag list (野菜, 果物, 精肉, 鮮魚, 惣菜, 卵, 乳製品, 豆腐・納豆・麺, パン, 米・穀物, 調味料, インスタント, 飲料, お酒, お菓子, 冷凍食品, 日用品, その他).
- Error/recovery: Guest gating surfaces inline prompts; password reset handled via Supabase deep link and in-app dialog; paywall errors use friendly messages; location/Places failures fall back to manual shop entry and non-community views.
- Paywall expectations: RevenueCat entitlement `カイログ Pro`; package identifiers expected by the custom UI: `monthly`, `quarterly`, `annual` (keep aligned with RC offerings). Non-Pro sees community counts; Pro sees full records.
