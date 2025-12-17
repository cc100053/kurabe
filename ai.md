Here’s a full SQL bundle to align the DB with the app and the asks:

  -- Extensions (idempotent)
  create extension if not exists pg_trgm;
  create extension if not exists cube;
  create extension if not exists earthdistance;

  -- Drop redundant trigram index (keep idx_price_records_product_name_trgm)
  drop index if exists idx_product_name_fuzzy;

  -- Enforce user_id presence/default and backfill legacy nulls
  alter table public.price_records
    alter column user_id set default auth.uid();
  update public.price_records
    set user_id = coalesce(user_id, '00000000-0000-0000-0000-
  000000000000'::uuid)
    where user_id is null;
  alter table public.price_records
    alter column user_id set not null;

  create or replace function public.set_price_records_user_id()
  returns trigger
  language plpgsql
  security definer
  set search_path = public, extensions
  as $$
  begin
    if new.user_id is null then
      new.user_id := auth.uid();
    end if;
    if new.user_id is null then
      raise exception 'user_id is required';
    end if;
    return new;
  end;
  $$;

  drop trigger if exists trg_set_price_records_user_id on public.price_records;
  create trigger trg_set_price_records_user_id
  before insert on public.price_records
  for each row execute function public.set_price_records_user_id();

  -- RPC: get_nearby_cheapest (used when saving to set is_best_price)
  create or replace function public.get_nearby_cheapest(
    query_product_name text,
    user_lat double precision,
    user_lng double precision,
    search_radius_meters integer default 2000,
    recent_days integer default 5
  )
  returns table (
    id bigint,
    product_name text,
    price numeric,
    quantity integer,
    unit_price double precision,
    shop_name text,
    shop_lat double precision,
    shop_lng double precision,
    distance_meters double precision,
    created_at timestamptz
  ) as $$
  begin
    return query
    select
      pr.id,
      pr.product_name,
      pr.price,
      pr.quantity,
      pr.price / greatest(pr.quantity, 1) as unit_price,
      pr.shop_name,
      pr.shop_lat,
      pr.shop_lng,
      earth_distance(
        ll_to_earth(user_lat, user_lng),
        ll_to_earth(pr.shop_lat, pr.shop_lng)
      ) as distance_meters,
      pr.created_at
    from public.price_records pr
    where pr.shop_lat is not null
      and pr.shop_lng is not null
      and pr.product_name ilike concat('%', query_product_name, '%')
      and pr.created_at >= now() - make_interval(days => recent_days)
      and earth_distance(
            ll_to_earth(user_lat, user_lng),
            ll_to_earth(pr.shop_lat, pr.shop_lng)
          ) <= search_radius_meters
    order by (pr.price / greatest(pr.quantity, 1)) asc, distance_meters asc,
  pr.created_at desc
    limit 1;
  end;
  $$ language plpgsql
  security definer
  set search_path = public, extensions;

  -- RPC: search_community_prices (self results included)
  create or replace function public.search_community_prices(
    query_text text,
    user_lat double precision,
    user_lng double precision,
    limit_results integer default 20
  )
  returns table (
    id bigint,
    product_name text,
    price numeric,
    quantity integer,
    unit_price double precision,
    shop_name text,
    shop_lat double precision,
    shop_lng double precision,
    category_tag text,
    image_url text,
    created_at timestamptz,
    distance_meters double precision
  ) as $$
  begin
    return query
    select
      pr.id,
      pr.product_name,
      pr.price,
      pr.quantity,
      pr.price / greatest(pr.quantity, 1) as unit_price,
      pr.shop_name,
      pr.shop_lat,
      pr.shop_lng,
      pr.category_tag,
      pr.image_url,
      pr.created_at,
      case
        when pr.shop_lat is null or pr.shop_lng is null then null
        else earth_distance(
               ll_to_earth(user_lat, user_lng),
               ll_to_earth(pr.shop_lat, pr.shop_lng)
             )
      end as distance_meters
    from public.price_records pr
    where pr.product_name ilike concat('%', query_text, '%')
    order by
      (pr.price / greatest(pr.quantity, 1)) asc,
      distance_meters nulls last,
      pr.created_at desc
    limit limit_results;
  end;
  $$ language plpgsql
  security definer
  set search_path = public, extensions;

  -- RPC: count of nearby community prices ignoring RLS (for non-Pro counts)
  create or replace function public.count_nearby_community_prices(
    query_text text,
    user_lat double precision,
    user_lng double precision,
    search_radius_meters integer default 3000
  )
  returns integer as $$
  declare
    cnt integer;
  begin
    select count(*) into cnt
    from public.price_records pr
    where pr.product_name ilike concat('%', query_text, '%')
      and pr.shop_lat is not null
      and pr.shop_lng is not null
      and earth_distance(
            ll_to_earth(user_lat, user_lng),
            ll_to_earth(pr.shop_lat, pr.shop_lng)
          ) <= search_radius_meters;
    return cnt;
  end;
  $$ language plpgsql
  security definer
  set search_path = public, extensions;

  Notes:

  - The backfill assigns any legacy null user_id to a fixed UUID (00000000-
    0000-0000-0000-000000000000) so the column can be non-null; owners of those
    rows are unknown, but Pro users can still see them via RLS. For tighter
    ownership, rerun the update with your chosen user IDs instead.
  - Storage: left unchanged (public uploads/read for price_tags) to match the
    app.
  - After creating these functions, expose them in Supabase SQL editor or a
    migration file and reload the API.

- Check RPCs exist and are definer
      - select proname, prosecdef from pg_proc join pg_namespace n on
        n.oid=pg_proc.pronamespace where n.nspname='public' and proname in
        ('get_nearby_cheapest','search_community_prices','count_nearby_community
        _prices'); → prosecdef should be t (security definer).
      - Optional quick call:
          - select * from public.get_nearby_cheapest('test', 35.0, 135.0, 10,
            30) limit 1;
          - select * from public.search_community_prices('test', 35.0, 135.0,
            5);
          - select public.count_nearby_community_prices('test', 35.0, 135.0,
            5000);
            Use realistic coords/product fragments for your data; calls should
            succeed (empty result is fine if no data matches).
  - RLS behavior sanity
      - As a regular (non-Pro) user, select count(*) from price_records;
        should return only their rows; as a Pro user, it should include the
        placeholder-owner rows.
      - Anonymous upload still works: use the app or run a storage upload with
        an anon session to price_tags and ensure a public URL is returned.
  - Storage unchanged
      - Ensure bucket price_tags policies still allow public upload/read if
        that’s intended; if needed, check Supabase Storage policies UI.

  If all these checks pass (no nulls, correct defaults, trigger present, indexes
  correct, RPCs callable/definer), the DB matches the updated plan.