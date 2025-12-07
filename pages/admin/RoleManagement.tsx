import React, { useEffect, useState } from 'react';
import { supabase } from '../../services/supabaseClient';
import { AppRole, AppPermission } from '../../types';
import { useAuth } from '../../context/AuthContext';
import { Save, Shield, Check, X } from 'lucide-react';

const RoleManagement: React.FC = () => {
    const { hasPermission } = useAuth();
    const [roles, setRoles] = useState<AppRole[]>([]);
    const [permissions, setPermissions] = useState<AppPermission[]>([]);
    const [loading, setLoading] = useState(true);
    const [matrix, setMatrix] = useState<Record<string, string[]>>({}); // roleId -> permissionCodes[]

    useEffect(() => {
        fetchData();
    }, []);

    const fetchData = async () => {
        setLoading(true);
        const { data: rolesData } = await supabase.from('app_roles').select('*').order('name');
        const { data: permsData } = await supabase.from('app_permissions').select('*').order('code');

        // Fetch matrix
        const { data: matrixData } = await supabase.from('role_permissions').select('role_id, app_permissions(code)');

        setRoles(rolesData || []);
        setPermissions(permsData || []);

        const newMatrix: Record<string, string[]> = {};
        matrixData?.forEach((item: any) => {
            if (!newMatrix[item.role_id]) newMatrix[item.role_id] = [];
            newMatrix[item.role_id].push(item.app_permissions.code);
        });
        setMatrix(newMatrix);
        setLoading(false);
    };

    const togglePermission = async (roleId: string, permCode: string, permId: string) => {
        const currentPerms = matrix[roleId] || [];
        const hasPerm = currentPerms.includes(permCode);

        if (hasPerm) {
            // Remove
            await supabase.from('role_permissions').delete().match({ role_id: roleId, permission_id: permId });
            setMatrix({ ...matrix, [roleId]: currentPerms.filter(p => p !== permCode) });
        } else {
            // Add
            await supabase.from('role_permissions').insert({ role_id: roleId, permission_id: permId });
            setMatrix({ ...matrix, [roleId]: [...currentPerms, permCode] });
        }
    };

    if (!hasPermission('manage_users')) return <div>Accès refusé</div>;
    if (loading) return <div>Chargement...</div>;

    return (
        <div className="p-6">
            <h1 className="text-2xl font-bold mb-6 flex items-center gap-2">
                <Shield className="w-6 h-6" /> Gestion des Rôles
            </h1>

            <div className="overflow-x-auto bg-white rounded-lg shadow">
                <table className="min-w-full border-collapse">
                    <thead>
                        <tr>
                            <th className="p-4 border-b text-left bg-gray-50">Permission</th>
                            {roles.map(role => (
                                <th key={role.id} className="p-4 border-b text-center bg-gray-50 min-w-[100px]">
                                    <div className="font-bold">{role.name}</div>
                                    <div className="text-xs text-gray-500 font-normal">{role.description}</div>
                                </th>
                            ))}
                        </tr>
                    </thead>
                    <tbody>
                        {permissions.map(perm => (
                            <tr key={perm.id} className="hover:bg-gray-50">
                                <td className="p-4 border-b">
                                    <div className="font-medium">{perm.code}</div>
                                    <div className="text-sm text-gray-500">{perm.description}</div>
                                </td>
                                {roles.map(role => {
                                    const hasPerm = (matrix[role.id] || []).includes(perm.code);
                                    return (
                                        <td key={`${role.id}-${perm.id}`} className="p-4 border-b text-center">
                                            <button
                                                onClick={() => togglePermission(role.id, perm.code, perm.id)}
                                                disabled={role.name === 'Admin'} // Admin has all by default usually
                                                className={`p-2 rounded-full transition-colors ${hasPerm ? 'bg-green-100 text-green-600' : 'bg-gray-100 text-gray-300'
                                                    }`}
                                            >
                                                {hasPerm ? <Check className="w-5 h-5" /> : <X className="w-5 h-5" />}
                                            </button>
                                        </td>
                                    );
                                })}
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        </div>
    );
};

export default RoleManagement;
