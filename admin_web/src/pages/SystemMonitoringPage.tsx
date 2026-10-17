import { useEffect, useMemo, useRef, useState } from 'react'
import { Activity, AlertTriangle, BellRing, CheckCircle2, Clock3, CreditCard, Radio, ShieldAlert, Siren, Truck, UsersRound, X } from 'lucide-react'
import { useAdminData } from '../hooks/useAdminData'
import { acknowledgeSystemAlert, getSystemMonitoring } from '../lib/monitoringApi'
import type { AlertSeverity, MonitoringAlert, MonitoringEvent, MonitoringSection, MonitoringStatus } from '../lib/monitoringTypes'
import { dateValue } from '../lib/adminFormat'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { DataState, ReloadButton } from '../components/ui/AdminData'
import { StatusBadge } from '../components/ui/StatusBadge'
import '../styles/system-monitoring.css'

const tabs: { id: MonitoringSection; label: string }[] = [
  { id: 'overview', label: 'Tổng quan' }, { id: 'payment', label: 'Thanh toán' }, { id: 'webhook', label: 'Webhook' },
  { id: 'rescue', label: 'Cứu hộ' }, { id: 'security', label: 'Bảo mật' }, { id: 'alerts', label: 'Nhật ký cảnh báo' },
]
const severityLabel: Record<AlertSeverity, string> = { info: 'INFO', warning: 'WARNING', critical: 'CRITICAL' }
const statusLabel: Record<MonitoringStatus, string> = { healthy: 'Ổn định', degraded: 'Cần chú ý', critical: 'Nghiêm trọng' }
const tone = (value: AlertSeverity | MonitoringStatus) => value === 'critical' ? 'red' : value === 'warning' || value === 'degraded' ? 'orange' : 'green'
const categoryLabel: Record<string, string> = { payment: 'Thanh toán', webhook: 'Webhook', rescue: 'Cứu hộ', security: 'Bảo mật', system: 'Hệ thống' }

function MetricCard({ label, value, icon: Icon, critical = false }: { label: string; value: number | string; icon: typeof Activity; critical?: boolean }) {
  return <article className={'monitor-metric' + (critical ? ' is-critical' : '')}><div><span>{label}</span><strong>{value}</strong></div><Icon size={20}/></article>
}

function EventTable({ rows, onSelect }: { rows: MonitoringEvent[]; onSelect: (row: MonitoringEvent) => void }) {
  if (!rows.length) return <div className="monitor-empty"><CheckCircle2 size={22}/><strong>Không có sự kiện bất thường trong khoảng thời gian này.</strong></div>
  return <div className="table-scroll"><table><thead><tr><th>Mức độ</th><th>Sự kiện</th><th>Trạng thái</th><th>Thời gian</th><th></th></tr></thead><tbody>{rows.map((row) => <tr key={row.id}>
    <td><StatusBadge tone={tone(row.severity)}>{severityLabel[row.severity]}</StatusBadge></td>
    <td><b>{row.code}</b><small>{categoryLabel[row.category] ?? row.category}</small></td><td>{row.status}</td><td>{dateValue(row.occurred_at)}</td>
    <td><button className="small-button" onClick={() => onSelect(row)}>Chi tiết</button></td>
  </tr>)}</tbody></table></div>
}

function AlertTable({ rows, onSelect }: { rows: MonitoringAlert[]; onSelect: (row: MonitoringAlert) => void }) {
  if (!rows.length) return <div className="monitor-empty"><CheckCircle2 size={22}/><strong>Không có cảnh báo phù hợp.</strong></div>
  return <div className="table-scroll"><table><thead><tr><th>Mức độ</th><th>Cảnh báo</th><th>Nhóm</th><th>Phát hiện</th><th>Trạng thái</th><th></th></tr></thead><tbody>{rows.map((row) => <tr key={row.key + row.fingerprint}>
    <td><StatusBadge tone={tone(row.severity)}>{severityLabel[row.severity]}</StatusBadge></td><td><b>{row.title}</b><small>{row.message}</small></td>
    <td>{categoryLabel[row.category] ?? row.category}</td><td>{dateValue(row.detected_at)}</td><td>{row.acknowledged ? 'Đã xác nhận' : 'Đang mở'}</td>
    <td><button className="small-button" onClick={() => onSelect(row)}>Chi tiết</button></td>
  </tr>)}</tbody></table></div>
}

