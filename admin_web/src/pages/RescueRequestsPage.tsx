import { useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { cancelRequest, getRescueRequests } from '../lib/adminApi'
import { canCancel, codeValue, dateValue, matchesSearch, moneyValue, newestFirst, serviceValue, statusValue, textValue } from '../lib/adminFormat'
import { useAdminData } from '../hooks/useAdminData'
import { useAdminAction } from '../hooks/useAdminAction'
import { DataState, DataTable, ReloadButton, SearchFilter, UnsupportedButton } from '../components/ui/AdminData'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { StatCard } from '../components/ui/StatCard'
import { StatusBadge } from '../components/ui/StatusBadge'

export function RescueRequestsPage() {
  const [params, setParams] = useSearchParams()
  const search = params.get('search') ?? ''
  const [status, setStatus] = useState('')
  const resource = useAdminData(getRescueRequests, ['rescue_requests', 'rescue_quotes', 'rescue_request_assignments'])
  const action = useAdminAction(resource.reload)
  const all = useMemo(() => newestFirst(resource.data ?? []), [resource.data])
  const rows = useMemo(() => all.filter((row) => (!status || row.status === status) && matchesSearch(search, codeValue(row.request_code), row.customer_name, row.customer_phone, row.vehicle_name, row.vehicle_plate, row.pickup_address, row.rescuer_name, serviceValue(row.service_type))), [all, status, search])
  return <><PageHeader title="Yêu cầu cứu hộ" description="Theo dõi và điều phối các ca cứu hộ trên toàn mạng lưới." actions={<><ReloadButton resource={resource}/><UnsupportedButton>Tạo yêu cầu</UnsupportedButton></>}/>{action.notice}
    <DataState resource={resource}><div className="stat-grid">
      <StatCard label="Tổng yêu cầu" value={String(all.length)}/>
      <StatCard label="Đang xử lý" value={String(all.filter((row) => canCancel(row.status) || row.status === 'in_progress').length)}/>
      <StatCard label="Hoàn tất" value={String(all.filter((row) => row.status === 'completed').length)} tone="green"/>
      <StatCard label="Đã hủy" value={String(all.filter((row) => row.status === 'cancelled').length)} tone="red"/>
    </div><SectionCard title="Danh sách yêu cầu cứu hộ" subtitle="Dữ liệu được cập nhật từ ứng dụng khách hàng và đối tác">
      <SearchFilter query={search} onQuery={(value) => setParams(value ? { search: value } : {}, { replace: true })} status={status} onStatus={setStatus} options={['searching', 'accepted', 'arriving', 'in_progress', 'completed', 'cancelled']} placeholder="Tìm mã ca, khách hàng, biển số, địa chỉ..."/>
      <DataTable rows={rows} rowKey={(row) => row.request_id} emptyTitle="Chưa có yêu cầu cứu hộ" columns={[
        { label: 'Mã ca', render: (row) => <Link className="id-link" to={'/requests/' + row.request_id}>{codeValue(row.request_code)}</Link> },
        { label: 'Khách hàng', render: (row) => <><b>{textValue(row.customer_name)}</b><small>{textValue(row.customer_phone)}</small></> },
        { label: 'Dịch vụ & xe', render: (row) => <><b>{serviceValue(row.service_type)}</b><small>{textValue(row.vehicle_name)} · {textValue(row.vehicle_plate)}</small></> },
        { label: 'Địa chỉ đón', render: (row) => textValue(row.pickup_address) },
        { label: 'Đối tác', render: (row) => textValue(row.rescuer_name) },
        { label: 'Báo giá', render: (row) => moneyValue(row.quote_amount) },
        { label: 'Trạng thái', render: (row) => <StatusBadge>{statusValue(row.status)}</StatusBadge> },
        { label: 'Thời gian tạo', render: (row) => dateValue(row.created_at) },
        { label: 'Thao tác', render: (row) => <div className="row-actions"><Link className="small-button" to={'/requests/' + row.request_id}>Xem chi tiết</Link><button className="small-button danger" disabled={!canCancel(row.status)} onClick={() => action.open({ title: 'Hủy yêu cầu cứu hộ', description: textValue(row.customer_name) + ' · ' + textValue(row.pickup_address), reason: true, run: (reason) => cancelRequest(row.request_id, reason) })}>Hủy đơn</button></div> },
      ]}/>
    </SectionCard></DataState>{action.dialog}</>
}
