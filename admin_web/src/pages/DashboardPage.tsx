import { useState } from 'react'
import { ArrowRight, CalendarDays, ClipboardList, MapPinned, Radio, ShieldCheck, Siren, Star } from 'lucide-react'
import { Link } from 'react-router-dom'
import { getDashboardStats, getRescueRequests } from '../lib/adminApi'
import { useAdminData } from '../hooks/useAdminData'
import { codeValue, countValue, dateValue, moneyValue, newestFirst, serviceValue, statusValue, textValue } from '../lib/adminFormat'
import type { DashboardStats } from '../lib/adminTypes'
import type { Tone } from '../lib/uiTypes'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { StatCard } from '../components/ui/StatCard'
import { StatusBadge } from '../components/ui/StatusBadge'
import { EmptyState } from '../components/ui/EmptyState'
import { DataState, DataTable, ReloadButton } from '../components/ui/AdminData'
import { RequestBreakdown, RequestTrend } from '../components/dashboard/RequestCharts'

async function loadDashboard(signal?: AbortSignal) {
  const [stats, requests] = await Promise.all([getDashboardStats(signal), getRescueRequests(signal)])
  if (stats.error) return { data: null, error: stats.error }
  return { data: { loadedAt: new Date().toISOString(), stats: stats.data ?? {}, requests: newestFirst(requests.data ?? []), requestsError: requests.error }, error: null }
}

const cards: { key: keyof DashboardStats; label: string; icon: string; tone: Tone; note: string }[] = [
  { key: 'total_customers', label: 'Tổng khách hàng', icon: 'users', tone: 'blue', note: 'Khách hàng trên toàn hệ thống' },
  { key: 'total_rescuers', label: 'Tổng đối tác', icon: 'shield', tone: 'orange', note: 'Mạng lưới đối tác cứu hộ' },
  { key: 'today_requests', label: 'Yêu cầu hôm nay', icon: 'clipboard', tone: 'blue', note: 'Yêu cầu được tạo trong ngày' },
  { key: 'active_requests', label: 'Đang xử lý', icon: 'clock', tone: 'blue', note: 'Các ca cứu hộ đang hoạt động' },
  { key: 'completed_requests', label: 'Đã hoàn tất', icon: 'check', tone: 'green', note: 'Tổng ca cứu hộ hoàn thành' },
  { key: 'cancelled_requests', label: 'Đã hủy', icon: 'x', tone: 'red', note: 'Tổng yêu cầu đã được hủy' },
  { key: 'today_revenue', label: 'Báo giá hôm nay', icon: 'wallet', tone: 'blue', note: 'Giá trị phát hành, chưa phải thực thu' },
  { key: 'online_rescuers', label: 'Đối tác trực tuyến', icon: 'truck', tone: 'orange', note: 'Đã duyệt, có kết nối gần đây' },
]

