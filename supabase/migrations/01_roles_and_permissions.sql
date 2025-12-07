-- 1. Create Roles Table
create table public.app_roles (
  id uuid default uuid_generate_v4() primary key,
  name text not null unique,
  description text,
  is_system boolean default false, -- If true, cannot be deleted (e.g. Admin)
  created_at timestamptz default now()
);

-- 2. Create Permissions Table
create table public.app_permissions (
  id uuid default uuid_generate_v4() primary key,
  code text not null unique, -- e.g. 'view_planning', 'manage_users'
  description text,
  created_at timestamptz default now()
);

-- 3. Create Role-Permissions Link Table
create table public.role_permissions (
  role_id uuid references public.app_roles(id) on delete cascade not null,
  permission_id uuid references public.app_permissions(id) on delete cascade not null,
  primary key (role_id, permission_id)
);

-- 4. Update Profiles to link to App Roles
alter table public.profiles 
  add column role_id uuid references public.app_roles(id);

-- 5. RLS for New Tables
alter table public.app_roles enable row level security;
alter table public.app_permissions enable row level security;
alter table public.role_permissions enable row level security;

-- Policies
-- Roles: Everyone can view (to see their own role name), only Admins can manage
create policy "Roles viewable by everyone" on public.app_roles for select using (true);
create policy "Admins can manage roles" on public.app_roles for all using (public.is_admin());

-- Permissions: Everyone can view, only Admins can manage
create policy "Permissions viewable by everyone" on public.app_permissions for select using (true);
create policy "Admins can manage permissions" on public.app_permissions for all using (public.is_admin());

-- Role-Permissions: Everyone can view, only Admins can manage
create policy "Role-Permissions viewable by everyone" on public.role_permissions for select using (true);
create policy "Admins can manage role-permissions" on public.role_permissions for all using (public.is_admin());

-- 6. Seed Initial Data
-- Insert Permissions
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
('view_all_unavailabilities', 'Voir les indisponibilités des autres');

-- Insert Roles
insert into public.app_roles (name, description, is_system) values
('Admin', 'Accès total', true),
('Docteur', 'Accès standard médecin', true),
('Secrétariat', 'Lecture seule et impression', true);

-- Assign Permissions to Admin (ALL)
insert into public.role_permissions (role_id, permission_id)
select (select id from public.app_roles where name = 'Admin'), id from public.app_permissions;

-- Assign Permissions to Docteur
insert into public.role_permissions (role_id, permission_id)
select (select id from public.app_roles where name = 'Docteur'), id from public.app_permissions
where code in ('view_dashboard', 'view_planning', 'view_rcp', 'view_doctors', 'declare_unavailability');

-- Assign Permissions to Secrétariat
insert into public.role_permissions (role_id, permission_id)
select (select id from public.app_roles where name = 'Secrétariat'), id from public.app_permissions
where code in ('view_dashboard', 'view_planning', 'view_rcp', 'view_doctors', 'view_all_unavailabilities');

-- 7. Migrate Existing Profiles (Optional, if you have data)
-- update public.profiles set role_id = (select id from public.app_roles where name = 'Admin') where role = 'admin';
-- update public.profiles set role_id = (select id from public.app_roles where name = 'Docteur') where role = 'doctor';
-- update public.profiles set role_id = (select id from public.app_roles where name = 'Secrétariat') where role = 'viewer';
