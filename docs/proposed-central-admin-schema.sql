-- GBSBFORYOU Central Admin/RBAC schema proposal (PostgreSQL/Supabase)
-- DESIGN ONLY: review and adapt before applying to any live database.
-- Authentication identities should come from the configured identity provider (e.g. Supabase Auth).
-- Never store plaintext passwords or provider API secrets in these tables.

create extension if not exists pgcrypto;

create table if not exists public.publishing_branches (
  id uuid primary key default gen_random_uuid(),
  branch_key text not null unique,
  display_name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  email text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.branch_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  branch_id uuid not null references public.publishing_branches(id) on delete cascade,
  role text not null check (role in ('branch_admin','sub_admin','editor','producer','viewer')),
  granted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (user_id, branch_id)
);

create table if not exists public.central_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('main_admin','central_auditor')),
  granted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.approval_events (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.publishing_branches(id),
  asset_type text not null,
  asset_id text not null,
  decision text not null check (decision in ('submitted','approved','changes_requested','rejected','scheduled','published','failed')),
  note text,
  actor_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  branch_id uuid references public.publishing_branches(id) on delete set null,
  action text not null,
  resource_type text not null,
  resource_id text,
  outcome text not null default 'success' check (outcome in ('success','denied','failure')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists branch_memberships_user_idx on public.branch_memberships(user_id);
create index if not exists branch_memberships_branch_idx on public.branch_memberships(branch_id);
create index if not exists approval_events_asset_idx on public.approval_events(branch_id, asset_type, asset_id, created_at desc);
create index if not exists audit_events_actor_idx on public.audit_events(actor_user_id, created_at desc);
create index if not exists audit_events_branch_idx on public.audit_events(branch_id, created_at desc);

-- IMPORTANT IMPLEMENTATION GATES:
-- 1. Enable RLS on every table before connecting client applications.
-- 2. Create policies using trusted JWT claims and server-side permission checks.
-- 3. Do not let users self-assign central_roles or branch_memberships.
-- 4. Enforce final-publication approval server-side, not just in UI.
-- 5. Add updated_at triggers and immutable/audited role-change procedures.
-- 6. Restrict audit_events writes to trusted server functions where possible.
-- This file deliberately does not enable broad access policies or create an initial admin.
