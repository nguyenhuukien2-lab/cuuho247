import { useMemo, useState } from 'react'
import { getQuotes } from '../lib/adminApi'
import { codeValue, dateValue, matchesSearch, moneyValue, newestFirst, numberValue, serviceValue, statusValue, textValue } from '../lib/adminFormat'
import { useAdminData } from '../hooks/useAdminData'
import { DataState, DataTable, ReloadButton, SearchFilter, UnsupportedButton } from '../components/ui/AdminData'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { StatCard } from '../components/ui/StatCard'
import { StatusBadge } from '../components/ui/StatusBadge'
import { EmptyState } from '../components/ui/EmptyState'

export function QuotesPage() {
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState('')
  const resource = useAdminData(getQuotes, ['rescue_quotes', 'rescue_request_assignments'])
  const all = useMemo(() => newestFirst(resource.data ?? []), [resource.data])
  const current = all.filter((row) => row.is_current)
  const rows = useMemo(() => all.filter((row) => (!status || row.status === status) && matchesSearch(query, codeValue(row.quote_code), codeValue(row.request_code), row.customer_name, row.rescuer_name, serviceValue(row.service_type))), [all, status, query])
  return <><PageHeader eyebrow="TÀI CHÍNH & QUẢN TRỊ" title="Báo giá & Doanh thu Cứu Hộ" description="Theo dõi báo giá dịch vụ. Giá trị báo giá chưa xác nhận số tiền đã thu." actions={<><ReloadButton resource={resource}/><UnsupportedButton>Xuất Excel</UnsupportedButton></>}/>
    <DataState resource={resource}><div className="stat-grid">
      <StatCard label="Tổng phiên bản báo giá" value={String(all.length)}/>
      <StatCard label="Báo giá hiện hành" value={String(current.length)}/>
      <StatCard label="Giá trị báo giá hiện hành" value={moneyValue(current.reduce((sum, row) => sum + numberValue(row.amount), 0))} icon="wallet"/>
      <StatCard label="Báo giá của ca hoàn tất" value={String(all.filter((row) => row.is_completion_quote).length)} tone="green"/>
    </div><div className="dashboard-charts"><SectionCard title="Doanh thu theo tuần & ngày"><EmptyState title="Chưa có dữ liệu biểu đồ thật" description="Biểu đồ doanh thu chưa được kết nối."/></SectionCard><SectionCard title="Cơ cấu nguồn thu"><EmptyState title="Chưa có dữ liệu biểu đồ thật" description="Chưa có dữ liệu đối soát thanh toán."/></SectionCard></div>
      <SectionCard title="Chi tiết báo giá"><SearchFilter query={query} onQuery={setQuery} status={status} onStatus={setStatus} options={[...new Set(all.map((row) => row.status).filter((value): value is string => !!value))]} placeholder="Tìm mã báo giá, mã ca, khách hàng, đối tác..."/>
        <DataTable rows={rows} rowKey={(row) => row.quote_id} emptyTitle="Chưa có báo giá" columns={[
          { label: 'Mã báo giá', render: (row) => codeValue(row.quote_code) },
          { label: 'Mã ca', render: (row) => codeValue(row.request_code) },
          { label: 'Khách hàng', render: (row) => textValue(row.customer_name) },
          { label: 'Đối tác', render: (row) => textValue(row.rescuer_name) },
          { label: 'Dịch vụ', render: (row) => serviceValue(row.service_type) },
          { label: 'Số tiền', render: (row) => moneyValue(row.amount) },
          { label: 'Ghi chú', render: (row) => textValue(row.note) },
          { label: 'Trạng thái', render: (row) => <><StatusBadge>{statusValue(row.status)}</StatusBadge><small>{row.is_current ? 'Hiện hành' : 'Phiên bản cũ'}</small></> },
          { label: 'Ngày tạo', render: (row) => dateValue(row.created_at) },
        ]}/>
      </SectionCard>
    </DataState></>
}
