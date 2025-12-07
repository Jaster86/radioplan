-- Fix rcp_attendance table to use TEXT for slot_id instead of UUID
-- The slot_id is a composite key like "uuid-date" (e.g., "563726f7-ce5e-4bac-9f39-6ebcc7afae3c-2025-12-03")

-- First, drop the existing table and recreate with correct schema
DROP TABLE IF EXISTS public.rcp_attendance;

CREATE TABLE IF NOT EXISTS public.rcp_attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slot_id TEXT NOT NULL,
    doctor_id UUID REFERENCES public.doctors(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('PRESENT', 'ABSENT')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(slot_id, doctor_id)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_rcp_attendance_slot_id ON public.rcp_attendance(slot_id);
CREATE INDEX IF NOT EXISTS idx_rcp_attendance_doctor_id ON public.rcp_attendance(doctor_id);

-- Enable RLS
ALTER TABLE public.rcp_attendance ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Allow all for authenticated users" ON public.rcp_attendance
    FOR ALL USING (auth.role() = 'authenticated');
