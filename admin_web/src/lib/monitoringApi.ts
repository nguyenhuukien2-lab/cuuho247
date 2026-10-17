import { supabase } from './supabase'
import type { ApiResult } from './adminTypes'
import type { AlertSeverity, MonitoringAlert, MonitoringDashboard, MonitoringDeliveryChannel, MonitoringEvent, MonitoringStatus } from './monitoringTypes'

type JsonObject = Record<string, unknown>
const object = (value: unknown): JsonObject => value != null && typeof value === 'object' && !Array.isArray(value) ? value as JsonObject : {}
const array = (value: unknown) => Array.isArray(value) ? value : []
const text = (value: unknown) => typeof value === 'string' ? value : null
const count = (value: unknown) => typeof value === 'number' && Number.isSafeInteger(value) && value >= 0 ? value : 0
const severity = (value: unknown): AlertSeverity => value === 'critical' || value === 'warning' ? value : 'info'
const status = (value: unknown): MonitoringStatus => value === 'critical' || value === 'degraded' ? value : 'healthy'

// Reject missing/incompatible snapshots instead of displaying a healthy, empty system.
function validDashboard(value: unknown): boolean {
  const root = object(value), summary = object(root.summary)
  const counts = ['webhook_4xx', 'webhook_5xx', 'payment_failures', 'pending_payments', 'rejected_transactions',
    'incomplete_receipts', 'active_rescue_requests', 'online_rescuers', 'restricted_accounts', 'recent_security_events', 'open_alerts', 'critical_alerts']
  const hasText = (value: unknown) => typeof value === 'string' && value.length > 0
  const hasSeverity = (value: unknown) => ['info', 'warning', 'critical'].includes(String(value))
  const rowsValid = (value: unknown, check: (row: JsonObject) => boolean) => Array.isArray(value) && value.every((row) => check(object(row)))
  return typeof root.generated_at === 'string' && Number.isFinite(Date.parse(root.generated_at))
    && Number.isInteger(root.window_hours) && Number(root.window_hours) >= 1 && Number(root.window_hours) <= 168
    && typeof root.can_acknowledge === 'boolean'
    && ['overall_status', 'webhook_status'].every((key) => ['healthy', 'degraded', 'critical'].includes(String(summary[key])))
    && counts.every((key) => typeof summary[key] === 'number' && Number.isSafeInteger(summary[key]) && Number(summary[key]) >= 0)
    && rowsValid(root.alerts, (row) => hasText(row.key) && typeof row.fingerprint === 'string' && /^[a-f0-9]{64}$/.test(row.fingerprint)
      && hasSeverity(row.severity) && hasText(row.title) && hasText(row.code) && typeof row.acknowledged === 'boolean')
    && ['payment_events', 'webhook_events', 'rescue_events', 'security_events'].every((key) => rowsValid(root[key],
      (row) => hasText(row.id) && hasText(row.code) && hasText(row.status) && hasSeverity(row.severity)))
    && rowsValid(root.delivery_channels, (row) => ['admin_web', 'telegram', 'email'].includes(String(row.channel))
      && ['active', 'requires_server_configuration'].includes(String(row.status)))
}

function loadError(code: string, httpStatus: number): string {
  if (code === '42501' || httpStatus === 403) return 'Bạn không có quyền xem Giám sát hệ thống.'
  if (httpStatus === 401) return 'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại.'
  if (code === 'PGRST202' || httpStatus === 404) return 'Dịch vụ giám sát chưa sẵn sàng. Vui lòng liên hệ quản trị hệ thống và thử tải lại.'
  return 'Dịch vụ giám sát tạm thời không khả dụng. Vui lòng thử tải lại.'
}

function safeDetail(value: unknown): MonitoringEvent['detail'] {
  const row = object(value)
  return Object.fromEntries(Object.entries(row).filter(([, item]) => item == null || ['string', 'number', 'boolean'].includes(typeof item))) as MonitoringEvent['detail']
}

function event(value: unknown): MonitoringEvent {
  const row = object(value)
  return {
    id: text(row.id) ?? '', category: text(row.category) ?? 'system', code: text(row.code) ?? 'unknown',
    status: text(row.status) ?? 'unknown', severity: severity(row.severity), occurred_at: text(row.occurred_at),
    entity_type: text(row.entity_type), entity_id: text(row.entity_id), detail: safeDetail(row.detail),
  }
}

