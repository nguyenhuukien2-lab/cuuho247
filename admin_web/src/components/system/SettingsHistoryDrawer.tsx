import { useLayoutEffect, useRef } from 'react'
import type { ConfigAudit, ConfigDefinition } from '../../lib/systemConfigApi'
import { formatSettingValue, isVisibleSetting } from './settingsPresentation'

const accountFields: Record<string, string> = { status: 'Trạng thái', role: 'Vai trò', suspended_until: 'Đình chỉ đến', tokens_valid_after: 'JWT có hiệu lực từ', version: 'Phiên bản', updated_at: 'Cập nhật', user_id: 'Tài khoản' }
function auditKeys(entry: ConfigAudit) {
  return [...new Set([...Object.keys(entry.before_value ?? {}), ...Object.keys(entry.after_value ?? {})])].filter((key) =>
    (isVisibleSetting(key) || (['account_control', 'admin_access'].includes(entry.action) && Object.hasOwn(accountFields, key))) &&
    JSON.stringify(entry.before_value?.[key]) !== JSON.stringify(entry.after_value?.[key]))
}
export function SettingsHistoryDrawer({ history, definitions, error, loading, more, onReload, onMore, onClose }: {
  history: ConfigAudit[]; definitions: ConfigDefinition[]; error: string; loading: boolean; more: boolean
  onReload: () => void; onMore: () => void; onClose: () => void
}) {
  const ref = useRef<HTMLDialogElement>(null)
  useLayoutEffect(() => {
    const dialog = ref.current
    const previousFocus = document.activeElement as HTMLElement | null
    const overflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    dialog?.showModal()
    return () => { dialog?.close(); document.body.style.overflow = overflow; previousFocus?.focus() }
  }, [])
  return <dialog ref={ref} className="settings-history-drawer" aria-labelledby="settings-history-title" onCancel={(e) => { e.preventDefault(); onClose() }}>
    <header><div><h2 id="settings-history-title">Lịch sử cấu hình & bảo mật</h2><p>Các thay đổi đã được ghi nhận trên hệ thống.</p></div><button className="button button-white" autoFocus onClick={onClose} aria-label="Đóng lịch sử">Đóng</button></header>
    <button className="button button-white" disabled={loading} onClick={onReload}>Tải lại lịch sử</button>
    {loading && <p role="status">Đang tải lịch sử...</p>}{error && <p className="settings-error" role="alert">{error}</p>}
    {!loading && !error && history.length === 0 && <p className="settings-tab-note">Chưa có thay đổi được ghi nhận.</p>}
    <div className="system-audit-list">{history.map((entry) => <article key={entry.id}>
      <div className="settings-audit-heading"><strong>Phiên bản {entry.version}</strong><time dateTime={entry.created_at}>{new Date(entry.created_at).toLocaleString('vi-VN')}</time></div>
      <p>Admin: {entry.actor_id}</p><p>Thao tác: {entry.action} · Đối tượng: {entry.target}</p><p className="settings-audit-reason">Lý do: {entry.reason}</p>
      {auditKeys(entry).map((key) => <div className="settings-audit-change" key={key}><strong>{definitions.find((d) => d.key === key)?.label ?? accountFields[key] ?? key}</strong>
        <dl><div><dt>Giá trị cũ</dt><dd>{formatSettingValue(entry.before_value?.[key])}</dd></div><div><dt>Giá trị mới</dt><dd>{formatSettingValue(entry.after_value?.[key])}</dd></div></dl>
      </div>)}
    </article>)}</div>
    {more && <button className="button button-white" disabled={loading} onClick={onMore}>Xem thêm lịch sử</button>}
  </dialog>
}
