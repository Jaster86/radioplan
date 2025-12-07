-- Migration: Create specialties table
-- This table stores available specialties that can be assigned to doctors

CREATE TABLE IF NOT EXISTS public.specialties (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    color TEXT DEFAULT '#3b82f6',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.specialties ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read specialties
CREATE POLICY "Anyone can view specialties"
    ON public.specialties FOR SELECT
    USING (true);

-- Only admins can modify specialties
CREATE POLICY "Only admins can insert specialties"
    ON public.specialties FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.app_roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'Admin'
        )
    );

CREATE POLICY "Only admins can update specialties"
    ON public.specialties FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.app_roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'Admin'
        )
    );

CREATE POLICY "Only admins can delete specialties"
    ON public.specialties FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.app_roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'Admin'
        )
    );

-- Insert some default specialties
INSERT INTO public.specialties (name, description, color) VALUES
    ('Radiologie', 'Radiologie générale', '#3b82f6'),
    ('Scanner', 'Tomodensitométrie', '#8b5cf6'),
    ('IRM', 'Imagerie par résonance magnétique', '#06b6d4'),
    ('Échographie', 'Échographie et Doppler', '#10b981'),
    ('Sénologie', 'Imagerie mammaire', '#ec4899'),
    ('Interventionnel', 'Radiologie interventionnelle', '#f97316'),
    ('Pédiatrique', 'Radiologie pédiatrique', '#eab308'),
    ('Ostéo-articulaire', 'Imagerie ostéo-articulaire', '#64748b')
ON CONFLICT (name) DO NOTHING;
