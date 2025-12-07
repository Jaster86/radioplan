import { supabase } from './supabaseClient';
import { RcpDefinition } from '../types';

export const rcpService = {
    async getAll(): Promise<RcpDefinition[]> {
        const { data, error } = await supabase
            .from('rcp_definitions')
            .select(`
        *,
        rcp_manual_instances (*)
      `)
            .order('name');

        if (error) throw error;

        return data.map((r: any) => ({
            id: r.id,
            name: r.name,
            frequency: r.frequency,
            weekParity: r.week_parity,
            monthlyWeekNumber: r.monthly_week_number,
            manualInstances: r.rcp_manual_instances.map((m: any) => ({
                id: m.id,
                date: m.date,
                time: m.time,
                doctorIds: m.doctor_ids,
                backupDoctorId: m.backup_doctor_id
            }))
        }));
    },

    async create(rcp: Omit<RcpDefinition, 'id'>): Promise<RcpDefinition> {
        const { data, error } = await supabase
            .from('rcp_definitions')
            .insert({
                name: rcp.name,
                frequency: rcp.frequency,
                week_parity: rcp.weekParity,
                monthly_week_number: rcp.monthlyWeekNumber
            })
            .select()
            .single();

        if (error) throw error;

        return {
            id: data.id,
            name: data.name,
            frequency: data.frequency,
            weekParity: data.week_parity,
            monthlyWeekNumber: data.monthly_week_number,
            manualInstances: []
        };
    },

    async update(rcp: RcpDefinition): Promise<RcpDefinition> {
        console.log('📤 Updating RCP:', rcp.id, 'with', rcp.manualInstances?.length || 0, 'instances');

        // Update the RCP definition
        const { data, error } = await supabase
            .from('rcp_definitions')
            .update({
                name: rcp.name,
                frequency: rcp.frequency,
                week_parity: rcp.weekParity,
                monthly_week_number: rcp.monthlyWeekNumber
            })
            .eq('id', rcp.id)
            .select()
            .single();

        if (error) {
            console.error('❌ RCP update error:', error);
            throw error;
        }

        // Always delete existing instances first
        console.log('🗑️ Deleting existing instances for RCP:', rcp.id);
        const { error: deleteError } = await supabase
            .from('rcp_manual_instances')
            .delete()
            .eq('rcp_definition_id', rcp.id);

        if (deleteError) {
            console.error('❌ Delete instances error:', deleteError);
        }

        // Then insert new instances if there are any
        if (rcp.manualInstances && rcp.manualInstances.length > 0) {
            const instancesForDb = rcp.manualInstances.map(m => ({
                rcp_definition_id: rcp.id,
                date: m.date,
                time: m.time,
                doctor_ids: m.doctorIds || [],
                backup_doctor_id: m.backupDoctorId || null
            }));

            console.log('📦 Inserting', instancesForDb.length, 'instances');
            const { error: insertError } = await supabase
                .from('rcp_manual_instances')
                .insert(instancesForDb);

            if (insertError) {
                console.error('❌ Insert instances error:', insertError);
            } else {
                console.log('✅ Saved', instancesForDb.length, 'manual instances');
            }
        } else {
            console.log('✅ No instances to save');
        }

        return {
            id: data.id,
            name: data.name,
            frequency: data.frequency,
            weekParity: data.week_parity,
            monthlyWeekNumber: data.monthly_week_number,
            manualInstances: rcp.manualInstances || []
        };
    },

    async delete(id: string): Promise<void> {
        const { error } = await supabase
            .from('rcp_definitions')
            .delete()
            .eq('id', id);

        if (error) throw error;
    }
};
