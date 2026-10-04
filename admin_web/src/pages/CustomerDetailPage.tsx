import { Link, useParams } from 'react-router-dom'
import { ArrowLeft, Car, Mail, Phone, UserRound } from 'lucide-react'
import { customers, rescueRequests } from '../mocks/mockData'
import { formatCurrency, initials } from '../lib/format'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { StatusBadge } from '../components/ui/StatusBadge'
import { EmptyState } from '../components/ui/EmptyState'
export function CustomerDetailPage() {
  const { id } = useParams(); const customer = customers.find((item) => item.id === id)
  if (!customer) return <EmptyState title="Không tìm thấy khách hàng"/>
  const orders = rescueRequests.filter((item) => item.customer === customer.name)
  return <><PageHeader eyebrow="KHÁCH HÀNG / HỒ SƠ" title={customer.name} description={'Hồ sơ khách hàng ' + customer.id} actions={<Link className="button button-white" to="/customers"><ArrowLeft size={15}/> Danh sách khách hàng</Link>}/><div className="detail-grid"><SectionCard title="Thông tin khách hàng"><div className="profile-line"><span className="avatar large">{initials(customer.name)}</span><div><h3>{customer.name}</h3><p>{customer.tier} · <StatusBadge>{customer.status}</StatusBadge></p></div></div><div className="info-list"><div><Phone size={16}/><span>{customer.phone}</span></div><div><Mail size={16}/><span>{customer.email}</span></div><div><Car size={16}/><span>{customer.vehicle}</span></div><div><UserRound size={16}/><span>{customer.orders} đơn cứu hộ · {formatCurrency(customer.spent)} đã chi tiêu</span></div></div></SectionCard><SectionCard title="Lịch sử cứu hộ gần đây"><div className="table-scroll"><table><thead><tr><th>Mã ca</th><th>Dịch vụ</th><th>Vị trí</th><th>Trạng thái</th></tr></thead><tbody>{orders.map((item) => <tr key={item.id}><td><Link className="id-link" to={'/requests/' + item.id}>{item.id}</Link></td><td>{item.service}</td><td>{item.location}</td><td><StatusBadge>{item.status}</StatusBadge></td></tr>)}</tbody></table></div>{!orders.length && <EmptyState title="Chưa có ca cứu hộ trong dữ liệu demo"/>}</SectionCard></div></>
}
