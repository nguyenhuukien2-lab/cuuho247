import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { getRescuers } from '../lib/adminApi'
import { codeValue, countValue, dateValue, matchesSearch, newestFirst, statusValue, textValue } from '../lib/adminFormat'
import { useAdminData } from '../hooks/useAdminData'
import { RescuerActions } from '../components/ui/AdminAction'
import { useAdminAction } from '../hooks/useAdminAction'
import { DataState, DataTable, ReloadButton, SearchFilter, UnsupportedButton } from '../components/ui/AdminData'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { StatCard } from '../components/ui/StatCard'
import { StatusBadge } from '../components/ui/StatusBadge'

export function RescuersPage() {
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState('')
  const resource = useAdminData(getRescuers, ['rescuer_profiles', 'rescuer_online_status', 'rescuer_vehicles', 'rescuer_service_capabilities', 'rescue_request_assignments', 'customer_request_reviews'])
  const action = useAdminAction(resource.reload)
  const all = useMemo(() => newestFirst(resource.data ?? []), [resource.data])
  const rows = useMemo(() => all.filter((row) => (!status || row.approval_status === status) && matchesSearch(query, row.full_name, row.phone, row.email, codeValue(row.rescuer_code))), [all, query, status])
  return <><PageHeader eyebrow="HỆ THỐNG ĐỐI TÁC" title="Đối Tác Cứu Hộ" description="Kiểm duyệt hồ sơ và theo dõi trạng thái hoạt động của đối tác." actions={<><ReloadButton resource={resource}/><UnsupportedButton>Xuất báo cáo</UnsupportedButton><UnsupportedButton>Thêm đối tác</UnsupportedButton></>}/>{action.notice}
    <DataState resource={resource}><div className="stat-grid cols-5">
      <StatCard label="Tổng đối tác" value={String(all.length)} icon="truck"/>
      <StatCard label="Chờ duyệt" value={String(all.filter((row) => row.approval_status === 'submitted').length)} icon="clock"/>
      <StatCard label="Đã duyệt" value={String(all.filter((row) => row.approval_status === 'approved').length)} tone="green"/>
      <StatCard label="Sẵn sàng nhận đơn" value={String(all.filter((row) => row.is_available).length)}/>
      <StatCard label="Đã khóa" value={String(all.filter((row) => row.approval_status === 'suspended').length)} tone="red"/>
    </div><SectionCard title="Danh sách Đối Tác & Đội Xe">
      <SearchFilter query={query} onQuery={setQuery} status={status} onStatus={setStatus} options={['draft', 'submitted', 'approved', 'rejected', 'suspended']} placeholder="Tìm tên, số điện thoại, email, mã đối tác..."/>
      <DataTable rows={rows} rowKey={(row) => row.rescuer_id} emptyTitle="Chưa có đối tác cứu hộ" columns={[
        { label: 'Đối tác', render: (row) => <><Link className="row-title" to={'/rescuers/' + row.rescuer_id}>{textValue(row.full_name)}</Link><small>{codeValue(row.rescuer_code)}</small></> },
        { label: 'Liên hệ', render: (row) => <>{textValue(row.phone)}<small>{textValue(row.email)}</small></> },
        { label: 'Hồ sơ', render: (row) => <StatusBadge>{statusValue(row.approval_status)}</StatusBadge> },
        { label: 'Kết nối / Sẵn sàng', render: (row) => <>{row.online_status === null ? 'Chưa có dữ liệu' : row.online_status ? 'Trực tuyến' : 'Ngoại tuyến'}<small>{row.is_available ? 'Sẵn sàng nhận đơn' : 'Chưa sẵn sàng'}</small></> },
        { label: 'Xe / Dịch vụ', render: (row) => countValue(row.vehicle_count) + ' / ' + countValue(row.service_count) },
        { label: 'Ca hoàn tất', render: (row) => countValue(row.completed_jobs) },
        { label: 'Đánh giá', render: (row) => countValue(row.average_rating) + ' / 5' },
        { label: 'Ngày tạo', render: (row) => dateValue(row.created_at) },
        { label: 'Thao tác', render: (row) => <><Link className="text-link" to={'/rescuers/' + row.rescuer_id}>Xem chi tiết</Link><RescuerActions rescuer={row} open={action.open}/></> },
      ]}/>
    </SectionCard></DataState>{action.dialog}</>
}
