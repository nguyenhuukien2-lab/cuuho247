import { useState } from 'react'
import { Outlet } from 'react-router-dom'
import { Sidebar } from './Sidebar'
import { Topbar } from './Topbar'
export function AdminLayout() {
  const [mobileOpen, setMobileOpen] = useState(false)
  return <div className="admin-shell"><div className={'sidebar-wrap' + (mobileOpen ? ' open' : '')}><Sidebar onNavigate={() => setMobileOpen(false)}/></div>{mobileOpen && <button className="mobile-backdrop" aria-label="Đóng menu" onClick={() => setMobileOpen(false)}/>}<div className="main-shell"><Topbar onMenu={() => setMobileOpen(true)}/><main className="content"><Outlet/></main></div></div>
}
