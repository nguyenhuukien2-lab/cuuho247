import { useEffect, useId, useRef, useState } from 'react'
import type { Rescuer } from '../../lib/adminTypes'
import type { AdminAction } from '../../hooks/useAdminAction'
import { apiError, approveRescuer, blockRescuer, rejectRescuer } from '../../lib/adminApi'

export function ActionDialog({ action, onClose, onSuccess }: { action: AdminAction; onClose: () => void; onSuccess: (message: string) => Promise<void> }) {
  const dialog = useRef<HTMLDialogElement>(null)
  const busy = useRef(false)
  const [reason, setReason] = useState('')
  const [pending, setPending] = useState(false)
  const [error, setError] = useState('')
  const titleId = useId()
  useEffect(() => { const element = dialog.current; element?.showModal(); return () => element?.close() }, [])
  return <dialog ref={dialog} className="admin-dialog" aria-labelledby={titleId} onCancel={(event) => { event.preventDefault(); if (!busy.current) onClose() }}>
    <form onSubmit={async (event) => {
      event.preventDefault()
      if (busy.current || (action.reason && !reason.trim())) return
      busy.current = true; setPending(true); setError('')
      try {
        const result = await action.run(reason.trim())
        if (result.error || !result.data) { setError(result.error || 'Không thể thực hiện thao tác.'); return }
        await onSuccess(result.data.changed === false ? 'Trạng thái này đã được cập nhật trước đó.' : result.data.message)
      } catch (cause) { setError(apiError(cause)) }
      finally { busy.current = false; setPending(false) }
    }}>
      <h2 id={titleId}>{action.title}</h2><p>{action.description}</p>
      {action.reason && <label>Lý do<textarea autoFocus required maxLength={2000} value={reason} disabled={pending} onChange={(event) => setReason(event.target.value)} placeholder="Nhập lý do (tối đa 2000 ký tự)"/></label>}
      {error && <div className="data-error" role="alert">{error}</div>}
      <div className="button-pair"><button type="button" className="button button-white" disabled={pending} onClick={onClose}>Đóng</button><button className="button button-blue" type="submit" disabled={pending || (action.reason && !reason.trim())}>{pending ? 'Đang xử lý...' : 'Xác nhận'}</button></div>
    </form>
  </dialog>
}
export function RescuerActions({ rescuer, open }: { rescuer: Rescuer; open: (action: AdminAction) => void }) {
  const name = rescuer.full_name || 'đối tác này'
  return <div className="row-actions">
    <button className="small-button" disabled={rescuer.approval_status !== 'submitted'} onClick={() => open({ title: 'Duyệt đối tác', description: 'Duyệt hồ sơ của ' + name + '?', run: () => approveRescuer(rescuer.rescuer_id) })}>Duyệt</button>
    <button className="small-button" disabled={rescuer.approval_status !== 'submitted'} onClick={() => open({ title: 'Từ chối đối tác', description: name, reason: true, run: (reason) => rejectRescuer(rescuer.rescuer_id, reason) })}>Từ chối</button>
    <button className="small-button danger" disabled={!rescuer.approval_status || rescuer.approval_status === 'suspended'} onClick={() => open({ title: 'Khóa đối tác', description: name, reason: true, run: (reason) => blockRescuer(rescuer.rescuer_id, reason) })}>Khóa</button>
  </div>
}
