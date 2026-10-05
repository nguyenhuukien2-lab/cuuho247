import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { ArrowRight, Eye, EyeOff, LockKeyhole, Mail, ShieldCheck } from 'lucide-react'
import { isAdmin, supabase } from '../lib/supabase'

export function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [show, setShow] = useState(false)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const navigate = useNavigate()

  useEffect(() => {
    let active = true
    async function checkSession() {
      try {
        const { data, error: sessionError } = await supabase.auth.getSession()
        if (sessionError) throw sessionError
        if (data.session) {
          const admin = await isAdmin()
          if (!active) return
          if (admin) {
            navigate('/', { replace: true })
            return
          }
          await supabase.auth.signOut()
          if (active) setError('Tài khoản không có quyền Admin')
        }
      } catch {
        if (active) setError('Không thể kiểm tra phiên đăng nhập. Vui lòng thử lại.')
      } finally {
        if (active) setLoading(false)
      }
    }
    void checkSession()
    return () => { active = false }
  }, [navigate])

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError('')
    setLoading(true)
    try {
      const { error: loginError } = await supabase.auth.signInWithPassword({ email, password })
      if (loginError) {
        setError('Email hoặc mật khẩu không đúng. Vui lòng thử lại.')
        return
      }
      let admin: boolean
      try {
        admin = await isAdmin()
      } catch {
        await supabase.auth.signOut()
        setError('Không thể xác minh quyền Admin. Vui lòng thử lại.')
        return
      }
      if (!admin) {
        await supabase.auth.signOut()
        setError('Tài khoản không có quyền Admin')
        return
      }
      navigate('/', { replace: true })
    } catch {
      setError('Không thể đăng nhập. Vui lòng thử lại.')
    } finally {
      setLoading(false)
    }
  }

  return <div className="login-page"><div className="login-glow one"/><div className="login-glow two"/><div className="login-card"><div className="login-logo"><ShieldCheck size={27}/></div><div className="eyebrow">TRUNG TÂM ĐIỀU HÀNH KHẨN CẤP</div><h1>Cứu Hộ 24/7 <span>Admin</span></h1><p>Đăng nhập để tiếp tục quản lý và điều phối mạng lưới cứu hộ.</p><form onSubmit={handleSubmit}><label>Email quản trị<div className="login-input"><Mail size={18}/><input required type="email" autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="admin@cuuho247.vn"/></div></label><label>Mật khẩu<div className="login-input"><LockKeyhole size={18}/><input required type={show ? 'text' : 'password'} autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Nhập mật khẩu"/><button type="button" aria-label="Hiện mật khẩu" onClick={() => setShow(!show)}>{show ? <EyeOff size={18}/> : <Eye size={18}/>}</button></div></label>{error && <div className="login-error" role="alert">{error}</div>}<button className="button button-blue full-width" type="submit" disabled={loading}>{loading ? 'Đang xử lý...' : 'Đăng nhập Admin'} <ArrowRight size={17}/></button></form><div className="login-foot"><span className="pulse-dot"/> Hệ thống hoạt động 24/7 <span>·</span> Hotline 1900 6868</div></div></div>
}