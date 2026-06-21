-- ============================================================
-- Rent Manager — Supabase Schema
-- Run this in the Supabase SQL Editor (Project -> SQL Editor)
-- ============================================================

create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- 1. LANDLORDS (profile, 1 row per auth user)
-- ------------------------------------------------------------
create table if not exists public.landlords (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone_number text,
  business_name text,
  upi_id text,
  whatsapp_automation_sync boolean not null default true,
  payment_success_sound boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 2. TENANTS
-- ------------------------------------------------------------
create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  landlord_id uuid not null references public.landlords(id) on delete cascade,
  name text not null,
  phone_number text,
  room_complex text,
  monthly_rent numeric(10,2) not null default 0,
  due_day int not null default 1 check (due_day between 1 and 31),
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_tenants_landlord on public.tenants(landlord_id);

-- ------------------------------------------------------------
-- 3. RENT PAYMENTS / COLLECTION LOGS
-- ------------------------------------------------------------
create table if not exists public.rent_payments (
  id uuid primary key default gen_random_uuid(),
  landlord_id uuid not null references public.landlords(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  amount_due numeric(10,2) not null default 0,
  amount_paid numeric(10,2) not null default 0,
  period_month int not null,
  period_year int not null,
  due_date date,
  paid_at timestamptz,
  payment_method text,
  status text not null default 'pending',
  auto_verified boolean not null default false,
  reminder_sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, period_month, period_year)
);

create index if not exists idx_payments_landlord on public.rent_payments(landlord_id);
create index if not exists idx_payments_tenant on public.rent_payments(tenant_id);
create index if not exists idx_payments_status on public.rent_payments(status);

-- ------------------------------------------------------------
-- 4. updated_at triggers
-- ------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_landlords_updated on public.landlords;
create trigger trg_landlords_updated before update on public.landlords
  for each row execute function public.set_updated_at();

drop trigger if exists trg_tenants_updated on public.tenants;
create trigger trg_tenants_updated before update on public.tenants
  for each row execute function public.set_updated_at();

drop trigger if exists trg_payments_updated on public.rent_payments;
create trigger trg_payments_updated before update on public.rent_payments
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- 5. Auto-create landlord profile row on signup
-- ------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.landlords (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ------------------------------------------------------------
-- 6. Row Level Security
-- ------------------------------------------------------------
alter table public.landlords enable row level security;
alter table public.tenants enable row level security;
alter table public.rent_payments enable row level security;

create policy "Landlords can view own profile"
  on public.landlords for select
  using (auth.uid() = id);

create policy "Landlords can update own profile"
  on public.landlords for update
  using (auth.uid() = id);

create policy "Landlords can insert own profile"
  on public.landlords for insert
  with check (auth.uid() = id);

create policy "Landlords can view own tenants"
  on public.tenants for select
  using (auth.uid() = landlord_id);

create policy "Landlords can insert own tenants"
  on public.tenants for insert
  with check (auth.uid() = landlord_id);

create policy "Landlords can update own tenants"
  on public.tenants for update
  using (auth.uid() = landlord_id);

create policy "Landlords can delete own tenants"
  on public.tenants for delete
  using (auth.uid() = landlord_id);

create policy "Landlords can view own payments"
  on public.rent_payments for select
  using (auth.uid() = landlord_id);

create policy "Landlords can insert own payments"
  on public.rent_payments for insert
  with check (auth.uid() = landlord_id);

create policy "Landlords can update own payments"
  on public.rent_payments for update
  using (auth.uid() = landlord_id);

create policy "Landlords can delete own payments"
  on public.rent_payments for delete
  using (auth.uid() = landlord_id);
