import { supabase } from '../lib/supabase'
import { apiError } from '../lib/adminApi'
import { dateValue, textValue } from '../lib/adminFormat'
import type { ApiResult } from '../lib/adminTypes'
import { useAdminData } from '../hooks/useAdminData'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { DataState, DataTable, ReloadButton } from '../components/ui/AdminData'

type AuditLog = {
  id: string
  admin_id: string | null
  action: string
  target_table: string | null
  created_at: string
}
type AuditEntry = AuditLog & { actor_name: string | null }

const actionNames: Record<string, string> = {
  approve_rescuer: 'Duyệt đối tác',
  reject_rescuer: 'Từ chối đối tác',
  block_rescuer: 'Khóa đối tác',
  cancel_request: 'Hủy đơn cứu hộ',
  toggle_service: 'Thay đổi trạng thái dịch vụ',
}
const targetNames: Record<string, string> = {
  rescuer_profiles: 'Đối tác cứu hộ',
  rescue_requests: 'Đơn cứu hộ',
  rescue_services: 'Dịch vụ',
}

async function loadAuditLogs(signal?: AbortSignal): Promise<ApiResult<AuditEntry[]>> {
  try {
    let query = supabase.from('admin_audit_logs')
      .select('id,admin_id,action,target_table,created_at')
      .order('created_at', { ascending: false }).limit(100)
    if (signal) query = query.abortSignal(signal)
    const { data, error } = await query
    if (error) return { data: null, error: apiError(error) }

    const logs = (data ?? []) as AuditLog[]
    const actorIds = [...new Set(logs.map((log) => log.admin_id).filter((id): id is string => !!id))]
    if (!actorIds.length) return { data: logs.map((log) => ({ ...log, actor_name: null })), error: null }

    let profileQuery = supabase.from('admin_profiles').select('id,full_name').in('id', actorIds)
    if (signal) profileQuery = profileQuery.abortSignal(signal)
    const { data: profiles, error: profileError } = await profileQuery
    if (profileError) return { data: null, error: apiError(profileError) }
    const names = new Map((profiles ?? []).map((profile) => [profile.id, profile.full_name]))
    return { data: logs.map((log) => ({ ...log, actor_name: log.admin_id ? names.get(log.admin_id) ?? null : null })), error: null }
  } catch (error) {
    return { data: null, error: apiError(error) }
  }
}

export function AuditLogsPage() {
  const resource = useAdminData(loadAuditLogs)
  return <><PageHeader title="Nhật ký quản trị" description="100 thao tác quản trị mới nhất được lưu trong hệ thống." actions={<ReloadButton resource={resource}/>}/>
    <DataState resource={resource}><SectionCard title="Lịch sử thao tác"><DataTable rows={resource.data ?? []} rowKey={(row) => row.id} emptyTitle="Chưa có dữ liệu nhật ký quản trị." columns={[
      { label: 'Thời gian', render: (row) => dateValue(row.created_at) },
      { label: 'Quản trị viên', render: (row) => textValue(row.actor_name) },
      { label: 'Thao tác', render: (row) => actionNames[row.action] ?? textValue(row.action) },
      { label: 'Đối tượng', render: (row) => row.target_table ? targetNames[row.target_table] ?? row.target_table : 'Chưa có dữ liệu' },
    ]}/></SectionCard></DataState></>
}
