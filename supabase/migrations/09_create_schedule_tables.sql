-- Create schedule_templates table (Consultation and RCP rules)
CREATE TABLE IF NOT EXISTS public.schedule_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    day TEXT NOT NULL,
    period TEXT NOT NULL,
    time TEXT,
    location TEXT NOT NULL,
    type TEXT NOT NULL,
    default_doctor_id UUID REFERENCES public.doctors(id) ON DELETE SET NULL,
    secondary_doctor_ids UUID[] DEFAULT '{}',
    doctor_ids UUID[] DEFAULT '{}',
    backup_doctor_id UUID REFERENCES public.doctors(id) ON DELETE SET NULL,
    sub_type TEXT,
    is_required BOOLEAN DEFAULT true,
    is_blocking BOOLEAN DEFAULT true,
    frequency TEXT DEFAULT 'WEEKLY',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create unique constraint for template slots
CREATE UNIQUE INDEX IF NOT EXISTS schedule_templates_unique_slot 
ON public.schedule_templates(day, period, location, type);

-- Create schedule_slots table (Actual schedule instances)
CREATE TABLE IF NOT EXISTS public.schedule_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE NOT NULL,
    day TEXT NOT NULL,
    period TEXT NOT NULL,
    time TEXT,
    location TEXT,
    type TEXT NOT NULL,
    assigned_doctor_id UUID REFERENCES public.doctors(id) ON DELETE SET NULL,
    secondary_doctor_ids UUID[] DEFAULT '{}',
    backup_doctor_id UUID REFERENCES public.doctors(id) ON DELETE SET NULL,
    sub_type TEXT,
    is_generated BOOLEAN DEFAULT true,
    activity_id TEXT,
    is_locked BOOLEAN DEFAULT false,
    is_blocking BOOLEAN DEFAULT true,
    is_closed BOOLEAN DEFAULT false,
    is_unconfirmed BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create unique constraint for schedule slots
CREATE UNIQUE INDEX IF NOT EXISTS schedule_slots_unique_slot 
ON public.schedule_slots(date, period, location, type, activity_id);

-- Create RCP attendance table
CREATE TABLE IF NOT EXISTS public.rcp_attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slot_id TEXT NOT NULL,
    doctor_id UUID REFERENCES public.doctors(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('PRESENT', 'ABSENT')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(slot_id, doctor_id)
);

-- Create RCP exceptions table
CREATE TABLE IF NOT EXISTS public.rcp_exceptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rcp_template_id TEXT NOT NULL,
    original_date DATE NOT NULL,
    new_date DATE,
    new_period TEXT,
    is_cancelled BOOLEAN DEFAULT false,
    new_time TEXT,
    custom_doctor_ids UUID[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(rcp_template_id, original_date)
);

-- Enable RLS
ALTER TABLE public.schedule_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.schedule_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rcp_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rcp_exceptions ENABLE ROW LEVEL SECURITY;

-- Policies for schedule_templates
CREATE POLICY "Allow read access to schedule_templates" ON public.schedule_templates FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow insert access to schedule_templates" ON public.schedule_templates FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow update access to schedule_templates" ON public.schedule_templates FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Allow delete access to schedule_templates" ON public.schedule_templates FOR DELETE TO authenticated USING (true);

-- Policies for schedule_slots
CREATE POLICY "Allow read access to schedule_slots" ON public.schedule_slots FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow insert access to schedule_slots" ON public.schedule_slots FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow update access to schedule_slots" ON public.schedule_slots FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Allow delete access to schedule_slots" ON public.schedule_slots FOR DELETE TO authenticated USING (true);

-- Policies for rcp_attendance
CREATE POLICY "Allow read access to rcp_attendance" ON public.rcp_attendance FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow insert access to rcp_attendance" ON public.rcp_attendance FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow update access to rcp_attendance" ON public.rcp_attendance FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Allow delete access to rcp_attendance" ON public.rcp_attendance FOR DELETE TO authenticated USING (true);

-- Policies for rcp_exceptions
CREATE POLICY "Allow read access to rcp_exceptions" ON public.rcp_exceptions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow insert access to rcp_exceptions" ON public.rcp_exceptions FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow update access to rcp_exceptions" ON public.rcp_exceptions FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Allow delete access to rcp_exceptions" ON public.rcp_exceptions FOR DELETE TO authenticated USING (true);
