import { supabase } from './supabase'
import type { ApiResult } from './adminTypes'
import type { BankTransaction, BankTransactionPage, PaymentDetail, PaymentList, PaymentOverview, PaymentQuery, PaymentRow } from './paymentTypes'

export const PAYMENT_BACKEND_BLOCKED = 'ADMIN_PAYMENT_BACKEND_BLOCKED'
export const PAYMENT_PERMISSION_DENIED = 'ADMIN_PAYMENT_PERMISSION_DENIED'

type JsonObject = Record<string, unknown>
const object = (value: unknown): JsonObject => value != null && typeof value === 'object' && !Array.isArray(value) ? value as JsonObject : {}
const array = (value: unknown) => Array.isArray(value) ? value : []
const nullableString = (value: unknown) => typeof value === 'string' ? value : null
const money = (value: unknown) => typeof value === 'string' && /^\d+$/.test(value) ? value : null
const count = (value: unknown) => typeof value === 'number' && Number.isSafeInteger(value) && value >= 0 ? value : null

function vietnamRange(from: string, to: string) {
  const start = from ? new Date(`${from}T00:00:00+07:00`).toISOString() : null
  const endDate = to ? new Date(`${to}T00:00:00+07:00`) : null
  if (endDate) endDate.setUTCDate(endDate.getUTCDate() + 1)
  return { p_from: start, p_to: endDate?.toISOString() ?? null }
}

function paymentRow(value: unknown): PaymentRow {
  const row = object(value)
  return {
    id: nullableString(row.payment_id) ?? '', payment_code: nullableString(row.payment_code),
    request_id: nullableString(row.request_id) ?? '', request_code: nullableString(row.request_code),
    customer_name: nullableString(row.customer_name), rescuer_name: nullableString(row.rescuer_name),
    method: row.method === 'cash' || row.method === 'bank_transfer' ? row.method : null,
    status: nullableString(row.status), amount_expected: money(row.amount_expected), amount_received: money(row.amount_received),
    created_at: nullableString(row.created_at), paid_at: nullableString(row.paid_at), updated_at: nullableString(row.updated_at),
  }
}

function paymentOverview(value: unknown): PaymentOverview {
  const root = object(value), summary = object(root.summary)
  return {
    total_paid: money(summary.total_paid_amount), cash_paid: money(summary.cash_paid_amount), bank_paid: money(summary.bank_paid_amount),
    pending_count: count(summary.awaiting_count), verifying_count: count(summary.verifying_count), review_count: count(summary.issue_count),
    series: array(root.chart).map(object).map((entry) => ({
      date: nullableString(entry.bucket) ?? '', cash_paid: money(entry.cash_amount) ?? '0', bank_paid: money(entry.bank_amount) ?? '0',
    })).filter((entry) => entry.date),
    recent: array(root.recent_payments).map(paymentRow).filter((row) => row.id),
  }
}

function paymentList(value: unknown): PaymentList {
  const root = object(value), summary = object(root.summary)
  return {
    rows: array(root.rows).map(paymentRow).filter((row) => row.id),
    next_cursor: typeof root.next_cursor === 'string' || (root.next_cursor != null && typeof root.next_cursor === 'object') ? root.next_cursor as PaymentList['next_cursor'] : null,
    total: count(summary.total_count),
    summary: { amount_expected: money(summary.amount_expected), amount_received: money(summary.amount_received), paid_count: count(summary.paid_count), review_count: count(summary.review_count) },
  }
}

