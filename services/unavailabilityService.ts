import { supabase } from './supabaseClient';
import { Unavailability } from '../types';

export const unavailabilityService = {
    async getAll(): Promise<Unavailability[]> {
        const { data, error } = await supabase
            .from('unavailabilities')
            .select('*');

        if (error) throw error;

        return data.map((u: any) => ({
            id: u.id,
            doctorId: u.doctor_id,
            startDate: u.start_date,
            endDate: u.end_date,
            period: u.period,
            reason: u.reason
        }));
    },

    async create(unavailability: Omit<Unavailability, 'id'>): Promise<Unavailability> {
        const { data, error } = await supabase
            .from('unavailabilities')
            .insert({
                doctor_id: unavailability.doctorId,
                start_date: unavailability.startDate,
                end_date: unavailability.endDate,
                period: unavailability.period,
                reason: unavailability.reason
            })
            .select()
            .single();

        if (error) throw error;

        return {
            id: data.id,
            doctorId: data.doctor_id,
            startDate: data.start_date,
            endDate: data.end_date,
            period: data.period,
            reason: data.reason
        };
    },

    async delete(id: string): Promise<void> {
        const { error } = await supabase
            .from('unavailabilities')
            .delete()
            .eq('id', id);

        if (error) throw error;
    }
};
