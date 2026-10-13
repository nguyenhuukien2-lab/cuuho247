import type { ReactNode } from 'react'
import { LayoutDashboard, ClipboardList, Users, Truck, Wrench, Wallet, Star, Map, Bell, Settings, Radio, PhoneCall, MapPin } from 'lucide-react'
import { NavLink, useLocation } from 'react-router-dom'
import { PaymentNavigation } from './PaymentNavigation'
import { APP_NAME, HOTLINE, REGION } from '../../lib/constants'
const items = [
  { to: '/', label: 'Tổng quan', icon: LayoutDashboard, end: true },
  { to: '/requests', label: 'Yêu cầu cứu hộ', icon: ClipboardList },
  { to: '/customers', label: 'Khách hàng', icon: Users },
  { to: '/rescuers', label: 'Đối tác cứu hộ', icon: Truck },
  { to: '/services', label: 'Quản lý Dịch vụ', icon: Wrench },
  { to: '/quotes', label: 'Báo giá & Doanh thu', icon: Wallet },
  { to: '/payments', label: 'Thanh toán', icon: Wallet },
  { to: '/reviews', label: 'Đánh giá dịch vụ', icon: Star },
  { to: '/map', label: 'Bản đồ hoạt động', icon: Map },
  { to: '/notifications', label: 'Thông báo', icon: Bell },
  { to: '/audit-logs', label: 'Nhật ký quản trị', icon: ClipboardList },
  { to: '/settings', label: 'Cài đặt hệ thống', icon: Settings },
]
export function Sidebar({ onNavigate, closeButton }: { onNavigate?: () => void; closeButton?: ReactNode }) {
  const { pathname } = useLocation()
  return <aside className="sidebar">
    {closeButton}
    <NavLink className="brand" to="/" onClick={onNavigate} aria-label="Cứu Hộ 24/7 · Trang tổng quan"><img className="brand-logo" src="/cuuho-logo.svg" alt="" width="40" height="40"/><span><strong>{APP_NAME}</strong><small>Điều hành khẩn cấp</small></span></NavLink>
    <div className="region"><MapPin size={14}/> Khu vực: {REGION}</div>
    <div className="nav-caption">KHÔNG GIAN ĐIỀU HÀNH</div>
    <nav className="side-nav" aria-label="Điều hướng chính">{items.map(({ to, label, icon: Icon, end }) => to === '/payments'
      ? <PaymentNavigation key={'payments:' + pathname} pathname={pathname} onNavigate={onNavigate}/>
      : <NavLink key={to} to={to} end={end} onClick={onNavigate} className={({ isActive }) => 'nav-item' + (isActive ? ' active' : '')}><Icon size={18} strokeWidth={1.8}/><span>{label}</span></NavLink>)}</nav>
    <div className="sidebar-footer"><div><Radio size={14}/> Trung tâm điều hành 24/7</div><div><PhoneCall size={14}/> Hotline SOS <b><a href={'tel:' + HOTLINE.replace(/\s/g, '')}>{HOTLINE}</a></b></div></div>
  </aside>
}
