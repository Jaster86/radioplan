-- ============================================
-- FIX: Update trigger to use user_metadata and sync role
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. Update the trigger function to use user_metadata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    v_role_id uuid;
    v_doctor_id uuid;
    v_role_name text;
    v_role user_role;
BEGIN
    -- Get role_id and doctor_id from user_metadata
    v_role_id := (new.raw_user_meta_data->>'role_id')::uuid;
    v_doctor_id := (new.raw_user_meta_data->>'doctor_id')::uuid;
    
    -- Get role name to determine the enum value
    IF v_role_id IS NOT NULL THEN
        SELECT name INTO v_role_name FROM public.app_roles WHERE id = v_role_id;
        
        -- Map app_roles name to user_role enum
        IF v_role_name = 'Admin' THEN
            v_role := 'admin';
        ELSIF v_role_name IN ('Docteur', 'Médecin') THEN
            v_role := 'doctor';
        ELSE
            v_role := 'viewer';
        END IF;
    ELSE
        v_role := 'viewer';
    END IF;
    
    -- Insert profile with all the metadata
    INSERT INTO public.profiles (id, email, role, role_id, doctor_id)
    VALUES (new.id, new.email, v_role, v_role_id, v_doctor_id);
    
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Also create a helper function to sync role enum from role_id
CREATE OR REPLACE FUNCTION public.sync_role_from_role_id()
RETURNS trigger AS $$
DECLARE
    v_role_name text;
    v_role user_role;
BEGIN
    -- Get role name
    IF NEW.role_id IS NOT NULL THEN
        SELECT name INTO v_role_name FROM public.app_roles WHERE id = NEW.role_id;
        
        -- Map app_roles name to user_role enum
        IF v_role_name = 'Admin' THEN
            v_role := 'admin';
        ELSIF v_role_name IN ('Docteur', 'Médecin') THEN
            v_role := 'doctor';
        ELSE
            v_role := 'viewer';
        END IF;
        
        NEW.role := v_role;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to auto-sync role when role_id changes
DROP TRIGGER IF EXISTS sync_role_on_update ON public.profiles;
CREATE TRIGGER sync_role_on_update
    BEFORE UPDATE OF role_id ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_role_from_role_id();

-- 3. Fix existing profiles: sync their role enum with their role_id
UPDATE public.profiles p
SET role = CASE 
    WHEN ar.name = 'Admin' THEN 'admin'::user_role
    WHEN ar.name IN ('Docteur', 'Médecin') THEN 'doctor'::user_role
    ELSE 'viewer'::user_role
END
FROM public.app_roles ar
WHERE p.role_id = ar.id
AND p.role_id IS NOT NULL;

-- ============================================
-- VERIFICATION:
-- SELECT p.email, p.role, p.role_id, ar.name as role_name
-- FROM profiles p
-- LEFT JOIN app_roles ar ON p.role_id = ar.id;
-- ============================================
