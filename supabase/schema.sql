-- ============================================================
-- SpendSmart × Supabase schema
--
-- Run this ONCE in the Supabase SQL Editor for your project:
-- Dashboard → SQL Editor → New query → paste all → Run.
--
-- Tables: profiles, expenses, budgets, goals, income_entries,
--         ledger_entries, notifications
--
-- The app seeds nothing by itself: while a table is empty the app
-- keeps showing its built-in sample data; every add/edit/delete you
-- do in the app is mirrored to Supabase from then on.
-- ============================================================

-- ---------- profiles (single row, id = 'profile') ----------
create table if not exists public.profiles (
  id text primary key,
  full_name text not null default '',
  email text not null default '',
  phone text not null default '',
  member_tier text not null default 'Smart Saver',
  join_date text not null default '',
  monthly_income numeric not null default 0,
  occupation text not null default '',
  streak_days int not null default 0,
  health_score int not null default 0,
  biometrics_enabled boolean not null default false,
  app_lock_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

-- ---------- expenses ----------
create table if not exists public.expenses (
  id text primary key,
  title text not null,
  amount numeric not null,
  category_id text not null,
  date timestamptz not null,
  note text,
  created_at timestamptz not null default now()
);

-- ---------- budgets (single row, id = 1) ----------
create table if not exists public.budgets (
  id int primary key default 1,
  monthly_limit numeric not null default 0
);

-- ---------- goals (icon_codepoint = IconData codepoint) ----------
create table if not exists public.goals (
  id text primary key,
  name text not null,
  icon_codepoint bigint not null default 0,
  target_amount numeric not null default 0,
  saved_amount numeric not null default 0,
  monthly_saving numeric not null default 0,
  target_date timestamptz not null,
  created_at timestamptz not null default now()
);

-- ---------- income_entries (job salary + one-off earnings) ----------
create table if not exists public.income_entries (
  id text primary key,
  source text not null,
  amount numeric not null,
  date timestamptz not null,
  type text not null default 'other' check (type in ('job', 'other')),
  created_at timestamptz not null default now()
);

-- ---------- ledger_entries (Lend & Borrow) ----------
create table if not exists public.ledger_entries (
  id text primary key,
  person text not null,
  amount numeric not null,
  note text not null default '',
  date timestamptz not null,
  direction text not null check (direction in ('given', 'taken')),
  settled boolean not null default false,
  settled_date timestamptz,
  created_at timestamptz not null default now()
);

-- ---------- notifications ----------
create table if not exists public.notifications (
  id text primary key,
  type text not null,
  title text not null,
  body text not null default '',
  time_ago text not null default '',
  icon_codepoint bigint not null default 0,
  color_value bigint not null default 4282339879,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

-- Helpful index for the month/week aggregations.
create index if not exists expenses_date_idx on public.expenses (date desc);

-- ============================================================
-- Row Level Security — DEMO MODE (anon read/write)
-- ------------------------------------------------------------
-- SpendSmart has no real auth yet, so every table is readable and
-- writable with the anon key. That is fine for a university demo,
-- but NOT for real user data: anyone who gets your anon key could
-- read or edit the rows. See the PRODUCTION MODE block below.
-- ============================================================
alter table public.profiles        enable row level security;
alter table public.expenses        enable row level security;
alter table public.budgets         enable row level security;
alter table public.goals           enable row level security;
alter table public.income_entries  enable row level security;
alter table public.ledger_entries  enable row level security;
alter table public.notifications   enable row level security;

create policy "demo access profiles"       on public.profiles        for all using (true) with check (true);
create policy "demo access expenses"       on public.expenses        for all using (true) with check (true);
create policy "demo access budgets"        on public.budgets         for all using (true) with check (true);
create policy "demo access goals"          on public.goals           for all using (true) with check (true);
create policy "demo access income_entries" on public.income_entries  for all using (true) with check (true);
create policy "demo access ledger_entries" on public.ledger_entries  for all using (true) with check (true);
create policy "demo access notifications"  on public.notifications   for all using (true) with check (true);

-- ============================================================
-- PRODUCTION MODE (enable once real auth is added)
-- ------------------------------------------------------------
-- 1. Add an owner column to every table, e.g.:
--      alter table public.expenses add column user_id uuid default auth.uid();
-- 2. Drop the demo policies above and create per-user ones, e.g.:
--      create policy "own expenses select" on public.expenses
--        for select using (auth.uid() = user_id);
--      create policy "own expenses write" on public.expenses
--        for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
--    (repeat per table)
-- 3. Wire Supabase Auth into the login/register screens so users
--    actually sign in and auth.uid() exists.
-- ============================================================
