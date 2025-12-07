import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    console.log('Request received:', req.method, req.url);

    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        console.log('Processing request...');

        // 1. Create a Supabase client with the Auth context of the caller
        const supabaseUrl = Deno.env.get('SUPABASE_URL');
        const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
        console.log('Env vars - URL:', !!supabaseUrl, 'ANON:', !!anonKey);

        const authHeader = req.headers.get('Authorization');
        console.log('Auth header present:', !!authHeader);

        const supabaseClient = createClient(
            supabaseUrl ?? '',
            anonKey ?? '',
            { global: { headers: { Authorization: authHeader! } } }
        )
        console.log('Client created');

        // 2. Check if the caller is an Admin
        const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
        console.log('User:', user?.email, 'Error:', userError?.message);

        if (!user) {
            return new Response(
                JSON.stringify({ error: 'Unauthorized: ' + (userError?.message || 'No session') }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const { data: profile, error: profileError } = await supabaseClient
            .from('profiles')
            .select('role_id, app_roles(name)')
            .eq('id', user.id)
            .single()

        console.log('Profile check:', JSON.stringify(profile), 'Error:', profileError?.message);

        if (profile?.app_roles?.name !== 'Admin') {
            return new Response(
                JSON.stringify({ error: 'Forbidden: Admins only' }),
                { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        console.log('Admin check passed');

        // 3. Create admin client with SERVICE_ROLE_KEY
        const serviceRoleKey = Deno.env.get('SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
        console.log('SERVICE_ROLE_KEY exists:', !!serviceRoleKey);

        if (!serviceRoleKey) {
            return new Response(
                JSON.stringify({ error: 'Server config error: SERVICE_ROLE_KEY missing' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            serviceRoleKey
        )

        const body = await req.json()
        const { action } = body
        console.log('Action:', action, 'Body:', JSON.stringify(body));

        // Handle different actions
        switch (action) {
            case 'create': {
                const { email, password, doctorData, roleId, existingDoctorId } = body
                console.log('CREATE - email:', email, 'roleId:', roleId, 'hasDoctorData:', !!doctorData, 'existingDoctorId:', existingDoctorId);

                let doctorId = existingDoctorId || null;

                // Create doctor only if doctorData is provided AND no existingDoctorId
                if (!existingDoctorId && doctorData && doctorData.name) {
                    console.log('Creating doctor:', doctorData.name);
                    const { data: newDoctor, error: doctorError } = await supabaseAdmin
                        .from('doctors')
                        .insert({
                            name: doctorData.name,
                            color: doctorData.color || '#3B82F6',
                            specialty: [],
                            excluded_days: [],
                            excluded_activities: [],
                            excluded_slot_types: []
                        })
                        .select()
                        .single();

                    console.log('Doctor result:', newDoctor?.id, 'Error:', doctorError?.message);

                    if (doctorError) {
                        return new Response(
                            JSON.stringify({ error: 'Failed to create doctor: ' + doctorError.message }),
                            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                        )
                    }
                    doctorId = newDoctor.id;
                }

                // Create auth user
                console.log('Creating auth user...');
                const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
                    email,
                    password,
                    email_confirm: true,
                    user_metadata: {
                        role_id: roleId,
                        doctor_id: doctorId
                    }
                })

                console.log('Auth user result:', newUser?.user?.id, 'Error:', createError?.message);

                if (createError) {
                    // Rollback doctor creation
                    if (doctorId) {
                        await supabaseAdmin.from('doctors').delete().eq('id', doctorId);
                    }
                    return new Response(
                        JSON.stringify({ error: 'Failed to create user: ' + createError.message }),
                        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                    )
                }

                // Update profile
                console.log('Updating profile...');
                if (newUser.user) {
                    const { error: updateErr } = await supabaseAdmin
                        .from('profiles')
                        .update({
                            role_id: roleId,
                            doctor_id: doctorId
                        })
                        .eq('id', newUser.user.id)
                    console.log('Profile update error:', updateErr?.message);
                }

                console.log('SUCCESS - returning response');

                return new Response(
                    JSON.stringify({
                        success: true,
                        user: newUser.user,
                        doctorId: doctorId
                    }),
                    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }

            case 'delete': {
                const { userId, doctorId } = body

                // Delete doctor first if provided
                if (doctorId) {
                    await supabaseAdmin.from('doctors').delete().eq('id', doctorId);
                }

                // Delete auth user (this cascades to delete profile)
                const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userId)

                if (deleteError) {
                    return new Response(
                        JSON.stringify({ error: 'Failed to delete user: ' + deleteError.message }),
                        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                    )
                }

                return new Response(
                    JSON.stringify({ success: true }),
                    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }

            case 'update': {
                const { userId, roleId, doctorData, newPassword, existingDoctorId } = body

                // Get current profile
                const { data: currentProfile } = await supabaseAdmin
                    .from('profiles')
                    .select('doctor_id')
                    .eq('id', userId)
                    .single();

                let doctorId = currentProfile?.doctor_id;

                // Handle doctor - 3 cases:
                // 1. existingDoctorId provided: link to that existing doctor
                // 2. doctorData provided: create new or update existing doctor
                // 3. neither provided: set doctor_id to null (unlink)

                if (existingDoctorId) {
                    // Link to existing doctor
                    doctorId = existingDoctorId;
                } else if (doctorData && doctorData.name) {
                    // Create new doctor (don't update existing - that's different)
                    const { data: newDoctor, error: createDocError } = await supabaseAdmin
                        .from('doctors')
                        .insert({
                            name: doctorData.name,
                            color: doctorData.color || '#3B82F6',
                            specialty: [],
                            excluded_days: [],
                            excluded_activities: [],
                            excluded_slot_types: []
                        })
                        .select()
                        .single();

                    if (createDocError) {
                        return new Response(
                            JSON.stringify({ error: 'Failed to create doctor: ' + createDocError.message }),
                            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                        )
                    }
                    doctorId = newDoctor.id;
                } else {
                    // No doctor specified - unlink
                    doctorId = null;
                }

                // Update profile - the trigger will sync the role enum
                const { error: profileError } = await supabaseAdmin
                    .from('profiles')
                    .update({
                        role_id: roleId,
                        doctor_id: doctorId
                    })
                    .eq('id', userId);

                if (profileError) {
                    return new Response(
                        JSON.stringify({ error: 'Failed to update profile: ' + profileError.message }),
                        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                    )
                }

                // Update password if provided
                if (newPassword) {
                    const { error: passwordError } = await supabaseAdmin.auth.admin.updateUserById(
                        userId,
                        { password: newPassword }
                    )

                    if (passwordError) {
                        return new Response(
                            JSON.stringify({
                                success: true,
                                warning: 'Profile updated but password change failed: ' + passwordError.message,
                                doctorId
                            }),
                            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                        )
                    }
                }

                return new Response(
                    JSON.stringify({ success: true, doctorId }),
                    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }

            case 'updatePassword': {
                const { userId, newPassword } = body

                const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
                    userId,
                    { password: newPassword }
                )

                if (updateError) {
                    return new Response(
                        JSON.stringify({ error: updateError.message }),
                        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                    )
                }

                return new Response(
                    JSON.stringify({ success: true }),
                    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }

            default:
                return new Response(
                    JSON.stringify({ error: 'Unknown action: ' + action }),
                    { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
        }

    } catch (error) {
        console.error('Edge function error:', error);
        return new Response(
            JSON.stringify({ error: 'Server error: ' + (error.message || 'Unknown') }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
