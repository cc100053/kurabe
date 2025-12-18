Schema diagrams

### ER overview
```mermaid
erDiagram
  auth_users {
    uuid id PK
  }
  profiles {
    uuid id PK, FK -> auth_users.id
    bool is_pro
    timestamptz created_at
  }
  price_records {
    bigint id PK
    timestamptz created_at
    text product_name
    numeric price
    bool is_tax_included
    text shop_name
    double shop_lat
    double shop_lng
    text image_url
    text category_tag
    bool is_best_price
    int quantity
    numeric original_price
    text price_type
    text discount_type
    numeric discount_value
    uuid user_id FK -> auth_users.id
    real tax_rate
  }
  shopping_list_items {
    bigserial id PK
    uuid user_id FK -> auth_users.id
    text title
    bool is_done
    timestamptz created_at
  }

  auth_users ||--|| profiles : "1-1 (optional)"
  auth_users ||--o{ price_records : "1-M (owner)"
  auth_users ||--o{ shopping_list_items : "1-M (owner)"
```

### Table notes
- `price_records`: Stores captured price tags. User-owned (`user_id` FK), includes quantity, original price, discount metadata, price type, tax inclusion flag, `tax_rate`, location (shop_name/lat/lng), image URL, category, and `is_best_price`. Indexed on product name (trigram + btree), created_at, price, location, user, category.
- `profiles`: Per-user subscription flag (`is_pro`) keyed to Supabase auth user. Self-owned RLS for select/insert/update.
- `shopping_list_items`: Shopping list entries scoped to `user_id` (also used for anonymous sessions). Indexed on `(user_id, is_done, created_at)`.
- Storage: Bucket `price_tags` allows public upload/read for receipt images (objects not shown in ERD).

### Access policies (RLS/high level)
- `price_records`: Insert open; select if `user_id = auth.uid()` or linked `profiles.is_pro`; update/delete only when `user_id = auth.uid()`.
- `profiles`: Insert/select/update only for the owning `auth.uid()`.
- `shopping_list_items`: CRUD limited to `auth.uid() = user_id` (works for anonymous users too).
- Storage `price_tags`: Public upload/read policies in storage schema.
