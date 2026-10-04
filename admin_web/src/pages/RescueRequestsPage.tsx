import { useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { Search, SlidersHorizontal, ArrowRight, Plus, Radio } from 'lucide-react'
import { rescueRequests, requestOverview } from '../mocks/mockData'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { StatusBadge } from '../components/ui/StatusBadge'
import { EmptyState } from '../components/ui/EmptyState'
export function RescueRequestsPage() {
  const [params] = useSearchParams()
  const [search, setSearch] = useState(params.get('search') ?? '')
  const [status, setStatus] = useState('Tất cả trạng thái')
  const filtered = useMemo(() => rescueRequests.filter((item) => (item.id + item.customer + item.vehicle + item.service).toLocaleLowerCase('vi').includes(search.toLocaleLowerCase('vi')) && (status === 'Tất cả trạng thái' || item.status === status)), [search, status])
  return <><PageHeader title="Yêu cầu cứu hộ" description="Theo dõi và điều phối các ca cứu hộ trên toàn mạng lưới." actions={<button className="button button-blue" onClick={() => alert('Tính năng tạo yêu cầu sẽ kết nối khi có backend.') }><Plus size={16}/> Tạo yêu cầu</button>}/><div className="stat-grid cols-4">{requestOverview.map((item) => <div className="overview-tile" key={item.label}><span>{item.label}</span><strong className={item.tone}>{item.value}</strong><small>{item.note}</small></div>)}</div><SectionCard title="Danh sách yêu cầu cứu hộ" subtitle="Dữ liệu mô phỏng theo thời gian thực" action={<span className="soft-pill"><Radio size={13}/> Cập nhật trực tiếp</span>}><div className="filter-row"><label className="search-field"><Search size={16}/><input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Tìm mã ca, khách hàng, phương tiện..." /></label><label className="select-field"><SlidersHorizontal size={15}/><select value={status} onChange={(e) => setStatus(e.target.value)}>{['Tất cả trạng thái','Đang xử lý','Chờ điều phối','Hoàn tất','Đã hủy'].map((item) => <option key={item}>{item}</option>)}</select></label></div>{filtered.length ? <div className="table-scroll"><table><thead><tr><th>Mã ca</th><th>Khách hàng</th><th>Sự cố & vị trí</th><th>Dịch vụ</th><th>Đội cứu hộ</th><th>Trạng thái</th><th></th></tr></thead><tbody>{filtered.map((item) => <tr key={item.id}><td><Link className="id-link" to={'/requests/' + item.id}>{item.id}</Link><small>{item.time}</small></td><td><b>{item.customer}</b><small>{item.phone}</small></td><td><b>{item.incident}</b><small>{item.location}</small></td><td>{item.service}</td><td>{item.team}</td><td><StatusBadge>{item.status}</StatusBadge></td><td><Link className="icon-button" to={'/requests/' + item.id} aria-label={'Xem ' + item.id}><ArrowRight size={16}/></Link></td></tr>)}</tbody></table></div> : <EmptyState/>}</SectionCard></>
}