function DetailDrawer({ value, canAcknowledge, busy, error, onClose, onAcknowledge }: {
  value: MonitoringAlert | MonitoringEvent | null; canAcknowledge: boolean; busy: boolean; error: string; onClose: () => void; onAcknowledge: (row: MonitoringAlert) => void
}) {
  const ref = useRef<HTMLDialogElement>(null)
  useEffect(() => {
    const dialog = ref.current
    if (value && dialog && !dialog.open) dialog.showModal()
    return () => { if (dialog?.open) dialog.close() }
  }, [value])
  if (!value) return null
  const isAlert = 'fingerprint' in value
  return <dialog ref={ref} className="monitor-drawer" onCancel={(event) => { event.preventDefault(); onClose() }}>
    <header><div><StatusBadge tone={tone(value.severity)}>{severityLabel[value.severity]}</StatusBadge><h2>{isAlert ? value.title : value.code}</h2><p>{categoryLabel[value.category] ?? value.category} · {dateValue(isAlert ? value.detected_at : value.occurred_at)}</p></div><button className="icon-button" aria-label="Đóng chi tiết" onClick={onClose}><X size={18}/></button></header>
    {isAlert && <p className="monitor-message">{value.message}</p>}
    <dl className="monitor-detail-list"><div><dt>Mã</dt><dd>{value.code}</dd></div><div><dt>Đối tượng</dt><dd>{value.entity_type ?? 'system'}</dd></div><div><dt>ID đối tượng</dt><dd>{value.entity_id ?? '—'}</dd></div>
      {Object.entries(value.detail).map(([key, item]) => <div key={key}><dt>{key.replaceAll('_', ' ')}</dt><dd>{item == null ? '—' : String(item)}</dd></div>)}</dl>
    {error && <div className="data-error" role="alert">{error}</div>}
    {isAlert && !value.acknowledged && canAcknowledge && <button className="button button-blue" disabled={busy} onClick={() => onAcknowledge(value)}>{busy ? 'Đang xác nhận...' : 'Xác nhận đã tiếp nhận'}</button>}
    {isAlert && value.acknowledged && <div className="monitor-ack"><CheckCircle2 size={16}/> Đã xác nhận lúc {dateValue(value.acknowledged_at)}</div>}
  </dialog>
}

