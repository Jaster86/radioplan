-- Create RCP definitions table
CREATE TABLE IF NOT EXISTS public.rcp_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    frequency TEXT NOT NULL DEFAULT 'WEEKLY',
    week_parity TEXT,
    monthly_week_number INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create RCP manual instances table (for manual RCP dates/assignments)
CREATE TABLE IF NOT EXISTS public.rcp_manual_instances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rcp_definition_id UUID NOT NULL REFERENCES public.rcp_definitions(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    time TEXT,
    doctor_ids UUID[] DEFAULT '{}',
    backup_doctor_id UUID REFERENCES public.doctors(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(rcp_definition_id, date)
);

-- Enable RLS
ALTER TABLE public.rcp_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rcp_manual_instances ENABLE ROW LEVEL SECURITY;

-- Policies for rcp_definitions
CREATE POLICY "Allow read access to rcp_definitions" ON public.rcp_definitions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow insert access to rcp_definitions" ON public.rcp_definitions FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow update access to rcp_definitions" ON public.rcp_definitions FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Allow delete access to rcp_definitions" ON public.rcp_definitions FOR DELETE TO authenticated USING (true);

-- Policies for rcp_manual_instances
CREATE POLICY "Allow read access to rcp_manual_instances" ON public.rcp_manual_instances FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow insert access to rcp_manual_instances" ON public.rcp_manual_instances FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow update access to rcp_manual_instances" ON public.rcp_manual_instances FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Allow delete access to rcp_manual_instances" ON public.rcp_manual_instances FOR DELETE TO authenticated USING (true);