function alert(value: unknown): MonitoringAlert {
  const row = object(value)
  return {
    key: text(row.key) ?? '', fingerprint: text(row.fingerprint) ?? '', severity: severity(row.severity),
    category: text(row.category) ?? 'system', code: text(row.code) ?? 'unknown', title: text(row.title) ?? 'Cảnh báo hệ thống',
    message: text(row.message) ?? '', detected_at: text(row.detected_at), entity_type: text(row.entity_type),
    entity_id: text(row.entity_id), detail: safeDetail(row.detail), acknowledged: row.acknowledged === true,
    acknowledged_at: text(row.acknowledged_at), acknowledged_by: text(row.acknowledged_by),
  }
}

function dashboard(value: unknown): MonitoringDashboard {
  const root = object(value), summary = object(root.summary)
  const channel = (value: unknown): MonitoringDeliveryChannel => {
    const row = object(value)
    return {
      channel: row.channel === 'telegram' || row.channel === 'email' ? row.channel : 'admin_web',
      status: row.status === 'active' ? 'active' : 'requires_server_configuration',
      description: text(row.description) ?? '',
    }
  }
  return {
    generated_at: text(root.generated_at), window_hours: count(root.window_hours) || 24, can_acknowledge: root.can_acknowledge === true,
    summary: {
      overall_status: status(summary.overall_status), webhook_status: status(summary.webhook_status),
      webhook_4xx: count(summary.webhook_4xx), webhook_5xx: count(summary.webhook_5xx),
      payment_failures: count(summary.payment_failures), pending_payments: count(summary.pending_payments),
      rejected_transactions: count(summary.rejected_transactions), incomplete_receipts: count(summary.incomplete_receipts),
      active_rescue_requests: count(summary.active_rescue_requests), online_rescuers: count(summary.online_rescuers),
      restricted_accounts: count(summary.restricted_accounts), recent_security_events: count(summary.recent_security_events),
      open_alerts: count(summary.open_alerts), critical_alerts: count(summary.critical_alerts),
    },
    alerts: array(root.alerts).map(alert).filter((row) => row.key && row.fingerprint),
    payment_events: array(root.payment_events).map(event).filter((row) => row.id),
    webhook_events: array(root.webhook_events).map(event).filter((row) => row.id),
    rescue_events: array(root.rescue_events).map(event).filter((row) => row.id),
    security_events: array(root.security_events).map(event).filter((row) => row.id),
    delivery_channels: array(root.delivery_channels).map(channel),
  }
}

export async function getSystemMonitoring(signal?: AbortSignal): Promise<ApiResult<MonitoringDashboard>> {
  try {
    const { data, error, status: httpStatus } = await supabase.rpc('admin_get_system_monitoring', { p_window_hours: 24, p_limit: 100 })
    if (signal?.aborted) return { data: null, error: 'REQUEST_ABORTED' }
    if (error) return { data: null, error: loadError(error.code, httpStatus) }
    if (!validDashboard(data)) return { data: null, error: 'Dữ liệu giám sát chưa hợp lệ. Vui lòng tải lại hoặc liên hệ quản trị hệ thống.' }
    return { data: dashboard(data), error: null }
  } catch { return { data: null, error: 'Không thể kết nối máy chủ. Vui lòng thử lại.' } }
}

export async function acknowledgeSystemAlert(row: MonitoringAlert): Promise<ApiResult<{ changed: boolean; message: string }>> {
  try {
    const { data, error } = await supabase.rpc('admin_acknowledge_system_alert', {
      p_alert_key: row.key, p_fingerprint: row.fingerprint, p_operation_id: crypto.randomUUID(),
    })
    if (error) return { data: null, error: error.code === '42501' ? 'Bạn không có quyền xác nhận cảnh báo.' : 'Không thể xác nhận cảnh báo. Hãy tải lại dữ liệu.' }
    const result = object(data)
    return { data: { changed: result.changed === true, message: text(result.message) ?? 'Đã xác nhận cảnh báo.' }, error: null }
  } catch { return { data: null, error: 'Không thể kết nối máy chủ. Vui lòng thử lại.' } }
}
