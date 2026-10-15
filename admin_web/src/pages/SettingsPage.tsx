import { useEffect, useEffectEvent, useRef, useState } from 'react'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { getSystemConfig, getSystemAudit, updateSystemConfig, validateConfig, configError } from '../lib/systemConfigApi'
import type { ConfigAudit, ConfigDefinition, ConfigValue, SystemConfig } from '../lib/systemConfigApi'
import { supabase } from '../lib/supabase'
import { AccountSecurity } from '../components/system/AccountSecurity'
import { Confirmation } from '../components/system/Confirmation'
import { SettingRow } from '../components/system/SettingRow'
import { SettingsOverview } from '../components/system/SettingsOverview'
import { SettingsSaveBar } from '../components/system/SettingsSaveBar'
import { SettingsHistoryDrawer } from '../components/system/SettingsHistoryDrawer'
import { formatSettingValue, isSettingDirty, isVisibleSetting, settingDescriptions, settingGroups, settingsTabs } from '../components/system/settingsPresentation'
import type { SettingsTab } from '../components/system/settingsPresentation'
import '../styles/system-config.css'
export function SettingsPage() {
  const [activeTab, setActiveTab] = useState<SettingsTab>('overview')
  const [historyOpen, setHistoryOpen] = useState(false)
  const [historyLoading, setHistoryLoading] = useState(false)
  const [config, setConfig] = useState<SystemConfig | null>(null)
  const [draft, setDraft] = useState<Record<string, ConfigValue>>({})
  const [history, setHistory] = useState<ConfigAudit[]>([])
  const [historyError, setHistoryError] = useState('')
  const [historyMore, setHistoryMore] = useState(false)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [reason, setReason] = useState('')
  const [confirmation, setConfirmation] = useState(false)
  const [conflict, setConflict] = useState(false)
  const generation = useRef(0)
  const lock = useRef(false)
  async function load() {
    const current = ++generation.current
    setLoading(true); setError(''); setNotice(''); setConfirmation(false)
    try {
      const data = await getSystemConfig()
      if (generation.current !== current) return
      setConfig(data); setDraft({}); setConflict(false); setReason('')
    } catch (e) { if (generation.current === current) { setError(configError(e)); setConfig(null) } }
    finally { if (generation.current === current) setLoading(false) }
  }
  async function loadHistory(append = false) {
    const current = generation.current
    setHistoryError(''); setHistoryLoading(true)
    try {
      const data = await getSystemAudit(append ? history.at(-1)?.id ?? null : null)
      if (current !== generation.current) return
      setHistory((p) => append ? [...p, ...data.rows] : data.rows); setHistoryMore(data.rows.length === 30)
    } catch (e) { if (current === generation.current) setHistoryError(configError(e)) }
    finally { if (current === generation.current) setHistoryLoading(false) }
  }
  const initialLoad = useEffectEvent(() => { void load().then(() => loadHistory()) })
  useEffect(() => {
    const timer = setTimeout(() => initialLoad(), 0)
    let owner: string | undefined
    const lifecycle = generation
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'SIGNED_OUT' || event === 'USER_UPDATED' || (owner && session?.user.id !== owner)) {
        generation.current++; setConfig(null); setDraft({}); setHistory([]); setConfirmation(false); setHistoryOpen(false)
      }
      owner = session?.user.id
    })
    return () => { clearTimeout(timer); lifecycle.current++; subscription.unsubscribe() }
  }, [])
  const changed = config ? config.definitions.filter((d) => isVisibleSetting(d.key) && d.key in draft && isSettingDirty(d, draft[d.key], config.values[d.key])) : []
  const invalid = changed.some((d) => validateConfig(d, draft[d.key]))
  async function save(confirmed: boolean) {
    if (!config || lock.current || invalid || conflict || !changed.length || reason.trim().length < 5) return
    if (changed.some((d) => d.dangerous) && !confirmed) { setConfirmation(true); return }
    lock.current = true; setBusy(true); setError(''); setNotice('')
    const current = generation.current
    const patch = Object.fromEntries(changed.map((d) => [d.key, d.kind === 'integer' ? Number(draft[d.key]) : d.kind === 'permissions' && typeof draft[d.key] === 'string' ? JSON.parse(draft[d.key] as string) : draft[d.key]]))
    try {
      const data = await updateSystemConfig(patch, config.version, reason.trim(), confirmed)
      if (current !== generation.current) return
      setConfig(data); setDraft({}); setReason(''); setConfirmation(false); setNotice('Đã lưu cấu hình và ghi lịch sử.')
      await loadHistory()
    } catch (e) {
      if (current !== generation.current) return
      setError(configError(e)); setConfirmation(false); setConflict(true)
    } finally { lock.current = false; if (current === generation.current) setBusy(false) }
  }
  function renderSetting(d: ConfigDefinition) {
    if (!config) return null
    const raw = draft[d.key] ?? config.values[d.key]
    const validation = d.key in draft ? validateConfig(d, raw) : null
    const editable = config.editable_sections.includes(d.section)
    const common = { id: d.key, disabled: busy || conflict, 'aria-describedby': `${d.key}-description${validation ? ` ${d.key}-error` : ''}`, 'aria-invalid': !!validation }
    const onChange = (value: ConfigValue) => setDraft((previous) => ({ ...previous, [d.key]: value }))
    const control = !editable ? <span className="settings-readonly">Chỉ đọc</span>
      : d.kind === 'boolean' ? <label className="settings-switch"><input {...common} type="checkbox" checked={raw === true} onChange={(e) => onChange(e.target.checked)}/><span aria-hidden="true">{raw === true ? 'Bật' : 'Tắt'}</span></label>
        : d.kind === 'permissions' ? <textarea {...common} rows={5} value={typeof raw === 'string' ? raw : JSON.stringify(raw, null, 2)} onChange={(e) => onChange(e.target.value)}/>
          : <input {...common} type={d.kind === 'integer' ? 'number' : 'text'} min={d.minimum ?? undefined} max={d.maximum ?? undefined} step={d.kind === 'integer' ? 1 : undefined} maxLength={d.kind === 'text' ? d.maximum ?? undefined : undefined} value={String(raw ?? '')} onChange={(e) => onChange(e.target.value)}/>
    return <SettingRow key={d.key} id={d.key} label={d.label} description={settingDescriptions[d.key]} currentValue={formatSettingValue(config.values[d.key])} dangerous={d.dangerous} dirty={changed.some((item) => item.key === d.key)} control={control} helperText={validation}/>
  }
  return <div className="settings-page">
    <PageHeader title="Cấu hình hệ thống" description="Quản lý Customer, Rescuer, thanh toán và quyền truy cập." actions={<>
      <button className="button button-white" onClick={() => { void load().then(() => loadHistory()) }} disabled={busy || loading}>Tải lại</button>
      <button className="button button-white" onClick={() => setHistoryOpen(true)} disabled={loading || !config}>Xem lịch sử</button>
    </>}/>
    <div className="settings-tabs" role="tablist" aria-label="Nhóm cấu hình">{settingsTabs.map((tab, index) => <button key={tab.id} id={`settings-tab-${tab.id}`} role="tab" aria-selected={activeTab === tab.id} aria-controls={`settings-panel-${tab.id}`} tabIndex={activeTab === tab.id ? 0 : -1} onClick={() => setActiveTab(tab.id)} onKeyDown={(e) => {
      let next: number
      if (e.key === 'ArrowRight') next = (index + 1) % settingsTabs.length
      else if (e.key === 'ArrowLeft') next = (index + settingsTabs.length - 1) % settingsTabs.length
      else if (e.key === 'Home') next = 0
      else if (e.key === 'End') next = settingsTabs.length - 1
      else return
      e.preventDefault(); setActiveTab(settingsTabs[next].id); document.getElementById(`settings-tab-${settingsTabs[next].id}`)?.focus()
    }}>{tab.label}</button>)}</div>
    {config && !loading && <p className="settings-version">Phiên bản {config.version} · Cập nhật {new Date(config.updated_at).toLocaleTimeString('vi-VN', { hour12: false })} {new Date(config.updated_at).toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit', year: 'numeric' })}</p>}
    {error && <div className="settings-error" role="alert">{error}</div>}
    {notice && <div className="settings-notice" role="status">{notice}<button aria-label="Đóng thông báo" onClick={() => setNotice('')}>×</button></div>}
    {loading ? <p className="settings-empty" role="status">Đang tải cấu hình...</p> : config && <>
      {config.definitions.length === 0 && <p className="settings-empty">Chưa có cấu hình hệ thống.</p>}
      {settingsTabs.map((tab) => <div key={tab.id} id={`settings-panel-${tab.id}`} role="tabpanel" aria-labelledby={`settings-tab-${tab.id}`} hidden={activeTab !== tab.id} tabIndex={0}>
        {activeTab === tab.id && (tab.id === 'overview' ? <SettingsOverview config={config} onSelect={setActiveTab}/> : <>
          {!config.editable_sections.includes(tab.id) && <p className="settings-tab-note">Chỉ đọc theo phân quyền hiện tại.</p>}
          <div className="system-config-grid">{settingGroups[tab.id].map((group) => {
            const definitions = group.keys.flatMap((key) => config.definitions.find((d) => d.key === key) ?? [])
            return <SectionCard key={group.title} title={group.title} className="settings-group" subtitle={group.note}>
              {definitions.length ? definitions.map(renderSetting) : <p className="settings-tab-note">Chưa có cấu hình trong nhóm này.</p>}
            </SectionCard>
          })}</div>
        </>)}
        {tab.id === 'security' && config.editable_sections.includes('security') && <div className="settings-account"><AccountSecurity onSaved={() => { void loadHistory() }}/></div>}
      </div>)}
      {changed.length > 0 && <SettingsSaveBar count={changed.length} reason={reason} busy={busy} disabled={busy || conflict || invalid || reason.trim().length < 5}
        feedback={conflict ? 'Tải lại để đối chiếu trạng thái máy chủ trước khi tiếp tục.' : invalid ? 'Có giá trị chưa hợp lệ. Kiểm tra các mục đã chỉnh sửa.' : undefined}
        onReason={setReason} onReset={() => { setDraft({}); setReason(''); setConfirmation(false) }} onSave={() => void save(false)}/>}
    </>}
    {historyOpen && config && <SettingsHistoryDrawer history={history} definitions={config.definitions} error={historyError} loading={historyLoading} more={historyMore} onReload={() => void loadHistory()} onMore={() => void loadHistory(true)} onClose={() => setHistoryOpen(false)}/>}
    {confirmation && <Confirmation title="Xác nhận thay đổi cấu hình nguy hiểm" busy={busy} onClose={() => setConfirmation(false)}><h2 id="confirm-config-title">Xác nhận thay đổi cấu hình nguy hiểm</h2>
      <p>Các thay đổi sẽ có hiệu lực cho thao tác tiếp theo. Kiểm tra kỹ trước khi xác nhận.</p>
      <ul>{changed.map((d) => <li key={d.key}>{d.label}: {JSON.stringify(config?.values[d.key])} → {JSON.stringify(draft[d.key])}</li>)}</ul>
      <button className="button button-white" autoFocus disabled={busy} onClick={() => setConfirmation(false)}>Hủy</button><button className="button button-danger" disabled={busy} onClick={() => void save(true)}>{busy ? 'Đang lưu...' : 'Xác nhận lưu'}</button>
    </Confirmation>}
  </div>
}
