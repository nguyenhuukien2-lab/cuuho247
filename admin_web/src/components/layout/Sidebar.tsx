import { LayoutDashboard, ClipboardList, Users, Truck, Wrench, Wallet, Star, Map, Bell, Settings, Radio, PhoneCall, Shield } from 'lucide-react'
import { NavLink } from 'react-router-dom'
import { APP_NAME, HOTLINE, REGION } from '../../lib/constants'
const items = [
  { to: '/', label: 'Tổng quan', icon: LayoutDashboard, end: true },
  { to: '/requests', label: 'Yêu cầu cứu hộ', icon: ClipboardList },
  { to: '/customers', label: 'Khách hàng', icon: Users },
  { to: '/rescuers', label: 'Đối tác cứu hộ', icon: Truck },
  { to: '/services', label: 'Quản lý Dịch vụ', icon: Wrench },
  { to: '/quotes', label: 'Báo giá & Doanh thu', icon: Wallet },
  { to: '/reviews', label: 'Đánh giá dịch vụ', icon: Star },
  { to: '/map', label: 'Bản đồ hoạt động', icon: Map },
  { to: '/notifications', label: 'Thông báo', icon: Bell },
  { to: '/audit-logs', label: 'Nhật ký quản trị', icon: ClipboardList },
  { to: '/settings', label: 'Cài đặt hệ thống', icon: Settings },
]
export function Sidebar({ onNavigate }: { onNavigate?: () => void }) {
  return <aside className="sidebar">
    <div className="brand"><span className="brand-mark"><Shield size={20}/></span><span><strong>{APP_NAME}</strong><small>Điều hành khẩn cấp</small></span></div>
    <div className="region"><span className="pulse-dot" /> Khu vực: {REGION}</div>
    <nav className="side-nav" aria-label="Điều hướng chính">{items.map(({ to, label, icon: Icon, end }) => <NavLink key={to} to={to} end={end} onClick={onNavigate} className={({ isActive }) => 'nav-item' + (isActive ? ' active' : '')}><Icon size={17}/><span>{label}</span></NavLink>)}</nav>
    <div className="sidebar-footer"><div><Radio size={13}/> Trung tâm điều hành</div><div><PhoneCall size={13}/> Hotline SOS: <b>{HOTLINE}</b></div></div>
  </aside>
}
