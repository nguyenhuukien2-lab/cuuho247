import { supabase } from '../lib/supabase'
import { apiError } from '../lib/adminApi'
import { dateValue, textValue } from '../lib/adminFormat'
import type { ApiResult } from '../lib/adminTypes'
import { useAdminData } from '../hooks/useAdminData'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { EmptyState } from '../components/ui/EmptyState'
import { DataState, DataTable, ReloadButton, UnsupportedButton } from '../components/ui/AdminData'

type Notification = {
  id: string
  title: string
  body: string
  target_type: string
  created_at: string
}

const targetNames: Record<string, string> = {
  all: 'Tất cả',
  customers: 'Khách hàng',
  rescuers: 'Đối tác cứu hộ',
  single_customer: 'Một khách hàng',
  single_rescuer: 'Một đối tác',
}

async function loadNotifications(signal?: AbortSignal): Promise<ApiResult<Notification[]>> {
  try {
    let query = supabase.from('admin_notifications')
      .select('id,title,body,target_type,created_at')
      .order('created_at', { ascending: false }).limit(100)
    if (signal) query = query.abortSignal(signal)
    const { data, error } = await query
    return error ? { data: null, error: apiError(error) } : { data: (data ?? []) as Notification[], error: null }
  } catch (error) {
    return { data: null, error: apiError(error) }
  }
}

export function NotificationsPage() {
  const resource = useAdminData(loadNotifications)
  return <><PageHeader title="Thông báo" description="Xem các bản ghi thông báo đã lưu; chưa xác nhận việc gửi đến thiết bị." actions={<ReloadButton resource={resource}/>}/>
    <div className="settings-grid"><SectionCard title="Thông báo trong hệ thống" subtitle="100 bản ghi mới nhất"><DataState resource={resource}><DataTable rows={resource.data ?? []} rowKey={(row) => row.id} emptyTitle="Chưa có dữ liệu thông báo." columns={[
      { label: 'Thời gian', render: (row) => dateValue(row.created_at) },
      { label: 'Tiêu đề', render: (row) => textValue(row.title) },
      { label: 'Nội dung', render: (row) => textValue(row.body) },
      { label: 'Đối tượng', render: (row) => targetNames[row.target_type] ?? textValue(row.target_type) },
    ]}/></DataState></SectionCard>
      <SectionCard title="Gửi thông báo" subtitle="Chưa hỗ trợ gửi thật"><EmptyState title="Chức năng gửi thông báo thật chưa được bật." description="Biểu mẫu và thao tác gửi sẽ mở khi có API gửi thật."/><div className="broadcast"><label>Tiêu đề<input disabled placeholder="Chưa hỗ trợ"/></label><label>Nội dung<textarea disabled placeholder="Chưa hỗ trợ"/></label><div className="button-pair"><UnsupportedButton>Gửi thông báo</UnsupportedButton><UnsupportedButton>Hẹn giờ</UnsupportedButton></div></div></SectionCard></div></>
}
