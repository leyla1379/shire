-- شیرین‌کده پاریس: تنظیمات محتوای قابل ویرایش سایت
-- در Supabase Dashboard > SQL Editor اجرا شود.
create table if not exists public.site_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.site_settings enable row level security;

drop policy if exists "Public can read site content" on public.site_settings;
create policy "Public can read site content"
  on public.site_settings for select
  to anon, authenticated
  using (key = 'site_content');

drop policy if exists "Store owner can insert site content" on public.site_settings;
create policy "Store owner can insert site content"
  on public.site_settings for insert
  to authenticated
  with check (
    key = 'site_content'
    and lower(coalesce(auth.jwt() ->> 'email', '')) = 'leylakazempoor79@gmail.com'
  );

drop policy if exists "Store owner can update site content" on public.site_settings;
create policy "Store owner can update site content"
  on public.site_settings for update
  to authenticated
  using (
    key = 'site_content'
    and lower(coalesce(auth.jwt() ->> 'email', '')) = 'leylakazempoor79@gmail.com'
  )
  with check (
    key = 'site_content'
    and lower(coalesce(auth.jwt() ->> 'email', '')) = 'leylakazempoor79@gmail.com'
  );

grant select on public.site_settings to anon, authenticated;
grant insert, update on public.site_settings to authenticated;
