import { useLayoutEffect, useRef } from 'react'

interface SettingsSaveBarProps {
  count: number; reason: string; busy: boolean; disabled: boolean; feedback?: string
  onReason: (value: string) => void; onReset: () => void; onSave: () => void
}
export function SettingsSaveBar({ count, reason, busy, disabled, feedback, onReason, onReset, onSave }: SettingsSaveBarProps) {
  const bar = useRef<HTMLDivElement>(null)
  const spacer = useRef<HTMLDivElement>(null)
  useLayoutEffect(() => {
    const update = () => { if (spacer.current && bar.current) spacer.current.style.height = `${bar.current.getBoundingClientRect().height + 24}px` }
    const observer = new ResizeObserver(update)
    if (bar.current) observer.observe(bar.current)
    update()
    return () => observer.disconnect()
  }, [])
  return <><div ref={spacer} aria-hidden="true"/><div ref={bar} className="settings-save-bar" role="region" aria-label="Thay đổi chưa lưu">
    <div className="settings-save-inner">
      <div className="settings-save-count"><strong aria-live="polite">{count} thay đổi chưa lưu</strong><small>Áp dụng cho tất cả các tab</small></div>
      <div className="settings-save-reason"><label className="sr-only" htmlFor="config-reason">Lý do thay đổi</label>
        <input id="config-reason" placeholder="Nhập lý do thay đổi…" value={reason} maxLength={500} disabled={busy} onChange={(e) => onReason(e.target.value)} aria-describedby="config-save-help"/>
        <small id="config-save-help">{feedback || 'Lý do cần ít nhất 5 ký tự để ghi lịch sử.'}</small>
      </div>
      <div className="settings-save-actions"><button className="button button-white" disabled={busy} onClick={onReset}>Đặt lại</button>
        <button className="button button-blue" disabled={disabled} onClick={onSave}>{busy ? 'Đang lưu...' : 'Lưu thay đổi'}</button></div>
    </div>
  </div></>
}
