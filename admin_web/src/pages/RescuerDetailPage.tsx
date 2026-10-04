import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { ArrowLeft, MapPin, Phone, ShieldCheck, Star, Truck } from 'lucide-react'
import { rescuers } from '../mocks/mockData'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { StatusBadge } from '../components/ui/StatusBadge'
import { EmptyState } from '../components/ui/EmptyState'
export function RescuerDetailPage() {
  const { id } = useParams(); const partner = rescuers.find((item) => item.id === id); const [approved, setApproved] = useState(false)
  if (!partner) return <EmptyState title="Không tìm thấy đối tác cứu hộ"/>
  return <><PageHeader eyebrow="ĐỐI TÁC CỨU HỘ / HỒ SƠ" title={partner.name} description={partner.area} actions={<Link className="button button-white" to="/rescuers"><ArrowLeft size={15}/> Danh sách đối tác</Link>}/><div className="detail-grid"><SectionCard title="Hồ sơ đối tác"><div className="profile-line"><span className="avatar blue large"><Truck size={25}/></span><div><h3>{partner.name}</h3><p>{partner.id} · <StatusBadge>{partner.status}</StatusBadge></p></div></div><div className="info-list"><div><ShieldCheck size={16}/><span>Đại diện: {partner.person}</span></div><div><Phone size={16}/><span>{partner.phone}</span></div><div><MapPin size={16}/><span>{partner.area}</span></div><div><Truck size={16}/><span>{partner.vehicle} · {partner.service}</span></div><div><Star size={16}/><span>{partner.jobs} ca tuần này · {partner.rating || 'Chưa có'} sao</span></div></div></SectionCard><SectionCard title="Kiểm duyệt & điều hành"><div className="key-values"><div><span>Trạng thái hồ sơ</span><StatusBadge>{approved ? 'Đã duyệt' : partner.approval}</StatusBadge></div><div><span>Khu vực phục vụ</span><b>{partner.area}</b></div><div><span>Đội xe</span><b>{partner.vehicle}</b></div></div><div className="button-pair"><button className="button button-blue" onClick={() => setApproved(true)}><ShieldCheck size={15}/> Duyệt hồ sơ</button><a className="button button-white" href={'tel:' + partner.phone.replaceAll(' ', '')}><Phone size={15}/> Gọi đối tác</a></div></SectionCard></div></>
}
