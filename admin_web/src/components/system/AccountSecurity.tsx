import { useEffect, useRef, useState } from 'react'
import { SectionCard } from '../ui/SectionCard'
import { getAccountControl, updateAccountControl, updateAdminAccess, configError } from '../../lib/systemConfigApi'
import type { AccountControl } from '../../lib/systemConfigApi'
import { Confirmation } from './Confirmation'
export function AccountSecurity({ onSaved }: { onSaved: () => void }) {
  const [id, setId] = useState('')
  const [account, setAccount] = useState<AccountControl | null>(null)
  const [status, setStatus] = useState<AccountControl['status']>('active')
  const [until, setUntil] = useState('')
  const [revoke, setRevoke] = useState(false)
  const [reason, setReason] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [confirm, setConfirm] = useState(false)
  const serial = useRef(0)
  const lock = useRef(false)
  useEffect(() => () => { serial.current++ }, [])
  const validId = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)
  async function read() {
    const current = ++serial.current
    setBusy(true); setError(''); setAccount(null); setConfirm(false)
    try { const data = await getAccountControl(id); if (current === serial.current) { setAccount(data); setStatus(data.status); setUntil(''); setRevoke(false) } }
    catch (e) { if (current === serial.current) setError(configError(e)) }
    finally { if (current === serial.current) setBusy(false) }
  }
  async function save() {
    if (!account || lock.current) return
    lock.current = true
    const current = ++serial.current
    setBusy(true); setError('')
    try {
      const data = await updateAccountControl(account, status, status === 'suspended' && until ? new Date(until).toISOString() : null, revoke, reason.trim())
      if (current !== serial.current) return
      setAccount(data); setConfirm(false); setRevoke(false); setReason(''); onSaved()
    } catch (e) { if (current === serial.current) { setError(configError(e)); setAccount(null); setConfirm(false) } }
    finally { lock.current = false; if (current === serial.current) setBusy(false) }
  }
  return <SectionCard title="Khóa tài khoản & phiên truy cập" action={<span className="system-danger">Cần xác nhận</span>}><p>Tra cứu tài khoản để quản lý trạng thái, phiên truy cập và quyền Admin.</p>
    <div className="settings-account-lookup"><label htmlFor="security-user">UUID tài khoản</label><input id="security-user" value={id} disabled={busy} onChange={(e) => { setId(e.target.value.trim()); setAccount(null); serial.current++ }}/>
    <button className="button button-white" disabled={busy || !validId} onClick={() => void read()}>{busy ? 'Đang xử lý...' : 'Tra cứu tài khoản'}</button></div>{error && <p role="alert">{error}</p>}
    {account?.admin_access && <AdminAccess key={account.user_id + account.admin_access.updated_at} account={account} onSaved={(data) => { setAccount(data); onSaved() }}/>} 
    {account && <div className="settings-account-controls"><p>Hiện tại: {account.status} · v{account.version}</p><label htmlFor="account-status">Trạng thái tài khoản</label>
      <select id="account-status" value={status} disabled={busy} onChange={(e) => setStatus(e.target.value as AccountControl['status'])}><option value="active">Hoạt động</option><option value="locked">Khóa</option><option value="suspended">Đình chỉ</option></select>
      {status === 'suspended' && <><label htmlFor="suspend-until">Đình chỉ đến (để trống: vô thời hạn)</label><input id="suspend-until" type="datetime-local" value={until} disabled={busy} onChange={(e) => setUntil(e.target.value)}/></>}
      <label><input type="checkbox" checked={revoke} disabled={busy} onChange={(e) => setRevoke(e.target.checked)}/>Thu hồi JWT đã cấp</label>
      <label htmlFor="account-reason">Lý do kiểm soát tài khoản</label><textarea className="system-config-reason" id="account-reason" value={reason} maxLength={500} disabled={busy} onChange={(e) => setReason(e.target.value)}/>
      <button className="button button-white" disabled={busy || reason.trim().length < 5} onClick={() => {
        if (status === 'suspended' && until && new Date(until).getTime() <= Date.now()) { setError('Thời hạn đình chỉ phải ở tương lai.'); return }
        setConfirm(true)
      }}>Áp dụng kiểm soát tài khoản</button>
      {confirm && <Confirmation title="Xác nhận kiểm soát tài khoản" busy={busy} onClose={() => setConfirm(false)}><h2>Xác nhận kiểm soát tài khoản</h2><p>{account.user_id} → {status}{revoke ? ' · Thu hồi JWT' : ''}</p><button className="button button-white" autoFocus disabled={busy} onClick={() => setConfirm(false)}>Hủy</button><button className="button button-danger" disabled={busy} onClick={() => void save()}>Xác nhận áp dụng</button></Confirmation>}</div>}
  </SectionCard>
}

function AdminAccess({ account, onSaved }: { account: AccountControl; onSaved: (data: AccountControl) => void }) {
  const [role, setRole] = useState(account.admin_access!.role)
  const [status, setStatus] = useState(account.admin_access!.status)
  const [reason, setReason] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const [confirm, setConfirm] = useState(false)
  const lock = useRef(false)
  const alive = useRef(true)
  useEffect(() => { alive.current = true; return () => { alive.current = false } }, [])
  async function apply() {
    if (lock.current) return
    lock.current = true; setBusy(true); setError('')
    try { const data = await updateAdminAccess(account, role, status, reason.trim()); if (alive.current) { setConfirm(false); onSaved(data) } }
    catch (e) { if (alive.current) { setError(configError(e)); setConfirm(false) } }
    finally { lock.current = false; if (alive.current) setBusy(false) }
  }
  return <div className="system-config-field"><h3>Quyền Admin <span className="system-danger">Cần xác nhận</span></h3><p>Hiện tại: {account.admin_access!.role} · {account.admin_access!.status}</p>
    <label htmlFor="admin-access-role">Vai trò Admin</label><select id="admin-access-role" value={role} disabled={busy} onChange={(e) => setRole(e.target.value)}>
      {['super_admin','operator','support','partner_reviewer','finance'].map((r) => <option key={r}>{r}</option>)}</select>
    <label htmlFor="admin-access-status">Trạng thái Admin</label><select id="admin-access-status" value={status} disabled={busy} onChange={(e) => setStatus(e.target.value)}><option value="active">Hoạt động</option><option value="blocked">Khóa quyền Admin</option></select>
    <label htmlFor="admin-access-reason">Lý do đổi quyền Admin</label><textarea id="admin-access-reason" value={reason} maxLength={500} disabled={busy} onChange={(e) => setReason(e.target.value)}/>
    {error && <p role="alert">{error} Tải lại tài khoản để đối chiếu trước khi tiếp tục.</p>}
    <button className="button button-white" disabled={busy || !!error || reason.trim().length<5 || (role===account.admin_access!.role && status===account.admin_access!.status)} onClick={() => setConfirm(true)}>Lưu quyền Admin</button>
    {confirm && <Confirmation title="Xác nhận đổi quyền Admin" busy={busy} onClose={() => setConfirm(false)}><h2>Xác nhận đổi quyền Admin</h2><p>{account.user_id} → {role} · {status}</p><button className="button button-white" autoFocus disabled={busy} onClick={() => setConfirm(false)}>Hủy</button><button className="button button-danger" disabled={busy} onClick={() => void apply()}>Xác nhận đổi quyền</button></Confirmation>}
  </div>
}
