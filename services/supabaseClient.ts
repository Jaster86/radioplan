import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

const sb_u =  'https://sbkwkqqrersznlqpihkg.supabase.co';
const sb_k =  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNia3drcXFyZXJzem5scXBpaGtnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ2ODU0NzIsImV4cCI6MjA4MDI2MTQ3Mn0.xG8lmwRoSZq5Ehj9a6Apqlew5K4DenMOg8BtJOmn4Tc';

if (!supabaseUrl || !supabaseAnonKey) {
  console.warn('Missing Supabase environment variables');
}

export const supabase = createClient(sb_u, sb_k);
