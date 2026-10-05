import { Link } from 'react-router-dom'
import { getDashboardStats, getRescueRequests } from '../lib/adminApi'
import { useAdminData } from '../hooks/useAdminData'
import { codeValue, countValue, dateValue, moneyValue, newestFirst, statusValue, textValue } from '../lib/adminFormat'
import type { DashboardStats } from '../lib/adminTypes'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { StatCard } from '../components/ui/StatCard'
import { StatusBadge } from '../components/ui/StatusBadge'
import { EmptyState } from '../components/ui/EmptyState'
import { DataState, DataTable, ReloadButton } from '../components/ui/AdminData'

async function loadDashboard(signal?: AbortSignal) {
  const [stats, requests] = await Promise.all([getDashboardStats(signal), getRescueRequests(signal)])
  if (stats.error) return { data: null, error: stats.error }
  return { data: { stats: stats.data ?? {}, requests: newestFirst(requests.data ?? []).slice(0, 5), requestsError: requests.error }, error: null }
}
const cards: { key: keyof DashboardStats; label: string; icon: string }[] = [
  { key: 'total_customers', label: 'Tổng khách hàng', icon: 'users' },
  { key: 'total_rescuers', label: 'Tổng đối tác', icon: 'truck' },
  { key: 'today_requests', label: 'Yêu cầu hôm nay', icon: 'clipboard' },
  { key: 'active_requests', label: 'Đang xử lý', icon: 'clock' },
  { key: 'completed_requests', label: 'Đã hoàn tất', icon: 'check' },
  { key: 'cancelled_requests', label: 'Đã hủy', icon: 'x' },
  { key: 'today_revenue', label: 'Giá trị báo giá hôm nay', icon: 'wallet' },
  { key: 'online_rescuers', label: 'Đối tác sẵn sàng trực tuyến', icon: 'truck' },
  { key: 'pending_rescuers', label: 'Đối tác chờ duyệt', icon: 'shield' },
  { key: 'average_rating', label: 'Đánh giá trung bình', icon: 'check' },
]
export function DashboardPage() {
  const resource = useAdminData(loadDashboard, ['rescue_requests', 'rescuer_online_status', 'rescuer_profiles', 'customer_profiles', 'rescue_quotes', 'customer_request_reviews'])
  const stats = resource.data?.stats ?? {}
  return <><PageHeader title="Tổng quan hệ thống" description="Theo dõi hoạt động cứu hộ và đối tác trên toàn mạng lưới." actions={<><ReloadButton resource={resource}/><Link className="button button-danger" to="/requests">SOS · Điều phối khẩn cấp</Link></>}/>
    <DataState resource={resource}>
      <div className="stat-grid cols-5">{cards.map(({ key, label, icon }) => <StatCard key={key} label={label} icon={icon} value={key === 'today_revenue' ? moneyValue(stats.today_revenue ?? 0) : countValue(stats[key] as number | null | undefined)} note={key === 'today_revenue' ? (stats.revenue_visible === false ? 'Tài khoản không có quyền xem số tiền' : 'Báo giá phát hành, chưa phải tiền đã thu') : undefined}/>)}</div>
      <div className="dashboard-charts"><SectionCard title="Xu hướng đơn cứu hộ 7 ngày gần nhất"><EmptyState title="Chưa có dữ liệu biểu đồ thật" description="Biểu đồ sẽ hiển thị khi nguồn thống kê được kết nối."/></SectionCard><SectionCard title="Phân bổ trạng thái"><EmptyState title="Chưa có dữ liệu biểu đồ thật" description="Xem số lượng hiện tại trên các thẻ tổng quan."/></SectionCard></div>
      <div className="dashboard-bottom"><SectionCard title="Yêu cầu cứu hộ mới nhất" action={<Link className="text-link" to="/requests">Xem tất cả yêu cầu</Link>}>
        {resource.data?.requestsError ? <div className="data-error" role="alert">{resource.data.requestsError}<ReloadButton resource={resource}/></div> : <DataTable rows={resource.data?.requests ?? []} rowKey={(row) => row.request_id} emptyTitle="Chưa có yêu cầu cứu hộ" columns={[
          { label: 'Mã ca', render: (row) => <Link className="id-link" to={'/requests/' + row.request_id}>{codeValue(row.request_code)}</Link> },
          { label: 'Khách hàng', render: (row) => textValue(row.customer_name) },
          { label: 'Đối tác', render: (row) => textValue(row.rescuer_name) },
          { label: 'Trạng thái', render: (row) => <StatusBadge>{statusValue(row.status)}</StatusBadge> },
          { label: 'Thời gian tạo', render: (row) => dateValue(row.created_at) },
        ]}/>}
      </SectionCard><SectionCard title="Hoạt động điều hành"><EmptyState title="Chưa kết nối dòng sự kiện" description="Xem yêu cầu cứu hộ để theo dõi trạng thái mới nhất."/><Link className="button button-soft full-width" to="/audit-logs">Nhật ký quản trị</Link></SectionCard></div>
      <div className="bottom-banner"><div><b>Bản đồ điều hành cứu hộ</b><small>Bản đồ đang chờ kết nối dữ liệu GPS thật</small></div><Link className="button button-outline-light" to="/map">Mở bản đồ điều hành</Link></div>
    </DataState>
  </>
}
