import { useState } from 'react'
import { Bell, ChevronDown, LogOut, Menu, Search, ShieldCheck } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { notifications } from '../../mocks/mockData'
export function Topbar({ onMenu }: { onMenu: () => void }) {
  const [query, setQuery] = useState('')
  const [open, setOpen] = useState(false)
  const navigate = useNavigate()
  return <header className="topbar"><button className="mobile-menu icon-button" onClick={onMenu} aria-label="Mở menu"><Menu size={20}/></button>
    <div className="breadcrumb"><span className="topbar-shield"><ShieldCheck size={18}/></span><span>Điều Hành</span><span className="slash">/</span><b>Trung Tâm Cứu Hộ</b></div>
    <form className="top-search" onSubmit={(event) => { event.preventDefault(); navigate('/requests?search=' + encodeURIComponent(query)) }}><Search size={16}/><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Tra cứu ca cứu hộ, xe kéo, tài xế..." /></form>
    <span className="shift-badge"><span className="pulse-dot"/> Trực ban: 24/7 Sẵn sàng</span>
    <div className="top-notification"><button className="icon-button notification-button" onClick={() => setOpen(!open)} aria-label="Thông báo"><Bell size={18}/><i/></button>{open && <div className="notification-popover"><strong>Thông báo mới</strong>{notifications.map((item) => <Link key={item.title} to="/notifications" onClick={() => setOpen(false)}><b>{item.title}</b><small>{item.description}</small></Link>)}</div>}</div>
    <div className="admin-profile"><span className="admin-avatar">A</span><span><strong>Nguyễn Văn Quản Trị</strong><small>Super Admin</small></span><ChevronDown size={14}/></div>
    <Link to="/login" className="icon-button logout-button" aria-label="Đăng xuất"><LogOut size={18}/></Link>
  </header>
}
