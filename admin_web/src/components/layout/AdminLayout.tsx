import { useEffect, useRef, useState } from 'react'
import { Outlet } from 'react-router-dom'
import { X } from 'lucide-react'
import { Sidebar } from './Sidebar'
import { Topbar } from './Topbar'

export function AdminLayout() {
  const [mobileOpen, setMobileOpen] = useState(false)
  const drawerRef = useRef<HTMLDivElement>(null)
  useEffect(() => {
    if (!mobileOpen) return
    const previousFocus = document.activeElement as HTMLElement | null
    const overflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    drawerRef.current?.querySelector<HTMLButtonElement>('button')?.focus()
    const handleKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') { event.preventDefault(); setMobileOpen(false) }
      if (event.key !== 'Tab') return
      const elements = drawerRef.current?.querySelectorAll<HTMLElement>('button,a[href]')
      if (!elements?.length) return
      const first = elements[0], last = elements[elements.length - 1]
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus() }
      if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus() }
    }
    const desktop = window.matchMedia('(min-width: 761px)')
    const closeOnDesktop = () => { if (desktop.matches) setMobileOpen(false) }
    desktop.addEventListener('change', closeOnDesktop)
    document.addEventListener('keydown', handleKey)
    return () => {
      document.body.style.overflow = overflow
      desktop.removeEventListener('change', closeOnDesktop)
      document.removeEventListener('keydown', handleKey)
      previousFocus?.focus()
    }
  }, [mobileOpen])
  return <div className="admin-shell">
    <a className="skip-link" href="#main-content">Đến nội dung chính</a>
    <div ref={drawerRef} id="admin-navigation" className={'sidebar-wrap' + (mobileOpen ? ' open' : '')} role={mobileOpen ? 'dialog' : undefined} aria-modal={mobileOpen || undefined} aria-label={mobileOpen ? 'Điều hướng quản trị' : undefined}>
      <Sidebar onNavigate={() => setMobileOpen(false)} closeButton={<button className="mobile-close icon-button" aria-label="Đóng menu" onClick={() => setMobileOpen(false)}><X size={18}/></button>}/>
    </div>
    {mobileOpen && <button className="mobile-backdrop" aria-label="Đóng vùng điều hướng" tabIndex={-1} onClick={() => setMobileOpen(false)}/>}
    <div className="main-shell" inert={mobileOpen}><Topbar onMenu={() => setMobileOpen(true)} menuOpen={mobileOpen}/><main className="content" id="main-content" tabIndex={-1}><Outlet/></main></div>
  </div>
}
