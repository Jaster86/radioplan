-- ============================================
-- FIX: Admin permissions for user management
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. Update is_admin function to work correctly with app_roles
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles p
    LEFT JOIN public.app_roles ar ON p.role_id = ar.id
    WHERE p.id = auth.uid() 
    AND (p.role = 'admin' OR ar.name = 'Admin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Add policy for Admins to UPDATE any profile
DROP POLICY IF EXISTS "Admins can update all profiles" ON public.profiles;
CREATE POLICY "Admins can update all profiles"
  ON public.profiles FOR UPDATE
  USING (public.is_admin());

-- 3. Add policy for Admins to DELETE any profile
DROP POLICY IF EXISTS "Admins can delete profiles" ON public.profiles;
CREATE POLICY "Admins can delete profiles"
  ON public.profiles FOR DELETE
  USING (public.is_admin());

-- 4. Add policy for Admins to INSERT profiles (for edge function)
DROP POLICY IF EXISTS "Admins can insert profiles" ON public.profiles;
CREATE POLICY "Admins can insert profiles"
  ON public.profiles FOR INSERT
  WITH CHECK (public.is_admin() OR auth.uid() = id);

-- 5. Ensure service role can do everything on profiles
DROP POLICY IF EXISTS "Service role full access to profiles" ON public.profiles;
CREATE POLICY "Service role full access to profiles"
  ON public.profiles FOR ALL
  USING (auth.jwt() ->> 'role' = 'service_role');

-- 6. Also ensure Admins can manage doctors (should already exist but let's be sure)
DROP POLICY IF EXISTS "Admins can manage doctors" ON public.doctors;
CREATE POLICY "Admins can manage doctors"
  ON public.doctors FOR ALL
  USING (public.is_admin());

-- 7. Service role full access to doctors (for edge function)
DROP POLICY IF EXISTS "Service role full access to doctors" ON public.doctors;
CREATE POLICY "Service role full access to doctors"
  ON public.doctors FOR ALL
  USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================
-- VERIFICATION: Run this to check your admin status
-- SELECT public.is_admin();
-- ============================================
