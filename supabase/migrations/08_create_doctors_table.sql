-- Create doctors table if not exists
CREATE TABLE IF NOT EXISTS public.doctors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    specialty TEXT[] DEFAULT '{}',
    color TEXT DEFAULT '#3B82F6',
    excluded_days TEXT[] DEFAULT '{}',
    excluded_activities TEXT[] DEFAULT '{}',
    excluded_slot_types TEXT[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add missing columns if doctors table already exists
DO $$ 
BEGIN
    -- Add excluded_days column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'doctors' AND column_name = 'excluded_days') THEN
        ALTER TABLE public.doctors ADD COLUMN excluded_days TEXT[] DEFAULT '{}';
    END IF;
    
    -- Add excluded_activities column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'doctors' AND column_name = 'excluded_activities') THEN
        ALTER TABLE public.doctors ADD COLUMN excluded_activities TEXT[] DEFAULT '{}';
    END IF;
    
    -- Add excluded_slot_types column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'doctors' AND column_name = 'excluded_slot_types') THEN
        ALTER TABLE public.doctors ADD COLUMN excluded_slot_types TEXT[] DEFAULT '{}';
    END IF;
END $$;

-- Enable RLS
ALTER TABLE public.doctors ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any (to avoid conflicts)
DROP POLICY IF EXISTS "Allow authenticated users to view doctors" ON public.doctors;
DROP POLICY IF EXISTS "Allow authenticated users to insert doctors" ON public.doctors;
DROP POLICY IF EXISTS "Allow authenticated users to update doctors" ON public.doctors;
DROP POLICY IF EXISTS "Allow authenticated users to delete doctors" ON public.doctors;

-- Create policies for doctors
CREATE POLICY "Allow authenticated users to view doctors"
ON public.doctors FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Allow authenticated users to insert doctors"
ON public.doctors FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update doctors"
ON public.doctors FOR UPDATE
TO authenticated
USING (true);

CREATE POLICY "Allow authenticated users to delete doctors"
ON public.doctors FOR DELETE
TO authenticated
USING (true);

-- Also ensure service_role can do everything
DROP POLICY IF EXISTS "Service role full access to doctors" ON public.doctors;
CREATE POLICY "Service role full access to doctors"
ON public.doctors FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