function paymentDetail(value: unknown): PaymentDetail | null {
  if (value == null) return null
  const root = object(value), payment = object(root.payment), request = object(root.request), customer = object(root.customer), rescuer = object(root.rescuer)
  const cash = root.cash == null ? null : object(root.cash), bank = root.bank == null ? null : object(root.bank)
  const vehicle = [nullableString(request.vehicle_name) ?? nullableString(request.vehicle_kind), nullableString(request.vehicle_plate)].filter(Boolean).join(' · ') || null
  const base = paymentRow({ ...payment, request_code: request.request_code, customer_name: customer.display_name, rescuer_name: rescuer.display_name })
  return {
    ...base, version: nullableString(payment.version),
    request: { service: nullableString(request.service_name) ?? nullableString(request.service_code), vehicle, status: nullableString(request.status), completed_at: nullableString(request.completed_at) },
    customer: { code: nullableString(customer.customer_code), name: nullableString(customer.display_name), phone: nullableString(customer.phone), email: nullableString(customer.email) },
    rescuer: { code: nullableString(rescuer.rescuer_code), name: nullableString(rescuer.display_name), phone: null, email: null },
    cash_confirmation: cash && cash.confirmed === true ? { confirmed_by: nullableString(cash.confirmed_by_name) ?? nullableString(cash.confirmed_by_rescuer_id), confirmed_at: nullableString(cash.confirmed_at) } : null,
    bank: bank ? { state: nullableString(bank.verification_status) ?? nullableString(bank.intent_status), provider: nullableString(bank.provider), reference: nullableString(bank.reference), bank_name: nullableString(bank.bank_name), account_masked: nullableString(bank.masked_account_number), expires_at: nullableString(bank.expires_at) } : null,
    events: array(root.timeline).map(object).map((item) => ({
      id: nullableString(item.id) ?? '', label: nullableString(item.description) ?? 'Sự kiện thanh toán',
      actor_name: item.actor_type === 'rescuer' ? nullableString(rescuer.display_name) : item.actor_type === 'customer' ? nullableString(customer.display_name) : nullableString(item.actor_type),
      created_at: nullableString(item.timestamp), status: nullableString(item.result),
    })).filter((item) => item.id),
  }
}

function bankPage(value: unknown): BankTransactionPage {
  const root = object(value), summary = object(root.summary)
  const rows: BankTransaction[] = array(root.rows).map(object).map((row) => ({
    id: nullableString(row.transaction_id) ?? '', provider: nullableString(row.provider), transaction_id: nullableString(row.provider_transaction_id),
    payment_id: nullableString(row.payment_id), payment_code: nullableString(row.payment_code), request_code: nullableString(row.request_code),
    amount: money(row.amount), reference: nullableString(row.reference), occurred_at: nullableString(row.occurred_at) ?? nullableString(row.received_at),
    match_result: nullableString(row.match_result), verification_status: nullableString(row.verification_status),
  })).filter((row) => row.id)
  return {
    rows, next_cursor: typeof root.next_cursor === 'string' || (root.next_cursor != null && typeof root.next_cursor === 'object') ? root.next_cursor as BankTransactionPage['next_cursor'] : null,
    total: count(summary.total_count), summary: { total_count: count(summary.total_count), matched_count: count(summary.matched_count), unmatched_count: count(summary.unmatched_count), duplicate_count: count(summary.duplicate_count), rejected_count: count(summary.rejected_count) },
  }
}

async function rpc<T>(name: string, args: JsonObject, map: (value: unknown) => T, signal?: AbortSignal): Promise<ApiResult<T>> {
  try {
    // useAdminData already ignores stale results through this signal. Attaching it
    // to PostgREST can short-circuit an RPC before fetch during route/auth remounts.
    const { data, error } = await supabase.rpc(name, args)
    if (signal?.aborted) return { data: null, error: 'REQUEST_ABORTED' }
    if (error) return { data: null, error: error.code === '42501' ? PAYMENT_PERMISSION_DENIED : 'Không thể tải dữ liệu thanh toán. Vui lòng thử lại.' }
    return { data: map(data), error: null }
  } catch { return { data: null, error: 'Không thể kết nối máy chủ. Vui lòng thử lại.' } }
}

export const getPaymentOverview = (range: Pick<PaymentQuery, 'from' | 'to'>, signal?: AbortSignal) =>
  rpc('admin_get_payment_overview', { ...vietnamRange(range.from, range.to), p_bucket: 'day' }, paymentOverview, signal)

export const getPaymentList = (query: PaymentQuery, signal?: AbortSignal) =>
  rpc('admin_list_payments', {
    p_search: query.search || null, p_method: query.method || null, p_status: query.status || null,
    ...vietnamRange(query.from, query.to), p_min_amount: query.minAmount || null, p_max_amount: query.maxAmount || null,
    p_limit: query.limit, p_cursor: query.cursor,
  }, paymentList, signal)

export const getPaymentDetail = (paymentId: string, signal?: AbortSignal) =>
  rpc('admin_get_payment_detail', { p_payment_id: paymentId }, paymentDetail, signal)

export const getBankTransactions = (query: PaymentQuery, signal?: AbortSignal) =>
  rpc('admin_list_bank_transactions', {
    p_search: query.search || null, p_provider: query.provider || null,
    p_verification_status: query.verificationStatus || null, p_match_result: query.matchResult || null,
    ...vietnamRange(query.from, query.to), p_min_amount: query.minAmount || null, p_max_amount: query.maxAmount || null,
    p_limit: query.limit, p_cursor: query.cursor,
  }, bankPage, signal)
