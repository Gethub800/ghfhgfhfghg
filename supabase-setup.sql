-- Настройка базы для сайта Exclusive balloons.
-- Supabase → SQL Editor → New query → вставить весь файл → Run.
-- Скрипт можно запускать повторно.

-- 1) ЗАМЕНИТЕ почту на ту, под которой будете входить в панель администратора
--    (ту же самую вы создадите в Authentication → Users).
create or replace function public.is_shop_admin() returns boolean
language sql stable as $$
  select lower(coalesce(auth.jwt() ->> 'email', '')) = lower('hdhrhdfjrkndbdhr@gmail.com')
$$;

-- 2) Таблица товаров
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price integer not null check (price > 0),
  category text not null,
  description text not null default '',
  images text[] not null default '{}',
  thumb text,
  created_at timestamptz not null default now()
);

-- Румынское название товара (если таблица уже была создана раньше — эта строка её дополнит)
alter table public.products add column if not exists name_ro text;

alter table public.products enable row level security;

drop policy if exists "products: read all" on public.products;
create policy "products: read all" on public.products
  for select using (true);

drop policy if exists "products: admin insert" on public.products;
create policy "products: admin insert" on public.products
  for insert to authenticated with check (public.is_shop_admin());

drop policy if exists "products: admin delete" on public.products;
create policy "products: admin delete" on public.products
  for delete to authenticated using (public.is_shop_admin());

-- 3) Хранилище для фото (публичное: фото видны всем на сайте)
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do update set public = true;

drop policy if exists "photos: read all" on storage.objects;
create policy "photos: read all" on storage.objects
  for select using (bucket_id = 'product-images');

drop policy if exists "photos: admin upload" on storage.objects;
create policy "photos: admin upload" on storage.objects
  for insert to authenticated with check (bucket_id = 'product-images' and public.is_shop_admin());

drop policy if exists "photos: admin delete" on storage.objects;
create policy "photos: admin delete" on storage.objects
  for delete to authenticated using (bucket_id = 'product-images' and public.is_shop_admin());
