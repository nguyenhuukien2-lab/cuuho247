import { useEffect, useState } from 'react'
import { Navigate } from 'react-router-dom'
import { AdminLayout } from '../components/layout/AdminLayout'
import { isAdmin, supabase } from '../lib/supabase'

export function AdminRoute() {
  const [allowed, setAllowed] = useState<boolean | null>(null)
  useEffect(() => {
    let active = true
    let request = 0
    let userId: string | undefined
    let timer: ReturnType<typeof setTimeout> | undefined
    async function checkSession() {
      const current = ++request
      try {
        const { data, error } = await supabase.auth.getSession()
        if (error) throw error
        if (!active || current !== request) return
        if (!data.session) { setAllowed(false); return }
        userId = data.session.user.id
        const admin = await isAdmin()
        if (!active || current !== request) return
        if (!admin) await supabase.auth.signOut()
        if (active && current === request) setAllowed(admin)
      } catch { if (active && current === request) setAllowed(false) }
    }
    void checkSession()
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (!active) return
      request++
      clearTimeout(timer)
      if (!session) { userId = undefined; setAllowed(false); return }
      // Keep forms/subscriptions mounted during same-user token refresh or focus events.
      if (userId !== session.user.id) setAllowed(null)
      userId = session.user.id
      timer = setTimeout(() => { if (active) void checkSession() }, 0)
    })
    return () => { active = false; request++; clearTimeout(timer); subscription.unsubscribe() }
  }, [])
  if (allowed === null) return <div className="page-loading">Đang kiểm tra quyền truy cập...</div>
  return allowed ? <AdminLayout/> : <Navigate to="/login" replace/>
}
