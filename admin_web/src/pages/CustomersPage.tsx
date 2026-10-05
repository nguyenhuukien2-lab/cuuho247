import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { getCustomers } from '../lib/adminApi'
import { codeValue, countValue, dateValue, matchesSearch, moneyValue, newestFirst, numberValue, statusValue, textValue } from '../lib/adminFormat'
import { initials } from '../lib/format'
import { useAdminData } from '../hooks/useAdminData'
import { DataState, DataTable, ReloadButton, SearchFilter, UnsupportedButton } from '../components/ui/AdminData'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { StatCard } from '../components/ui/StatCard'
import { StatusBadge } from '../components/ui/StatusBadge'

export function CustomersPage() {
  const [query, setQuery] = useState('')
  const resource = useAdminData(getCustomers, ['customer_profiles', 'customer_vehicles', 'customer_saved_addresses', 'rescue_requests'])
  const all = useMemo(() => newestFirst(resource.data ?? []), [resource.data])
  const rows = useMemo(() => all.filter((row) => matchesSearch(query, row.full_name, row.phone, row.email, codeValue(row.customer_code))), [all, query])
  return <><PageHeader eyebrow="KHÁCH HÀNG / CƠ SỞ DỮ LIỆU" title="Quản lý Khách hàng" description="Thông tin tài khoản và hoạt động cứu hộ của khách hàng." actions={<><ReloadButton resource={resource}/><UnsupportedButton>Xuất danh sách</UnsupportedButton><UnsupportedButton>Thêm khách hàng</UnsupportedButton></>}/>
    <DataState resource={resource}><div className="stat-grid">
      <StatCard label="Khách hàng" value={String(all.length)} icon="users"/>
      <StatCard label="Phương tiện đã lưu" value={countValue(all.reduce((sum, row) => sum + numberValue(row.vehicle_count), 0))} icon="truck"/>
      <StatCard label="Địa chỉ đã lưu" value={countValue(all.reduce((sum, row) => sum + numberValue(row.address_count), 0))}/>
      <StatCard label="Yêu cầu cứu hộ" value={countValue(all.reduce((sum, row) => sum + numberValue(row.request_count), 0))}/>
    </div><SectionCard title="Danh sách khách hàng" subtitle="Thông tin được cập nhật từ hệ thống tài khoản">
      <SearchFilter query={query} onQuery={setQuery} placeholder="Tìm tên, số điện thoại, email, mã khách..."/>
      <DataTable rows={rows} rowKey={(row) => row.customer_id} emptyTitle="Chưa có khách hàng" columns={[
        { label: 'Khách hàng', render: (row) => <div className="table-person"><span className="avatar">{initials(row.full_name || '?')}</span><div><Link className="row-title" to={'/customers/' + row.customer_id}>{textValue(row.full_name)}</Link><small>{codeValue(row.customer_code)}</small></div></div> },
        { label: 'Liên hệ', render: (row) => <>{textValue(row.phone)}<small>{textValue(row.email)}</small></> },
        { label: 'Số xe', render: (row) => countValue(row.vehicle_count) },
        { label: 'Số địa chỉ', render: (row) => countValue(row.address_count) },
        { label: 'Yêu cầu / Hoàn tất', render: (row) => countValue(row.request_count) + ' / ' + countValue(row.completed_count) },
        { label: 'Tổng chi tiêu', render: (row) => moneyValue(row.total_spent) },
        { label: 'Ngày tạo', render: (row) => dateValue(row.created_at) },
        { label: 'Trạng thái', render: (row) => <StatusBadge>{statusValue(row.status)}</StatusBadge> },
        { label: 'Thao tác', render: (row) => <Link className="small-button" to={'/customers/' + row.customer_id}>Xem chi tiết</Link> },
      ]}/>
    </SectionCard><div className="info-ribbon"><span>ⓘ</span><div><b>Thông tin chi tiêu</b><small>Tổng chi tiêu hiện chưa có sổ giao dịch thanh toán để đối soát.</small></div></div></DataState></>
}
