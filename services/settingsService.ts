import { supabase } from './supabaseClient';
import { ManualOverrides } from '../types';

// Settings service to persist global app settings
export const settingsService = {
    async get(): Promise<{ postes: string[], activitiesStartDate: string | null, validatedWeeks: string[], manualOverrides: ManualOverrides }> {
        const { data, error } = await supabase
            .from('app_settings')
            .select('*')
            .single();

        if (error) {
            // Return defaults if table doesn't exist or is empty
            console.warn('Settings not found, using defaults:', error.message);
            return {
                postes: ['Box 1', 'Box 2', 'Box 3'],
                activitiesStartDate: null,
                validatedWeeks: [],
                manualOverrides: {}
            };
        }

        return {
            postes: data?.postes || ['Box 1', 'Box 2', 'Box 3'],
            activitiesStartDate: data?.activities_start_date || null,
            validatedWeeks: data?.validated_weeks || [],
            manualOverrides: data?.manual_overrides || {}
        };
    },

    async update(settings: { postes?: string[], activitiesStartDate?: string | null, validatedWeeks?: string[], manualOverrides?: ManualOverrides }): Promise<void> {
        const updateData: any = {};
        if (settings.postes !== undefined) updateData.postes = settings.postes;
        if (settings.activitiesStartDate !== undefined) updateData.activities_start_date = settings.activitiesStartDate;
        if (settings.validatedWeeks !== undefined) updateData.validated_weeks = settings.validatedWeeks;
        if (settings.manualOverrides !== undefined) updateData.manual_overrides = settings.manualOverrides;

        // Try to upsert using id = 1 as the singleton pattern
        const { error } = await supabase
            .from('app_settings')
            .upsert({ id: 1, ...updateData, updated_at: new Date().toISOString() });

        if (error) {
            console.error('Failed to update settings:', error);
        }
    }
};
