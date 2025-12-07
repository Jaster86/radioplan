-- ============================================
-- Activity Equity Groups Schema Update
-- Run this in Supabase SQL Editor
-- ============================================

-- Add equity_group column to activities table
ALTER TABLE public.activities 
ADD COLUMN IF NOT EXISTS equity_group text DEFAULT NULL;

-- Update initial activities with equity groups
UPDATE public.activities SET equity_group = 'unity_astreinte' WHERE name IN ('Astreinte', 'UNITY');
UPDATE public.activities SET equity_group = 'workflow' WHERE name = 'Supervision Workflow';

-- Insert initial activities with equity groups (safe to re-run)
INSERT INTO public.activities (id, name, granularity, allow_double_booking, color, is_system, equity_group) VALUES
  ('0bbd55f0-0001-0001-0001-000000000001', 'Astreinte', 'HALF_DAY', false, 'bg-red-100 text-red-800', true, 'unity_astreinte'),
  ('0bbd55f0-0002-0002-0002-000000000002', 'UNITY', 'HALF_DAY', false, 'bg-orange-100 text-orange-800', true, 'unity_astreinte'),
  ('0bbd55f0-0003-0003-0003-000000000003', 'Supervision Workflow', 'WEEKLY', true, 'bg-emerald-100 text-emerald-800', true, 'workflow')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  granularity = EXCLUDED.granularity,
  allow_double_booking = EXCLUDED.allow_double_booking,
  color = EXCLUDED.color,
  is_system = EXCLUDED.is_system,
  equity_group = EXCLUDED.equity_group;

-- ============================================
-- RLS Policy for activities deletion (admin only)
-- ============================================
DROP POLICY IF EXISTS "Admins can delete activities" ON public.activities;
CREATE POLICY "Admins can delete activities" ON public.activities 
  FOR DELETE USING (public.is_admin() AND NOT is_system);
