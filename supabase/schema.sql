-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ENUMS
create type user_role as enum ('admin', 'doctor', 'viewer');
create type slot_type as enum ('Consultation', 'RCP', 'Machine', 'Activity', 'Other');
create type period_type as enum ('Matin', 'Après-midi', 'ALL_DAY'); -- ALL_DAY added for Unavailability
create type day_of_week as enum ('Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi');
create type rcp_frequency as enum ('WEEKLY', 'BIWEEKLY', 'MONTHLY', 'MANUAL');
create type conflict_severity as enum ('HIGH', 'MEDIUM', 'LOW');

-- PROFILES (Linked to auth.users)
create table public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  email text not null,
  role user_role not null default 'viewer',
  doctor_id uuid, -- Link to a doctor profile if applicable
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- DOCTORS
create table public.doctors (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  specialty text[] default '{}',
  color text not null default '#3B82F6',
  excluded_days day_of_week[] default '{}',
  excluded_activities uuid[] default '{}', -- References activities(id)
  excluded_slot_types slot_type[] default '{}',
  created_at timestamptz default now()
);

-- Add FK to profiles after doctors table creation
alter table public.profiles 
  add constraint profiles_doctor_id_fkey 
  foreign key (doctor_id) references public.doctors(id) on delete set null;

-- ACTIVITIES
create table public.activities (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  granularity text check (granularity in ('HALF_DAY', 'WEEKLY')) default 'HALF_DAY',
  allow_double_booking boolean default false,
  color text not null default '#10B981',
  is_system boolean default false,
  created_at timestamptz default now()
);

-- RCP DEFINITIONS
create table public.rcp_definitions (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  frequency rcp_frequency not null default 'WEEKLY',
  week_parity text check (week_parity in ('ODD', 'EVEN')),
  monthly_week_number integer check (monthly_week_number between 1 and 5),
  created_at timestamptz default now()
);

-- RCP MANUAL INSTANCES (For Manual Frequency)
create table public.rcp_manual_instances (
  id uuid default uuid_generate_v4() primary key,
  rcp_definition_id uuid references public.rcp_definitions(id) on delete cascade not null,
  date date not null,
  time time not null,
  doctor_ids uuid[] default '{}', -- Array of doctor UUIDs
  backup_doctor_id uuid references public.doctors(id),
  created_at timestamptz default now()
);

-- SCHEDULE TEMPLATES (Weekly Rules)
create table public.schedule_templates (
  id uuid default uuid_generate_v4() primary key,
  day day_of_week not null,
  period period_type not null,
  time time,
  location text not null,
  type slot_type not null,
  default_doctor_id uuid references public.doctors(id),
  secondary_doctor_ids uuid[] default '{}',
  doctor_ids uuid[] default '{}', -- Explicit list
  backup_doctor_id uuid references public.doctors(id),
  sub_type text,
  is_required boolean default true,
  is_blocking boolean default true,
  frequency text check (frequency in ('WEEKLY', 'BIWEEKLY')) default 'WEEKLY',
  created_at timestamptz default now()
);

-- UNAVAILABILITIES
create table public.unavailabilities (
  id uuid default uuid_generate_v4() primary key,
  doctor_id uuid references public.doctors(id) on delete cascade not null,
  start_date date not null,
  end_date date not null,
  period period_type default 'ALL_DAY',
  reason text,
  created_at timestamptz default now()
);

-- SCHEDULE SLOTS (The actual calendar)
create table public.schedule_slots (
  id uuid default uuid_generate_v4() primary key,
  date date not null,
  day day_of_week not null,
  period period_type not null,
  time time,
  location text,
  type slot_type not null,
  assigned_doctor_id uuid references public.doctors(id),
  secondary_doctor_ids uuid[] default '{}',
  backup_doctor_id uuid references public.doctors(id),
  sub_type text,
  is_generated boolean default true,
  activity_id uuid references public.activities(id),
  is_locked boolean default false,
  is_blocking boolean default true,
  is_closed boolean default false,
  is_unconfirmed boolean default false,
  created_at timestamptz default now()
);

-- RCP ATTENDANCE
create table public.rcp_attendance (
  id uuid default uuid_generate_v4() primary key,
  slot_id uuid references public.schedule_slots(id) on delete cascade not null,
  doctor_id uuid references public.doctors(id) on delete cascade not null,
  status text check (status in ('PRESENT', 'ABSENT')) default 'PRESENT',
  created_at timestamptz default now(),
  unique(slot_id, doctor_id)
);