export function SystemMonitoringPage() {
  const resource = useAdminData(getSystemMonitoring)
  const [tab, setTab] = useState<MonitoringSection>('overview')
  const [severityFilter, setSeverityFilter] = useState('')
  const [query, setQuery] = useState('')
  const [selected, setSelected] = useState<MonitoringAlert | MonitoringEvent | null>(null)
  const [ackBusy, setAckBusy] = useState(false)
  const [ackError, setAckError] = useState('')
  const data = resource.error ? null : resource.data
  const alerts = useMemo(() => (data?.alerts ?? []).filter((row) => (!severityFilter || row.severity === severityFilter) &&
    (!query.trim() || `${row.title} ${row.message} ${row.code}`.toLocaleLowerCase('vi').includes(query.trim().toLocaleLowerCase('vi')))), [data?.alerts, severityFilter, query])
  const switchTab = (next: MonitoringSection) => { setTab(next); setSelected(null) }
  async function acknowledge(row: MonitoringAlert) {
    setAckBusy(true); setAckError('')
    const result = await acknowledgeSystemAlert(row)
    setAckBusy(false)
    if (result.error) { setAckError(result.error); return }
    setSelected(null)
    await resource.reload()
  }
  const summary = data?.summary
  const alertSection = <SectionCard title="Cảnh báo vận hành" subtitle="Dữ liệu đã lọc, không chứa webhook body, header hoặc secret">
    <div className="monitor-filters"><label><input aria-label="Tìm cảnh báo" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Tìm mã hoặc nội dung..."/></label><label><select aria-label="Lọc mức độ" value={severityFilter} onChange={(event) => setSeverityFilter(event.target.value)}><option value="">Tất cả mức độ</option><option value="critical">CRITICAL</option><option value="warning">WARNING</option><option value="info">INFO</option></select></label></div>
    <AlertTable rows={alerts} onSelect={setSelected}/>
  </SectionCard>
  return <><PageHeader eyebrow="VẬN HÀNH / GIÁM SÁT" title="Giám sát hệ thống" description="Theo dõi SePay, thanh toán, cứu hộ, tài khoản và cảnh báo bảo mật từ dữ liệu server-side." actions={<><span className="monitor-updated"><Clock3 size={14}/> {data?.generated_at ? dateValue(data.generated_at) : 'Chưa tải'}</span><ReloadButton resource={resource}/></>}/>
    <div className="monitor-tabs" role="tablist" aria-label="Nhóm giám sát">{tabs.map((item) => <button key={item.id} role="tab" aria-selected={tab === item.id} onClick={() => switchTab(item.id)}>{item.label}{item.id === 'alerts' && summary?.open_alerts ? <span>{summary.open_alerts}</span> : null}</button>)}</div>
    <DataState resource={resource}>{data && summary && <div role="tabpanel" aria-label={tabs.find((item) => item.id === tab)?.label}>
      {tab === 'overview' && <>
        <section className={'monitor-health ' + summary.overall_status}><div><span className="monitor-pulse"><Activity size={22}/></span><div><small>TRẠNG THÁI TOÀN HỆ THỐNG</small><h2>{statusLabel[summary.overall_status]}</h2><p>{summary.critical_alerts ? `${summary.critical_alerts} cảnh báo nghiêm trọng cần xử lý.` : summary.open_alerts ? `${summary.open_alerts} cảnh báo đang mở.` : 'Không phát hiện sự cố đang mở.'}</p></div></div><StatusBadge tone={tone(summary.webhook_status)}>SePay: {statusLabel[summary.webhook_status]}</StatusBadge></section>
        <div className="monitor-grid"><MetricCard label="Webhook 4xx" value={summary.webhook_4xx} icon={Radio} critical={summary.webhook_4xx > 0}/><MetricCard label="Webhook 5xx" value={summary.webhook_5xx} icon={Siren} critical={summary.webhook_5xx > 0}/><MetricCard label="Thanh toán lỗi" value={summary.payment_failures} icon={CreditCard}/><MetricCard label="Đang chờ thanh toán" value={summary.pending_payments} icon={Clock3}/><MetricCard label="Giao dịch bị từ chối" value={summary.rejected_transactions} icon={AlertTriangle}/><MetricCard label="Yêu cầu cứu hộ hoạt động" value={summary.active_rescue_requests} icon={Truck}/><MetricCard label="Đối tác online" value={summary.online_rescuers} icon={UsersRound}/><MetricCard label="Tài khoản hạn chế" value={summary.restricted_accounts} icon={ShieldAlert}/></div>
        {alertSection}
        <SectionCard title="Kênh cảnh báo" subtitle="Token và credential chỉ được cấu hình ở server"><div className="monitor-channels">{data.delivery_channels.map((channel) => <article key={channel.channel}><BellRing size={18}/><div><b>{channel.channel === 'admin_web' ? 'Admin Web' : channel.channel === 'telegram' ? 'Telegram' : 'Email'}</b><p>{channel.description}</p></div><StatusBadge tone={channel.status === 'active' ? 'green' : 'slate'}>{channel.status === 'active' ? 'Đang hoạt động' : 'Cần cấu hình server'}</StatusBadge></article>)}</div></SectionCard>
      </>}
      {tab === 'payment' && <SectionCard title="Giám sát thanh toán" subtitle={`${summary.pending_payments} chờ xử lý · ${summary.rejected_transactions} giao dịch bị từ chối`}><EventTable rows={data.payment_events} onSelect={setSelected}/></SectionCard>}
      {tab === 'webhook' && <SectionCard title="SePay webhook" subtitle={`${summary.webhook_4xx} lỗi 4xx · ${summary.webhook_5xx} lỗi 5xx · ${summary.incomplete_receipts} receipt chưa hoàn tất`}><EventTable rows={data.webhook_events} onSelect={setSelected}/></SectionCard>}
      {tab === 'rescue' && <SectionCard title="Vận hành cứu hộ" subtitle={`${summary.active_rescue_requests} yêu cầu hoạt động · ${summary.online_rescuers} đối tác online`}><EventTable rows={data.rescue_events} onSelect={setSelected}/></SectionCard>}
      {tab === 'security' && <SectionCard title="Sự kiện bảo mật" subtitle={`${summary.restricted_accounts} tài khoản bị khóa hoặc tạm ngưng · ${summary.recent_security_events} sự kiện gần đây`}><EventTable rows={data.security_events} onSelect={setSelected}/></SectionCard>}
      {tab === 'alerts' && alertSection}
    </div>}</DataState>
    <DetailDrawer value={data ? selected : null} canAcknowledge={data?.can_acknowledge ?? false} busy={ackBusy} error={ackError} onClose={() => { setSelected(null); setAckError('') }} onAcknowledge={(row) => void acknowledge(row)}/>
  </>
}
