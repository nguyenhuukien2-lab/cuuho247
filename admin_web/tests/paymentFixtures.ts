import type { Page } from '@playwright/test'
import type { BankTransactionPage, PaymentDetail, PaymentList, PaymentOverview } from '../src/lib/paymentTypes'

export const paymentId = '44444444-4444-4444-8444-444444444444'
export const timestamp = '2026-10-12T03:00:00Z'
export const payment: PaymentDetail = {
  id: paymentId, payment_code: 'TT-000123', request_id: '55555555-5555-4555-8555-555555555555', request_code: 'CH-000321',
  customer_name: 'Khách kiểm thử', rescuer_name: 'Đối tác kiểm thử', method: 'cash', status: 'paid',
  amount_expected: '900000', amount_received: '900000', created_at: timestamp, updated_at: timestamp, paid_at: timestamp, version: '4',
  request: { service: 'towing', vehicle: 'Xe kiểm thử · 43A-000.01', status: 'completed', completed_at: timestamp },
  customer: { code: 'KH-000001', name: 'Khách kiểm thử', phone: '0900000001', email: 'customer@example.test' },
  rescuer: { code: 'DT-000001', name: 'Đối tác kiểm thử', phone: '0900000002', email: 'rescuer@example.test' },
  cash_confirmation: { confirmed_by: 'Đối tác xác nhận tiền mặt', confirmed_at: timestamp },
  bank: null,
  events: [{ id: 'event-1', label: 'Đối tác xác nhận đã nhận tiền mặt', actor_name: 'Đối tác kiểm thử', created_at: timestamp, status: 'paid' }],
}
export const overview: PaymentOverview = {
  total_paid: '1200000', cash_paid: '900000', bank_paid: '300000', pending_count: 3, verifying_count: 2, review_count: 1,
  series: [{ date: '2026-10-11', cash_paid: '400000', bank_paid: '200000' }, { date: '2026-10-12', cash_paid: '500000', bank_paid: '100000' }], recent: [payment],
}
export const paymentList: PaymentList = {
  rows: [payment], total: 21, next_cursor: 'cursor-next',
  summary: { amount_expected: '24000000', amount_received: '1200000', paid_count: 2, review_count: 1 },
}
export const bankPage: BankTransactionPage = {
  rows: [{ id: 'txn-1', provider: 'test-provider', transaction_id: 'TEST-TXN-001', payment_id: paymentId, payment_code: payment.payment_code, request_code: payment.request_code, amount: '300000', reference: 'TEST-REFERENCE', occurred_at: timestamp, match_result: 'matched_exact', verification_status: 'verified' }],
  total: 1, next_cursor: null, summary: { total_count: 1, matched_count: 1, unmatched_count: 0, duplicate_count: 0, rejected_count: 0 },
}

const overviewRpc = {
  summary: { total_payment_count: 6, paid_count: 2, total_paid_amount: '1200000', cash_paid_amount: '900000', bank_paid_amount: '300000', awaiting_count: 3, verifying_count: 2, issue_count: 1 },
  chart: overview.series.map((item) => ({ bucket: item.date, cash_amount: item.cash_paid, bank_amount: item.bank_paid, paid_amount: String(BigInt(item.cash_paid) + BigInt(item.bank_paid)), awaiting_count: 0 })),
  recent_payments: [{ payment_id: payment.id, payment_code: payment.payment_code, request_id: payment.request_id, request_code: payment.request_code, customer_name: payment.customer_name, rescuer_name: payment.rescuer_name, method: payment.method, amount_expected: payment.amount_expected, amount_received: payment.amount_received, status: payment.status, paid_at: payment.paid_at, created_at: payment.created_at, updated_at: payment.updated_at }],
}
const listRpc = {
  rows: overviewRpc.recent_payments.map((row) => ({ ...row, customer_id: 'customer-id', rescuer_id: 'rescuer-id', version: payment.version })),
  next_cursor: { created_at: timestamp, id: paymentId }, has_more: true,
  summary: { total_count: 21, amount_expected: '24000000', amount_received: '1200000', paid_count: 2, review_count: 1 },
}
const detailRpc = {
  payment: { payment_id: payment.id, payment_code: payment.payment_code, request_id: payment.request_id, method: payment.method, status: payment.status, amount_expected: payment.amount_expected, amount_received: payment.amount_received, created_at: payment.created_at, updated_at: payment.updated_at, paid_at: payment.paid_at, version: payment.version },
  request: { request_id: payment.request_id, request_code: payment.request_code, service_code: 'towing', service_name: 'Cứu hộ kéo xe', vehicle_kind: 'Xe kiểm thử', vehicle_name: 'Xe kiểm thử', vehicle_plate: '43A-000.01', status: 'completed', final_cost: payment.amount_expected, completed_at: timestamp },
  customer: { customer_id: 'customer-id', customer_code: payment.customer.code, display_name: payment.customer.name, phone: payment.customer.phone, email: payment.customer.email },
  rescuer: { rescuer_id: 'rescuer-id', rescuer_code: payment.rescuer.code, display_name: payment.rescuer.name, vehicle: 'Xe kiểm thử', verification_status: 'approved' },
  cash: { confirmed: true, confirmed_by_rescuer_id: 'rescuer-id', confirmed_by_name: payment.cash_confirmation?.confirmed_by, confirmed_at: timestamp, amount: payment.amount_received },
  bank: null,
  timeline: [{ id: 'event-1', timestamp, event_type: 'cash_received', actor_type: 'rescuer', actor_id: 'rescuer-id', description: payment.events?.[0]?.label, result: 'paid' }],
}
const bankRpc = {
  rows: bankPage.rows.map((row) => ({ transaction_id: row.id, provider: row.provider, provider_transaction_id: row.transaction_id, provider_event_id: 'event-1', payment_id: row.payment_id, payment_code: row.payment_code, request_id: payment.request_id, request_code: row.request_code, amount: row.amount, currency: 'VND', reference: row.reference, beneficiary: '•••• 9012', occurred_at: row.occurred_at, received_at: row.occurred_at, verification_status: row.verification_status, match_result: row.match_result, matched_at: row.occurred_at })),
  next_cursor: null, has_more: false, summary: bankPage.summary,
}

