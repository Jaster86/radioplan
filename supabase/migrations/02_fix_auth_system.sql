-- ============================================
-- FIX: Complete Authentication System
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. Create trigger to auto-create profile on user signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, role)
  values (new.id, new.email, 'viewer');
  return new;
end;
$$ language plpgsql security definer;

-- Drop existing trigger if exists
drop trigger if exists on_auth_user_created on auth.users;

-- Create trigger
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 2. Fix RLS policies - Allow INSERT for profiles (needed for trigger)
drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

-- 3. Add policy for service role to manage profiles
drop policy if exists "Service role can manage all profiles" on public.profiles;
create policy "Service role can manage all profiles"
  on public.profiles for all
  using (auth.jwt() ->> 'role' = 'service_role');

-- 4. Update is_admin function to also check app_roles
create or replace function public.is_admin()
returns boolean as $$
begin
  return exists (
    select 1 from public.profiles p
    left join public.app_roles ar on p.role_id = ar.id
    where p.id = auth.uid() 
    and (p.role = 'admin' OR ar.name = 'Admin')
  );
end;
$$ language plpgsql security definer;

-- 5. Ensure app_roles and app_permissions tables exist (safe to re-run)
create table if not exists public.app_roles (
  id uuid default uuid_generate_v4() primary key,
  name text not null unique,
  description text,
  is_system boolean default false,
  created_at timestamptz default now()
);

create table if not exists public.app_permissions (
  id uuid default uuid_generate_v4() primary key,
  code text not null unique,
  description text,
  created_at timestamptz default now()
);

create table if not exists public.role_permissions (
  role_id uuid references public.app_roles(id) on delete cascade not null,
  permission_id uuid references public.app_permissions(id) on delete cascade not null,
  primary key (role_id, permission_id)
);

-- 6. Add role_id column to profiles if not exists
do $$ 
begin
  if not exists (
    select 1 from information_schema.columns 
    where table_name = 'profiles' and column_name = 'role_id'
  ) then
    alter table public.profiles add column role_id uuid references public.app_roles(id);
  end if;
end $$;

-- 7. Enable RLS on new tables
alter table public.app_roles enable row level security;
alter table public.app_permissions enable row level security;
alter table public.role_permissions enable row level security;

-- 8. Create RLS policies for new tables
drop policy if exists "Roles viewable by everyone" on public.app_roles;
create policy "Roles viewable by everyone" on public.app_roles for select using (true);

drop policy if exists "Permissions viewable by everyone" on public.app_permissions;
create policy "Permissions viewable by everyone" on public.app_permissions for select using (true);

drop policy if exists "Role-Permissions viewable by everyone" on public.role_permissions;
create policy "Role-Permissions viewable by everyone" on public.role_permissions for select using (true);

-- 9. Seed data (use ON CONFLICT to avoid duplicates)
insert into public.app_permissions (code, description) values
  ('view_dashboard', 'Accès au tableau de bord'),
  ('view_planning', 'Accès au planning'),
  ('manage_planning', 'Modifier le planning'),
  ('view_rcp', 'Accès aux RCP'),
  ('manage_rcp', 'Gérer les RCP'),
  ('view_doctors', 'Voir la liste des médecins'),
  ('manage_doctors', 'Ajouter/Modifier des médecins'),
  ('manage_users', 'Gérer les utilisateurs et rôles'),
  ('manage_settings', 'Gérer la configuration'),
  ('declare_unavailability', 'Déclarer ses indisponibilités'),
  ('view_all_unavailabilities', 'Voir les indisponibilités des autres')
on conflict (code) do nothing;

insert into public.app_roles (name, description, is_system) values
  ('Admin', 'Accès total', true),
  ('Docteur', 'Accès standard médecin', true),
  ('Secrétariat', 'Lecture seule et impression', true)
on conflict (name) do nothing;

-- 10. Assign ALL permissions to Admin role
insert into public.role_permissions (role_id, permission_id)
select 
  (select id from public.app_roles where name = 'Admin'), 
  id 
from public.app_permissions
on conflict do nothing;

-- 11. Assign permissions to Docteur role
insert into public.role_permissions (role_id, permission_id)
select 
  (select id from public.app_roles where name = 'Docteur'), 
  id 
from public.app_permissions 
where code in ('view_dashboard', 'view_planning', 'view_rcp', 'view_doctors', 'declare_unavailability')
on conflict do nothing;

-- 12. Assign permissions to Secrétariat role  
insert into public.role_permissions (role_id, permission_id)
select 
  (select id from public.app_roles where name = 'Secrétariat'), 
  id 
from public.app_permissions
where code in ('view_dashboard', 'view_planning', 'view_rcp', 'view_doctors', 'view_all_unavailabilities')
on conflict do nothing;

-- ============================================
-- IMPORTANT: After running this script:
-- 1. Create a user in Supabase > Authentication > Users
-- 2. Then run this to make them admin:
-- 
-- UPDATE public.profiles 
-- SET role = 'admin', 
--     role_id = (SELECT id FROM public.app_roles WHERE name = 'Admin')
-- WHERE email = 'your-admin@email.com';
-- ============================================
