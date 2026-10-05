import { useEffect, useState } from 'react'
import { Bell, LogOut, Menu, Search, ShieldCheck } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { getAdminProfile } from '../../lib/adminApi'
import { codeValue } from '../../lib/adminFormat'
export function Topbar({ onMenu }: { onMenu: () => void }) {
  const [query, setQuery] = useState('')
  const [open, setOpen] = useState(false)
  const [email, setEmail] = useState('')
  const [adminCode, setAdminCode] = useState<string | null>(null)
  const [loggingOut, setLoggingOut] = useState(false)
  const [error, setError] = useState('')
  const navigate = useNavigate()
  useEffect(() => {
    let active = true
    void supabase.auth.getSession().then(async ({ data }) => {
      if (!active) return
      setEmail(data.session?.user.email ?? '')
      if (data.session) {
        const result = await getAdminProfile(data.session.user.id)
        if (active) setAdminCode(result.data?.admin_code ?? null)
      }
    }).catch(() => {})
    return () => { active = false }
  }, [])
  return <header className="topbar"><button className="mobile-menu icon-button" onClick={onMenu} aria-label="Mở menu"><Menu size={20}/></button>
    <div className="breadcrumb"><span className="topbar-shield"><ShieldCheck size={18}/></span><span>Điều Hành</span><span className="slash">/</span><b>Trung Tâm Cứu Hộ</b></div>
    <form className="top-search" onSubmit={(event) => { event.preventDefault(); navigate('/requests?search=' + encodeURIComponent(query)) }}><Search size={16}/><input aria-label="Tra cứu yêu cầu" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Tra cứu ca cứu hộ, xe, khách hàng..." /></form>
    <div className="top-notification"><button className="icon-button notification-button" onClick={() => setOpen(!open)} aria-label="Thông báo" aria-expanded={open}><Bell size={18}/></button>{open && <div className="notification-popover"><strong>Thông báo</strong><p>Chưa kết nối dữ liệu thông báo.</p><Link to="/notifications" onClick={() => setOpen(false)}>Mở trung tâm thông báo</Link></div>}</div>
    <div className="admin-profile"><span className="admin-avatar">A</span><span><strong>{email || 'Quản trị viên'}</strong><small>{codeValue(adminCode)}</small></span></div>
    <button className="icon-button logout-button" disabled={loggingOut} aria-label="Đăng xuất" onClick={async () => {
      setLoggingOut(true); setError('')
      try {
        const { error: signOutError } = await supabase.auth.signOut()
        if (signOutError) { setError('Không thể đăng xuất. Vui lòng thử lại.'); return }
        navigate('/login', { replace: true })
      } catch { setError('Không thể đăng xuất. Vui lòng thử lại.') }
      finally { setLoggingOut(false) }
    }}><LogOut size={18}/></button>{error && <span role="alert">{error}</span>}
  </header>
}
