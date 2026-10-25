-- Shirin Kadeh Paris Customer Club setup (idempotent; no existing data is deleted)
begin;
alter table public.orders
 add column if not exists points_awarded boolean not null default false,
 add column if not exists points_awarded_amount integer not null default 0,
 add column if not exists points_reversed boolean not null default false;
alter table public.club_coupons alter column user_id drop not null;
alter table public.club_coupons add column if not exists used_at timestamptz;
alter table public.club_coupons add column if not exists used_order_id bigint references public.orders(id) on delete set null;
do $$ begin
 if not exists(select 1 from pg_constraint where conname='club_coupons_discount_value_valid') then
  alter table public.club_coupons add constraint club_coupons_discount_value_valid check(discount_value>0 and (discount_type<>'percent' or discount_value<=100));
 end if;
end $$;
create index if not exists orders_club_points_idx on public.orders(user_id,payment_status,created_at desc);
create index if not exists club_coupons_club_user_idx on public.club_coupons(user_id,active,expires_at);
alter table public.club_points enable row level security;
alter table public.club_coupons enable row level security;
drop policy if exists club_points_read_own_or_owner on public.club_points;
create policy club_points_read_own_or_owner on public.club_points for select to authenticated using(auth.uid()=user_id or lower(coalesce(auth.jwt()->>'email',''))='leylakazempoor79@gmail.com');
drop policy if exists club_points_owner_manage on public.club_points;
create policy club_points_owner_manage on public.club_points for all to authenticated using(lower(coalesce(auth.jwt()->>'email',''))='leylakazempoor79@gmail.com') with check(lower(coalesce(auth.jwt()->>'email',''))='leylakazempoor79@gmail.com');
drop policy if exists club_coupons_read_own_or_owner on public.club_coupons;
create policy club_coupons_read_own_or_owner on public.club_coupons for select to authenticated using(auth.uid()=user_id or user_id is null or lower(coalesce(auth.jwt()->>'email',''))='leylakazempoor79@gmail.com');
drop policy if exists club_coupons_owner_manage on public.club_coupons;
create policy club_coupons_owner_manage on public.club_coupons for all to authenticated using(lower(coalesce(auth.jwt()->>'email',''))='leylakazempoor79@gmail.com') with check(lower(coalesce(auth.jwt()->>'email',''))='leylakazempoor79@gmail.com');
create or replace function public.award_shire_club_points_on_payment()
returns trigger language plpgsql security definer set search_path=pg_catalog,public as $$
declare v_points integer;
begin
 if new.payment_status='paid' and (tg_op='INSERT' or old.payment_status is distinct from new.payment_status) and not new.points_awarded and new.user_id is not null then
  v_points:=greatest(0,floor(greatest(coalesce(new.total,0),0)::numeric/10000)::integer);
  if v_points>0 then
   insert into public.club_points(user_id,points,updated_at) values(new.user_id,v_points,now())
   on conflict(user_id) do update set points=least(100000000,public.club_points.points+excluded.points),updated_at=now();
  end if;
  new.points_awarded:=true;new.points_awarded_amount:=v_points;new.points_reversed:=false;
 elsif new.payment_status='refunded' and old.payment_status is distinct from new.payment_status and new.points_awarded and not new.points_reversed and new.user_id is not null then
  if coalesce(new.points_awarded_amount,0)>0 then
   insert into public.club_points(user_id,points,updated_at) values(new.user_id,0,now()) on conflict(user_id) do nothing;
   update public.club_points set points=greatest(0,points-new.points_awarded_amount),updated_at=now() where user_id=new.user_id;
  end if;
  new.points_reversed:=true;
 end if;
 return new;
end;$$;
revoke all on function public.award_shire_club_points_on_payment() from public,anon,authenticated;
drop trigger if exists trg_shire_club_points_payment on public.orders;
create trigger trg_shire_club_points_payment before insert or update of payment_status on public.orders for each row execute function public.award_shire_club_points_on_payment();
commit;