export function DashboardPage() {
  const resource = useAdminData(loadDashboard, ['rescue_requests', 'rescuer_online_status', 'rescuer_profiles', 'customer_profiles', 'rescue_quotes', 'customer_request_reviews'])
  const [days, setDays] = useState(7)
  const stats = resource.data?.stats ?? {}
  const requests = resource.data?.requests ?? []
  const recent = requests.slice(0, 5)
  const requestsError = resource.data?.requestsError
  const requestError = <div className="data-error" role="alert">Không thể tải danh sách yêu cầu. {requestsError}<ReloadButton resource={resource}/></div>

  return <div className="dashboard-page">
    <PageHeader title="Tổng quan hệ thống" description="Theo dõi hoạt động cứu hộ, đối tác và chất lượng dịch vụ trên toàn mạng lưới." actions={<><ReloadButton resource={resource}/><Link className="button button-danger" to="/requests"><Siren size={17}/>Điều phối khẩn cấp</Link></>}/>
    <DataState resource={resource}>
      <div className="dashboard-context"><span><Radio size={14}/>{resource.realtimeWarning ? 'Đang cập nhật định kỳ' : 'Dữ liệu vận hành'}</span><span><CalendarDays size={14}/>Hôm nay · {new Intl.DateTimeFormat('vi-VN', { dateStyle: 'long', timeZone: 'Asia/Ho_Chi_Minh' }).format(new Date(resource.data?.loadedAt ?? 0))}</span></div>
      <div className="stat-grid dashboard-stats">{cards.map(({ key, label, icon, tone, note }) => <StatCard key={key} label={label} icon={icon} tone={tone}
        value={key === 'today_revenue' ? (stats.revenue_visible === false ? '—' : moneyValue(stats.today_revenue)) : stats[key] == null ? '—' : countValue(stats[key] as number | string)}
        note={key === 'today_revenue' && stats.revenue_visible === false ? 'Tài khoản không có quyền xem số tiền' : note}/>)}</div>
      <div className="dashboard-charts">
        <SectionCard title="Xu hướng yêu cầu cứu hộ" subtitle="Số yêu cầu theo ngày tạo · Giờ Việt Nam" action={<label className="chart-period"><span className="sr-only">Khoảng thời gian biểu đồ</span><select value={days} onChange={(event) => setDays(Number(event.target.value))}><option value={7}>7 ngày gần nhất</option><option value={14}>14 ngày gần nhất</option></select></label>}>
          {requestsError ? requestError : <RequestTrend requests={requests} days={days} now={resource.data?.loadedAt ?? '1970-01-01T00:00:00Z'}/>}
        </SectionCard>
        <SectionCard title="Phân bổ trạng thái" subtitle="Toàn bộ yêu cầu hiện có">
          {requestsError ? <EmptyState title="Chưa tải được thống kê yêu cầu" description="Tải lại để xem phân bổ trạng thái."/> : <RequestBreakdown requests={requests}/>}
        </SectionCard>
      </div>
      <div className="dashboard-bottom">
        <SectionCard title="Yêu cầu cứu hộ mới nhất" subtitle="Nắm bắt tình hình và tiếp tục điều phối" action={<Link className="text-link" to="/requests">Xem tất cả <ArrowRight size={15}/></Link>}>
          {requestsError ? requestError : <DataTable rows={recent} rowKey={(row) => row.request_id} emptyTitle="Chưa có yêu cầu cứu hộ" columns={[
            { label: 'Mã ca', render: (row) => <Link className="id-link" to={'/requests/' + row.request_id}>{codeValue(row.request_code)}</Link> },
            { label: 'Khách hàng / Xe', render: (row) => <><b>{textValue(row.customer_name)}</b><small>{textValue(row.vehicle_plate)}</small></> },
            { label: 'Dịch vụ / Đối tác', render: (row) => <><b>{serviceValue(row.service_type)}</b><small>{textValue(row.rescuer_name)}</small></> },
            { label: 'Trạng thái', render: (row) => <StatusBadge>{statusValue(row.status)}</StatusBadge> },
            { label: 'Thời gian tạo', render: (row) => dateValue(row.created_at) },
          ]}/>}
          <div className="dashboard-table-note"><ShieldCheck size={15}/>Chọn mã ca để xem thông tin và thao tác điều hành.</div>
        </SectionCard>
        <SectionCard title="Tình hình điều hành" subtitle="Thông tin cần theo dõi">
          <div className="operation-metrics"><Link to="/rescuers"><span className="icon-box orange"><ShieldCheck size={19}/></span><span>Đối tác chờ duyệt<strong>{stats.pending_rescuers == null ? '—' : countValue(stats.pending_rescuers)}</strong></span><ArrowRight size={16}/></Link><Link to="/reviews"><span className="icon-box blue"><Star size={19}/></span><span>Đánh giá trung bình<strong>{stats.average_rating == null ? '—' : countValue(stats.average_rating)} <small>/ 5</small></strong></span><ArrowRight size={16}/></Link></div>
          <h3 className="mini-heading">CA CỨU HỘ GẦN ĐÂY</h3>
          <div className="activity-list">{recent.slice(0, 3).map((row) => <Link className="activity-item" to={'/requests/' + row.request_id} key={row.request_id}><span className="activity-icon blue"><ClipboardList size={15}/></span><div><b>{codeValue(row.request_code)} · {statusValue(row.status)}</b><small>{textValue(row.customer_name)} · {serviceValue(row.service_type)}</small><em>Tạo lúc {dateValue(row.created_at)}</em></div><ArrowRight size={14}/></Link>)}</div>
          {!recent.length && <p className="muted-note">{requestsError ? 'Chưa tải được các ca cứu hộ.' : 'Chưa có ca cứu hộ để theo dõi.'}</p>}
          <Link className="button button-soft full-width" to="/audit-logs">Xem nhật ký quản trị <ArrowRight size={15}/></Link>
        </SectionCard>
      </div>
      <div className="bottom-banner"><span className="banner-icon"><MapPinned size={25}/></span><div><b>Trung tâm điều hành cứu hộ</b><small>Theo dõi yêu cầu và đối tác. Bản đồ vị trí đang chờ kết nối GPS.</small></div><Link className="button button-outline-light" to="/map">Mở bản đồ hoạt động <ArrowRight size={16}/></Link></div>
    </DataState>
  </div>
}
