import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { Download, Plus, Search, SlidersHorizontal, ArrowRight } from 'lucide-react'
import { customers, customerStats } from '../mocks/mockData'
import { formatCurrency, initials } from '../lib/format'
import { PageHeader } from '../components/ui/PageHeader'
import { StatCard } from '../components/ui/StatCard'
import { SectionCard } from '../components/ui/SectionCard'
import { StatusBadge } from '../components/ui/StatusBadge'
import { EmptyState } from '../components/ui/EmptyState'
export function CustomersPage() {
  const [query, setQuery] = useState('')
  const [tier, setTier] = useState('Hạng: Tất cả')
  const rows = useMemo(() => customers.filter((item) => (item.name + item.phone + item.email).toLocaleLowerCase('vi').includes(query.toLocaleLowerCase('vi')) && (tier === 'Hạng: Tất cả' || item.tier === tier)), [query, tier])
  const exportCsv = () => { const csv = ['Mã khách,Tên,Số điện thoại,Email', ...rows.map((item) => [item.id,item.name,item.phone,item.email].join(','))].join('\n'); const url = URL.createObjectURL(new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8' })); const a = document.createElement('a'); a.href = url; a.download = 'khach-hang-demo.csv'; a.click(); URL.revokeObjectURL(url) }
  return <><PageHeader eyebrow="MODULE KHÁCH HÀNG / CƠ SỞ DỮ LIỆU" title="Quản lý Khách hàng" description="Theo dõi tài khoản khách hàng, lịch sử cứu hộ và thông tin xe đã đăng ký trên hệ thống Cứu Hộ 24/7." actions={<><button className="button button-white" onClick={exportCsv}><Download size={15}/> Xuất danh sách</button><button className="button button-blue" onClick={() => alert('Chức năng thêm khách hàng sẽ khả dụng khi kết nối backend.')}><Plus size={15}/> Thêm khách hàng</button></>}/>
  <div className="stat-grid cols-4">{customerStats.map((item) => <StatCard key={item.label} {...item}/>)}</div>
  <SectionCard title="Danh sách khách hàng" subtitle="Thông tin được cập nhật từ hệ thống tài khoản"><div className="filter-row"><label className="search-field"><Search size={16}/><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Tìm theo tên khách hàng, SĐT, Email, biển số xe..." /></label><label className="select-field"><SlidersHorizontal size={15}/><select value={tier} onChange={(e) => setTier(e.target.value)}>{['Hạng: Tất cả','Hội viên Vàng','Hội viên','Thành viên'].map((item) => <option key={item}>{item}</option>)}</select></label></div>{rows.length ? <div className="table-scroll"><table><thead><tr><th>Khách hàng</th><th>Liên hệ</th><th>Hạng thành viên</th><th>Phương tiện đã lưu</th><th>Đơn cứu hộ</th><th>Tổng chi tiêu</th><th>Trạng thái</th><th></th></tr></thead><tbody>{rows.map((item) => <tr key={item.id}><td><div className="table-person"><span className="avatar">{initials(item.name)}</span><div><Link className="row-title" to={'/customers/' + item.id}>{item.name}</Link><small>{item.id}</small></div></div></td><td><b>{item.phone}</b><small>{item.email}</small></td><td><span className="tier-pill">{item.tier}</span></td><td><b>{item.vehicle.split(' · ')[0]}</b><small>{item.vehicle.split(' · ')[1]}</small></td><td><span className="number-pill">{item.orders}</span></td><td><b>{formatCurrency(item.spent)}</b></td><td><StatusBadge>{item.status}</StatusBadge></td><td><Link to={'/customers/' + item.id} className="icon-button" aria-label={'Xem ' + item.name}><ArrowRight size={16}/></Link></td></tr>)}</tbody></table></div> : <EmptyState/>}<div className="table-footer">Hiển thị {rows.length} trong tổng số 12,480 khách hàng <span>‹ &nbsp; <b>1</b> &nbsp; 2 &nbsp; 3 &nbsp; ... &nbsp; 125 &nbsp; ›</span></div></SectionCard><div className="info-ribbon"><span>ⓘ</span><div><b>Cần đồng bộ hóa dữ liệu Khách hàng từ Tổng đài?</b><small>Lịch sử dịch vụ, GPS sự cố và thông tin hợp đồng bảo hiểm xe được tự động cập nhật một khi kết nối API thật.</small></div><button className="button button-white" onClick={() => alert('Dữ liệu demo đang được sử dụng.')}>Xem báo cáo đồng bộ</button></div></>
}


