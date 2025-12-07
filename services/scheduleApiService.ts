import { supabase } from './supabaseClient';
import { ScheduleTemplateSlot, ScheduleSlot } from '../types';

export const scheduleApiService = {
    // --- TEMPLATES ---
    async getTemplate(): Promise<ScheduleTemplateSlot[]> {
        const { data, error } = await supabase
            .from('schedule_templates')
            .select('*');

        if (error) throw error;

        return data.map((t: any) => ({
            id: t.id,
            day: t.day,
            period: t.period,
            time: t.time,
            location: t.location,
            type: t.type,
            defaultDoctorId: t.default_doctor_id,
            secondaryDoctorIds: t.secondary_doctor_ids,
            doctorIds: t.doctor_ids,
            backupDoctorId: t.backup_doctor_id,
            subType: t.sub_type,
            isRequired: t.is_required,
            isBlocking: t.is_blocking,
            frequency: t.frequency
        }));
    },

    async saveTemplate(template: ScheduleTemplateSlot[]): Promise<ScheduleTemplateSlot[]> {
        console.log('📤 Saving template to DB:', template.length, 'items');

        // 1. Fetch current items from DB to detect deletions
        const { data: currentDbItems, error: fetchError } = await supabase
            .from('schedule_templates')
            .select('id');

        if (fetchError) {
            console.error('❌ Fetch Error:', fetchError);
            throw fetchError;
        }

        const currentDbIds = new Set((currentDbItems || []).map((item: any) => item.id));

        // 2. Separate new, existing, and deleted items
        const newItems = template.filter(t => t.id.includes('tmp_') || t.id.includes('temp_'));
        const existingItems = template.filter(t => !t.id.includes('tmp_') && !t.id.includes('temp_'));
        const existingIds = new Set(existingItems.map(t => t.id));

        // Items in DB that are not in the new template = deleted
        const deletedIds = [...currentDbIds].filter(id => !existingIds.has(id));

        const formatForDb = (t: ScheduleTemplateSlot) => ({
            id: t.id.includes('tmp_') || t.id.includes('temp_') ? undefined : t.id,
            day: t.day,
            period: t.period,
            time: t.time || null,
            location: t.location,
            type: t.type,
            default_doctor_id: t.defaultDoctorId || null,
            secondary_doctor_ids: t.secondaryDoctorIds || [],
            doctor_ids: t.doctorIds || [],
            backup_doctor_id: t.backupDoctorId || null,
            sub_type: t.subType || null,
            is_required: t.isRequired ?? true,
            is_blocking: t.isBlocking ?? true,
            frequency: t.frequency || 'WEEKLY'
        });

        // 3. Delete removed items first
        if (deletedIds.length > 0) {
            console.log('🗑️ Deleting', deletedIds.length, 'removed items:', deletedIds);
            const { error: deleteError } = await supabase
                .from('schedule_templates')
                .delete()
                .in('id', deletedIds);

            if (deleteError) {
                console.error('❌ Delete Error:', deleteError);
            } else {
                console.log('✅ Deleted', deletedIds.length, 'items');
            }
        }

        // 4. Update existing items one by one to avoid unique constraint issues
        if (existingItems.length > 0) {
            console.log('📝 Updating', existingItems.length, 'existing items');
            for (const item of existingItems) {
                const dbItem = formatForDb(item);
                const { error: updateError } = await supabase
                    .from('schedule_templates')
                    .update({
                        day: dbItem.day,
                        period: dbItem.period,
                        time: dbItem.time,
                        location: dbItem.location,
                        type: dbItem.type,
                        default_doctor_id: dbItem.default_doctor_id,
                        secondary_doctor_ids: dbItem.secondary_doctor_ids,
                        doctor_ids: dbItem.doctor_ids,
                        backup_doctor_id: dbItem.backup_doctor_id,
                        sub_type: dbItem.sub_type,
                        is_required: dbItem.is_required,
                        is_blocking: dbItem.is_blocking,
                        frequency: dbItem.frequency
                    })
                    .eq('id', item.id);

                if (updateError) {
                    console.error('❌ Update Error for', item.id, ':', updateError);
                }
            }
            console.log('✅ Updated', existingItems.length, 'items');
        }

        // 5. Upsert new items (insert or update if conflict on unique constraint)
        // The unique constraint is on (day, period, location, type)
        let insertedItems: ScheduleTemplateSlot[] = [];
        let insertFailed = false;
        if (newItems.length > 0) {
            console.log('📦 Upserting', newItems.length, 'new items:', newItems.map(i => ({ id: i.id, location: i.location, day: i.day, period: i.period, type: i.type, doctorIds: i.doctorIds })));

            // Format for DB but without ID (let DB generate or use existing)
            const itemsToUpsert = newItems.map(t => ({
                day: t.day,
                period: t.period,
                time: t.time || null,
                location: t.location,
                type: t.type,
                default_doctor_id: t.defaultDoctorId || null,
                secondary_doctor_ids: t.secondaryDoctorIds || [],
                doctor_ids: t.doctorIds || [],
                backup_doctor_id: t.backupDoctorId || null,
                sub_type: t.subType || null,
                is_required: t.isRequired ?? true,
                is_blocking: t.isBlocking ?? true,
                frequency: t.frequency || 'WEEKLY'
            }));
            console.log('📦 Formatted for DB:', itemsToUpsert);

            // Use upsert with conflict on the unique constraint columns
            const { data: upsertedData, error: upsertError } = await supabase
                .from('schedule_templates')
                .upsert(itemsToUpsert, {
                    onConflict: 'day,period,location,type',
                    ignoreDuplicates: false // Update on conflict
                })
                .select();

            if (upsertError) {
                console.error('❌ Upsert Error:', upsertError);
                console.error('❌ Upsert Error Details:', JSON.stringify(upsertError, null, 2));
                insertFailed = true;
            } else {
                console.log('✅ Upserted', newItems.length, 'items, received:', upsertedData?.length || 0);
                // Map back to frontend format
                insertedItems = (upsertedData || []).map((t: any) => ({
                    id: t.id,
                    day: t.day,
                    period: t.period,
                    time: t.time,
                    location: t.location,
                    type: t.type,
                    defaultDoctorId: t.default_doctor_id,
                    secondaryDoctorIds: t.secondary_doctor_ids,
                    doctorIds: t.doctor_ids,
                    backupDoctorId: t.backup_doctor_id,
                    subType: t.sub_type,
                    isRequired: t.is_required,
                    isBlocking: t.is_blocking,
                    frequency: t.frequency
                }));
            }
        }

        console.log('✅ Template save complete');
        console.log('📊 Summary: existing:', existingItems.length, 'inserted:', insertedItems.length, 'failed:', insertFailed);

        // Return updated template with real IDs
        // If insert failed, keep the temp items so user doesn't lose data
        if (insertFailed) {
            console.warn('⚠️ Returning original template due to insert failure');
            return template; // Return original template to preserve state
        }

        return [...existingItems, ...insertedItems];
    },


    async deleteTemplateSlot(id: string): Promise<void> {
        const { error } = await supabase
            .from('schedule_templates')
            .delete()
            .eq('id', id);

        if (error) throw error;
    },

    // --- SLOTS (The actual schedule) ---
    async getSlots(startDate: string, endDate: string): Promise<ScheduleSlot[]> {
        const { data, error } = await supabase
            .from('schedule_slots')
            .select('*')
            .gte('date', startDate)
            .lte('date', endDate);

        if (error) throw error;

        return data.map((s: any) => ({
            id: s.id,
            date: s.date,
            day: s.day,
            period: s.period,
            time: s.time,
            location: s.location,
            type: s.type,
            assignedDoctorId: s.assigned_doctor_id,
            secondaryDoctorIds: s.secondary_doctor_ids,
            backupDoctorId: s.backup_doctor_id,
            subType: s.sub_type,
            isGenerated: s.is_generated,
            activityId: s.activity_id,
            isLocked: s.is_locked,
            isBlocking: s.is_blocking,
            isClosed: s.is_closed,
            isUnconfirmed: s.is_unconfirmed
        }));
    },

    async saveSlots(slots: ScheduleSlot[]): Promise<void> {
        const dbSlots = slots.map(s => ({
            id: s.id.includes('gen_') ? undefined : s.id,
            date: s.date,
            day: s.day,
            period: s.period,
            time: s.time,
            location: s.location,
            type: s.type,
            assigned_doctor_id: s.assignedDoctorId,
            secondary_doctor_ids: s.secondaryDoctorIds,
            backup_doctor_id: s.backupDoctorId,
            sub_type: s.subType,
            is_generated: s.isGenerated,
            activity_id: s.activityId,
            is_locked: s.isLocked,
            is_blocking: s.isBlocking,
            is_closed: s.isClosed,
            is_unconfirmed: s.isUnconfirmed
        }));

        const { error } = await supabase
            .from('schedule_slots')
            .upsert(dbSlots);

        if (error) throw error;
    },

    // --- RCP ATTENDANCE ---
    async getRcpAttendance(): Promise<Record<string, Record<string, 'PRESENT' | 'ABSENT'>>> {
        const { data, error } = await supabase
            .from('rcp_attendance')
            .select('*');

        if (error) throw error;

        const attendance: Record<string, Record<string, 'PRESENT' | 'ABSENT'>> = {};
        data.forEach((a: any) => {
            if (!attendance[a.slot_id]) attendance[a.slot_id] = {};
            attendance[a.slot_id][a.doctor_id] = a.status;
        });
        return attendance;
    },

    async updateRcpAttendance(slotId: string, doctorId: string, status: 'PRESENT' | 'ABSENT'): Promise<void> {
        const { error } = await supabase
            .from('rcp_attendance')
            .upsert({
                slot_id: slotId,
                doctor_id: doctorId,
                status: status
            }, { onConflict: 'slot_id, doctor_id' });

        if (error) throw error;
    },

    // --- RCP EXCEPTIONS ---
    async getRcpExceptions(): Promise<any[]> {
        const { data, error } = await supabase
            .from('rcp_exceptions')
            .select('*');

        if (error) throw error;

        return data.map((e: any) => ({
            id: e.id,
            rcpTemplateId: e.rcp_template_id,
            originalDate: e.original_date,
            newDate: e.new_date,
            newPeriod: e.new_period,
            isCancelled: e.is_cancelled,
            newTime: e.new_time,
            customDoctorIds: e.custom_doctor_ids
        }));
    },

    async addRcpException(exception: any): Promise<void> {
        const dbData = {
            rcp_template_id: exception.rcpTemplateId,
            original_date: exception.originalDate,
            new_date: exception.newDate || null,
            new_period: exception.newPeriod || null,
            is_cancelled: exception.isCancelled || false,
            new_time: exception.newTime || null,
            custom_doctor_ids: exception.customDoctorIds || []
        };

        // Delete existing exception first (if any)
        await supabase
            .from('rcp_exceptions')
            .delete()
            .eq('rcp_template_id', exception.rcpTemplateId)
            .eq('original_date', exception.originalDate);

        // Insert new exception
        const { error } = await supabase
            .from('rcp_exceptions')
            .insert(dbData);

        if (error) {
            console.error('Error saving RCP exception:', error);
            throw error;
        }
    },

    async deleteRcpException(templateId: string, originalDate: string): Promise<void> {
        const { error } = await supabase
            .from('rcp_exceptions')
            .delete()
            .match({ rcp_template_id: templateId, original_date: originalDate });

        if (error) throw error;
    }
};
