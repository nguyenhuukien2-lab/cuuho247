import { useEffect, useRef, useState } from 'react'
import { Bell, LogOut, Menu, Search } from 'lucide-react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { getAdminProfile } from '../../lib/adminApi'
import { codeValue } from '../../lib/adminFormat'

const sections: Record<string, string> = { requests: 'Yêu cầu cứu hộ', customers: 'Khách hàng', rescuers: 'Đối tác cứu hộ', services: 'Dịch vụ', quotes: 'Báo giá & Doanh thu', payments: 'Thanh toán', reviews: 'Đánh giá', map: 'Bản đồ hoạt động', notifications: 'Thông báo', 'audit-logs': 'Nhật ký quản trị', settings: 'Cài đặt' }

export function Topbar({ onMenu, menuOpen }: { onMenu: () => void; menuOpen: boolean }) {
  const [query, setQuery] = useState('')
  const [open, setOpen] = useState(false)
  const [name, setName] = useState('')
  const [adminCode, setAdminCode] = useState<string | null>(null)
  const [loggingOut, setLoggingOut] = useState(false)
  const [error, setError] = useState('')
  const searchRef = useRef<HTMLInputElement>(null)
  const notificationRef = useRef<HTMLDivElement>(null)
  const navigate = useNavigate()
  const location = useLocation()
  useEffect(() => {
    let active = true
    void supabase.auth.getSession().then(async ({ data }) => {
      if (!active) return
      setName(data.session?.user.email ?? '')
      if (data.session) {
        const result = await getAdminProfile(data.session.user.id)
        if (active) {
          setAdminCode(result.data?.admin_code ?? null)
          if (result.data?.full_name) setName(result.data.full_name)
        }
      }
    }).catch(() => {})
    return () => { active = false }
  }, [])
  useEffect(() => {
    const shortcut = (event: KeyboardEvent) => {
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') { event.preventDefault(); searchRef.current?.focus() }
      if (event.key === 'Escape' && open) {
        setOpen(false)
        notificationRef.current?.querySelector('button')?.focus()
      }
    }
    const closeOutside = (event: PointerEvent) => {
      if (!notificationRef.current?.contains(event.target as Node)) setOpen(false)
    }
    window.addEventListener('keydown', shortcut)
    document.addEventListener('pointerdown', closeOutside)
    return () => { window.removeEventListener('keydown', shortcut); document.removeEventListener('pointerdown', closeOutside) }
  }, [open])
  return <header className="topbar">
    <button className="mobile-menu icon-button" onClick={onMenu} aria-label="Mở menu" aria-controls="admin-navigation" aria-expanded={menuOpen}><Menu size={21}/></button>
    <div className="breadcrumb"><span>Điều hành</span><span className="slash">/</span><b>{sections[location.pathname.split('/')[1]] ?? 'Tổng quan'}</b></div>
    <form className="top-search" role="search" onSubmit={(event) => { event.preventDefault(); navigate('/requests?search=' + encodeURIComponent(query.trim())) }}>
      <Search size={17}/><input ref={searchRef} aria-label="Tra cứu yêu cầu" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Tìm mã ca, xe, khách hàng..."/><kbd>Ctrl K</kbd>
    </form>
    <div className="top-notification" ref={notificationRef}><button className="icon-button notification-button" onClick={() => setOpen(!open)} aria-label="Thông báo" aria-expanded={open} aria-controls="admin-notifications"><Bell size={20}/></button>{open && <div id="admin-notifications" className="notification-popover"><strong>Trung tâm thông báo</strong><p>Chưa có nguồn thông báo được kết nối.</p><Link to="/notifications" onClick={() => setOpen(false)}>Xem trang thông báo →</Link></div>}</div>
    <div className="admin-profile"><span className="admin-avatar">{name ? name.charAt(0).toUpperCase() : 'A'}</span><span><strong title={name}>{name || 'Quản trị viên'}</strong><small>{adminCode ? codeValue(adminCode) : 'Quản trị hệ thống'}</small></span></div>
    <button className="icon-button logout-button" disabled={loggingOut} aria-label="Đăng xuất" title="Đăng xuất" onClick={async () => {
      setLoggingOut(true); setError('')
      try {
        const { error: signOutError } = await supabase.auth.signOut()
        if (signOutError) { setError('Không thể đăng xuất. Vui lòng thử lại.'); return }
        navigate('/login', { replace: true })
      } catch { setError('Không thể đăng xuất. Vui lòng thử lại.') }
      finally { setLoggingOut(false) }
    }}><LogOut size={19}/></button>{error && <span className="topbar-error" role="alert">{error}</span>}
  </header>
}
