import type { Page } from '@playwright/test'
import type { MonitoringDashboard } from '../src/lib/monitoringTypes'
import { paymentSession, timestamp } from './paymentFixtures'

export const monitoringFixture: MonitoringDashboard = {
  generated_at: timestamp, window_hours: 24, can_acknowledge: true,
  summary: {
    overall_status: 'critical', webhook_status: 'critical', webhook_4xx: 3, webhook_5xx: 2,
    payment_failures: 1, pending_payments: 4, rejected_transactions: 2, incomplete_receipts: 1,
    active_rescue_requests: 7, online_rescuers: 5, restricted_accounts: 2, recent_security_events: 3,
    open_alerts: 3, critical_alerts: 2,
  },
  alerts: [
    { key: 'webhook:500_burst', fingerprint: 'a'.repeat(64), severity: 'critical', category: 'webhook', code: 'multiple_webhook_failures', title: 'Webhook lỗi máy chủ liên tục', message: 'Có 3 lần webhook 500 trong 15 phút gần nhất.', detected_at: timestamp, entity_type: 'webhook', entity_id: null, detail: { attempt_count: 3, http_status: 500 }, acknowledged: false, acknowledged_at: null, acknowledged_by: null },
    { key: 'payment:transaction:one', fingerprint: 'b'.repeat(64), severity: 'critical', category: 'payment', code: 'beneficiary_mismatch', title: 'Sai tài khoản thụ hưởng', message: 'Giao dịch ngân hàng bị từ chối.', detected_at: timestamp, entity_type: 'bank_transaction', entity_id: 'transaction-one', detail: { provider: 'sepay', amount: '120000', currency: 'VND' }, acknowledged: false, acknowledged_at: null, acknowledged_by: null },
    { key: 'rescue:stale-online:one', fingerprint: 'c'.repeat(64), severity: 'warning', category: 'rescue', code: 'rescuer_presence_stale', title: 'Đối tác online mất tín hiệu', message: 'Heartbeat đã quá 120 giây.', detected_at: timestamp, entity_type: 'rescuer', entity_id: 'rescuer-one', detail: { is_online: true }, acknowledged: true, acknowledged_at: timestamp, acknowledged_by: 'operator-one' },
  ],
  payment_events: [{ id: 'transaction:one', category: 'payment', code: 'amount_mismatch', status: 'rejected', severity: 'warning', occurred_at: timestamp, entity_type: 'bank_transaction', entity_id: 'transaction-one', detail: { provider: 'sepay', amount: '120000' } }],
  webhook_events: [{ id: 'attempt:one', category: 'webhook', code: 'invalid_signature', status: '401', severity: 'warning', occurred_at: timestamp, entity_type: 'webhook_attempt', entity_id: '1', detail: { http_status: 401, stage: 'authenticate_normalize', duration_ms: 12 } }],
  rescue_events: [{ id: 'request:one', category: 'rescue', code: 'active_rescue_request', status: 'in_progress', severity: 'info', occurred_at: timestamp, entity_type: 'rescue_request', entity_id: 'request-one', detail: { request_code: 'CH-000160', service_code: 'towing' } }],
  security_events: [{ id: 'system:one', category: 'security', code: 'account_control', status: 'recorded', severity: 'warning', occurred_at: timestamp, entity_type: 'system_audit', entity_id: 'account-one', detail: { action: 'account_control', version: '1' } }],
  delivery_channels: [
    { channel: 'admin_web', status: 'active', description: 'Cảnh báo được hiển thị từ RPC admin-only.' },
    { channel: 'telegram', status: 'requires_server_configuration', description: 'Cần worker và secret server-side.' },
    { channel: 'email', status: 'requires_server_configuration', description: 'Cần provider email server-side.' },
  ],
}

export async function monitoringSession(page: Page) {
  await paymentSession(page)
  const state = {
    data: structuredClone(monitoringFixture), readError: false, ackError: false,
    failure: null as { status: number; code: string } | null,
    response: undefined as unknown, waitForRead: undefined as Promise<void> | undefined,
    calls: [] as { name: string; body: Record<string, unknown> }[],
  }
  await page.route('**/rest/v1/rpc/admin_*system_*', async (route) => {
    const name = new URL(route.request().url()).pathname.split('/').pop()!
    const body = route.request().postDataJSON() as Record<string, unknown>
    state.calls.push({ name, body })
    if (name === 'admin_get_system_monitoring') {
      await state.waitForRead
      if (state.failure) return route.fulfill({ status: state.failure.status, contentType: 'application/json', body: JSON.stringify({ code: state.failure.code, message: 'PRIVATE_BACKEND_DETAIL', details: 'PRIVATE_SQL_DETAIL', hint: 'PRIVATE_HINT' }) })
      if (state.readError) return route.fulfill({ status: 403, contentType: 'application/json', body: JSON.stringify({ code: '42501', message: 'PRIVATE_ROLE_DETAIL' }) })
      return route.fulfill({ contentType: 'application/json', body: JSON.stringify(state.response === undefined ? state.data : state.response) })
    }
    if (name === 'admin_acknowledge_system_alert') {
      if (state.ackError) return route.fulfill({ status: 409, contentType: 'application/json', body: JSON.stringify({ code: '40001', message: 'PRIVATE_STALE_DETAIL' }) })
      state.data.alerts = state.data.alerts.map((row) => row.key === body.p_alert_key ? { ...row, acknowledged: true, acknowledged_at: timestamp, acknowledged_by: 'operator-one' } : row)
      state.data.summary.open_alerts--
      return route.fulfill({ contentType: 'application/json', body: JSON.stringify({ changed: true, message: 'Đã xác nhận cảnh báo.' }) })
    }
    return route.fallback()
  })
  return state
}