-- RCP EXCEPTIONS
create table public.rcp_exceptions (
  id uuid default uuid_generate_v4() primary key,
  rcp_template_id uuid references public.schedule_templates(id) on delete cascade not null,
  original_date date not null,
  new_date date,
  new_period period_type,
  is_cancelled boolean default false,
  new_time time,
  custom_doctor_ids uuid[] default '{}',
  created_at timestamptz default now()
);

-- ROW LEVEL SECURITY (RLS)
alter table public.profiles enable row level security;
alter table public.doctors enable row level security;
alter table public.activities enable row level security;
alter table public.rcp_definitions enable row level security;
alter table public.rcp_manual_instances enable row level security;
alter table public.schedule_templates enable row level security;
alter table public.unavailabilities enable row level security;
alter table public.schedule_slots enable row level security;
alter table public.rcp_attendance enable row level security;
alter table public.rcp_exceptions enable row level security;

-- POLICIES

-- Helper function to check if user is admin
create or replace function public.is_admin()
returns boolean as $$
begin
  return exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
end;
$$ language plpgsql security definer;

-- Helper function to check if user is doctor
create or replace function public.is_doctor()
returns boolean as $$
begin
  return exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'doctor'
  );
end;
$$ language plpgsql security definer;

-- PROFILES
create policy "Public profiles are viewable by everyone"
  on public.profiles for select
  using ( true );

create policy "Users can update own profile"
  on public.profiles for update
  using ( auth.uid() = id );

-- DOCTORS
create policy "Doctors are viewable by everyone"
  on public.doctors for select
  using ( true );

create policy "Only admins can insert/update/delete doctors"
  on public.doctors for all
  using ( public.is_admin() );

-- ACTIVITIES
create policy "Activities are viewable by everyone"
  on public.activities for select
  using ( true );

create policy "Only admins can manage activities"
  on public.activities for all
  using ( public.is_admin() );

-- RCP DEFINITIONS & MANUAL INSTANCES
create policy "RCP definitions are viewable by everyone"
  on public.rcp_definitions for select
  using ( true );

create policy "Only admins can manage RCP definitions"
  on public.rcp_definitions for all
  using ( public.is_admin() );

create policy "RCP manual instances viewable by everyone"
  on public.rcp_manual_instances for select
  using ( true );

create policy "Only admins can manage RCP manual instances"
  on public.rcp_manual_instances for all
  using ( public.is_admin() );

-- SCHEDULE TEMPLATES
create policy "Templates viewable by everyone"
  on public.schedule_templates for select
  using ( true );

create policy "Only admins can manage templates"
  on public.schedule_templates for all
  using ( public.is_admin() );

-- UNAVAILABILITIES
create policy "Unavailabilities viewable by everyone"
  on public.unavailabilities for select
  using ( true );

create policy "Doctors can manage their own unavailabilities"
  on public.unavailabilities for all
  using ( 
    public.is_admin() or 
    (public.is_doctor() and doctor_id = (select doctor_id from public.profiles where id = auth.uid()))
  );

-- SCHEDULE SLOTS
create policy "Slots viewable by everyone"
  on public.schedule_slots for select
  using ( true );

create policy "Admins can manage slots"
  on public.schedule_slots for all
  using ( public.is_admin() );

-- RCP ATTENDANCE
create policy "Attendance viewable by everyone"
  on public.rcp_attendance for select
  using ( true );

create policy "Doctors can mark their own attendance"
  on public.rcp_attendance for all
  using (
    public.is_admin() or
    (public.is_doctor() and doctor_id = (select doctor_id from public.profiles where id = auth.uid()))
  );

-- RCP EXCEPTIONS
create policy "Exceptions viewable by everyone"
  on public.rcp_exceptions for select
  using ( true );

create policy "Only admins can manage exceptions"
  on public.rcp_exceptions for all
  using ( public.is_admin() );

-- STORAGE (If needed for avatars later)
-- insert into storage.buckets (id, name) values ('avatars', 'avatars');
-- create policy "Avatar images are publicly accessible." on storage.objects for select using ( bucket_id = 'avatars' );
-- create policy "Anyone can upload an avatar." on storage.objects for insert with check ( bucket_id = 'avatars' );
