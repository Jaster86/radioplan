-- Create unavailabilities table for storing doctor absences
CREATE TABLE IF NOT EXISTS public.unavailabilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    doctor_id UUID REFERENCES public.doctors(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    period TEXT CHECK (period IN ('ALL_DAY', 'Matin', 'Après-Midi')),
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.unavailabilities ENABLE ROW LEVEL SECURITY;

-- Create policies for unavailabilities
CREATE POLICY "Allow authenticated users to view unavailabilities"
ON public.unavailabilities FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Allow authenticated users to insert unavailabilities"
ON public.unavailabilities FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update their own unavailabilities"
ON public.unavailabilities FOR UPDATE
TO authenticated
USING (true);

CREATE POLICY "Allow authenticated users to delete unavailabilities"
ON public.unavailabilities FOR DELETE
TO authenticated
USING (true);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_unavailabilities_doctor_id ON public.unavailabilities(doctor_id);
CREATE INDEX IF NOT EXISTS idx_unavailabilities_dates ON public.unavailabilities(start_date, end_date);
