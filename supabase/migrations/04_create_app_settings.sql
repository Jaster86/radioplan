-- Create app_settings table for global configuration
CREATE TABLE IF NOT EXISTS public.app_settings (
    id BIGINT PRIMARY KEY DEFAULT 1, -- Singleton row
    postes TEXT[] DEFAULT ARRAY['Box 1', 'Box 2', 'Box 3'],
    activities_start_date DATE,
    validated_weeks TEXT[] DEFAULT '{}', -- Array of week start dates that are validated/locked
    manual_overrides JSONB DEFAULT '{}', -- Locked activity slot assignments { slotId: doctorId }
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT single_row CHECK (id = 1)
);

-- Add validated_weeks column if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'app_settings' AND column_name = 'validated_weeks') THEN
        ALTER TABLE public.app_settings ADD COLUMN validated_weeks TEXT[] DEFAULT '{}';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'app_settings' AND column_name = 'manual_overrides') THEN
        ALTER TABLE public.app_settings ADD COLUMN manual_overrides JSONB DEFAULT '{}';
    END IF;
END $$;

-- Insert default row if not exists
INSERT INTO public.app_settings (id, postes)
VALUES (1, ARRAY['Box 1', 'Box 2', 'Box 3'])
ON CONFLICT (id) DO NOTHING;

-- Enable RLS
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Allow read access to authenticated users"
ON public.app_settings FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Allow update access to authenticated users"
ON public.app_settings FOR UPDATE
TO authenticated
USING (true);

CREATE POLICY "Allow insert access to authenticated users"
ON public.app_settings FOR INSERT
TO authenticated
WITH CHECK (true);