export async function paymentSession(page: Page, signedIn = true) {
  const id = '11111111-1111-4111-8111-111111111111'
  const user = { id, email: 'finance@example.test', aud: 'authenticated', role: 'authenticated', created_at: timestamp }
  const payload = Buffer.from(JSON.stringify({ sub: id, role: 'authenticated', exp: Math.floor(Date.now() / 1000) + 3600 })).toString('base64url')
  const session = { access_token: `header.${payload}.signature`, refresh_token: 'refresh', expires_in: 3600, expires_at: Math.floor(Date.now() / 1000) + 3600, token_type: 'bearer', user }
  if (signedIn) await page.addInitScript((value) => localStorage.setItem('sb-admin-test-auth-token', JSON.stringify(value)), session)
  const state = { admin: true, finance: true, roleError: 0, rpcError: 0, calls: [] as { path: string; method: string; body: unknown; headers: Record<string, string> }[] }
  await page.route('https://admin-test.supabase.co/**', async (route) => {
    const request = route.request()
    const path = new URL(request.url()).pathname
    state.calls.push({ path, method: request.method(), body: request.postData() ? request.postDataJSON() : null, headers: request.headers() })
    const reply = (data: unknown, status = 200) => route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(data) })
    if (path.endsWith('/is_admin')) return reply(state.admin)
    if (path.endsWith('/has_admin_role')) return state.roleError ? reply({ code: state.roleError === 403 ? '42501' : 'XX000', message: 'PRIVATE_ERROR_MUST_NOT_RENDER' }, state.roleError) : reply(state.finance)
    const paymentReply = (data: unknown) => state.rpcError
      ? reply({ code: state.rpcError === 403 ? '42501' : 'XX000', message: 'PRIVATE_ERROR_MUST_NOT_RENDER' }, state.rpcError)
      : state.finance ? reply(data) : reply({ code: '42501', message: 'ADMIN_FORBIDDEN' }, 403)
    if (path.endsWith('/admin_get_payment_overview')) return paymentReply(overviewRpc)
    if (path.endsWith('/admin_list_payments')) return paymentReply(listRpc)
    if (path.endsWith('/admin_get_payment_detail')) return paymentReply(detailRpc)
    if (path.endsWith('/admin_list_bank_transactions')) return paymentReply(bankRpc)
    if (path.endsWith('/admin_profiles')) return reply({ id, admin_code: 'AD-000001', full_name: 'Tài chính kiểm thử' })
    if (path.endsWith('/logout')) return route.fulfill({ status: 204 })
    if (path.startsWith('/auth/v1/')) return reply(path.endsWith('/user') ? user : session)
    return reply({ message: 'Unexpected backend request in payment test' }, 500)
  })
  return state
}

// This module substitution exists ONLY in Playwright. Production paymentApi stays
// fail-closed. No fixture, mock RPC, test endpoint, flag, or bypass ships in src/.
export async function paymentFixtureApi(page: Page) {
  const state = {
    overview: structuredClone(overview), list: structuredClone(paymentList), detail: structuredClone(payment) as PaymentDetail | null,
    bank: structuredClone(bankPage), error: null as string | null, delay: 0,
    calls: [] as { kind: string; query: Record<string, unknown> }[],
  }
  await page.route('**/src/lib/paymentApi.ts*', (route) => route.fulfill({ contentType: 'application/javascript', body: `
    export const PAYMENT_BACKEND_BLOCKED = 'ADMIN_PAYMENT_BACKEND_BLOCKED';
    export const PAYMENT_PERMISSION_DENIED = 'ADMIN_PAYMENT_PERMISSION_DENIED';
    async function read(kind, query, signal) {
      const response = await fetch('/__payment_test__/' + kind, { method: 'POST', body: JSON.stringify(query), signal });
      return response.json();
    }
    export const getPaymentOverview = (query, signal) => read('overview', query, signal);
    export const getPaymentList = (query, signal) => read('list', query, signal);
    export const getPaymentDetail = (id, signal) => read('detail', { id }, signal);
    export const getBankTransactions = (query, signal) => read('bank', query, signal);
  ` }))
  await page.route('**/__payment_test__/*', async (route) => {
    const kind = new URL(route.request().url()).pathname.split('/').pop() as 'overview' | 'list' | 'detail' | 'bank'
    const query = route.request().postDataJSON() as Record<string, unknown>
    state.calls.push({ kind, query })
    if (state.delay) await new Promise((resolve) => setTimeout(resolve, state.delay))
    const data = kind === 'list' && query.cursor ? { ...state.list, rows: [{ ...payment, id: 'second-payment', payment_code: 'TT-000124' }], next_cursor: null } : state[kind]
    await route.fulfill({ contentType: 'application/json', body: JSON.stringify({ data: state.error ? null : data, error: state.error }) })
  })
  return state
}
