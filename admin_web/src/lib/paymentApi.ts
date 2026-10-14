import { supabase } from './supabase'
import type { ApiResult } from './adminTypes'
import type { BankTransaction, BankTransactionPage, PaymentDetail, PaymentList, PaymentOperationResult, PaymentOperationsData, PaymentOperationsReport, PaymentOverview, PaymentQuery, PaymentReconciliationRow, PaymentRefund, PaymentRow } from './paymentTypes'

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

function reconciliationPage(value: unknown): PaymentOperationsData['reconciliation'] {
  const root = object(value)
  const rows: PaymentReconciliationRow[] = array(root.rows).map(object).map((row) => {
    const receipt = object(row.receipt)
    return {
      id: nullableString(row.transaction_id) ?? '', provider: nullableString(row.provider), provider_scope: nullableString(row.provider_scope),
      transaction_id: nullableString(row.provider_transaction_id), amount: money(row.amount), currency: nullableString(row.currency),
      reference: nullableString(row.reference), occurred_at: nullableString(row.occurred_at), received_at: nullableString(row.received_at),
      transaction_version: nullableString(row.transaction_version), rejection_code: nullableString(row.rejection_code),
      receipt_id: nullableString(receipt.id), receipt_status: nullableString(receipt.status), receipt_result: nullableString(receipt.result_code),
      authentication_verified: receipt.authentication_verified === true, signature_verified: receipt.signature_verified === true,
      payment_id: nullableString(row.candidate_payment_id), payment_code: nullableString(row.payment_code), payment_version: nullableString(row.payment_version),
      request_id: nullableString(row.request_id), request_code: nullableString(row.request_code), payment_status: nullableString(row.payment_status),
      intent_id: nullableString(row.intent_id), intent_expires_at: nullableString(row.intent_expires_at), late_payment: row.late_payment === true,
      case_id: nullableString(row.case_id), reconciliation_status: nullableString(row.reconciliation_status) ?? 'pending',
      case_reason_code: nullableString(row.case_reason_code), case_version: nullableString(row.case_version),
      resolved_by: nullableString(row.resolved_by), resolved_at: nullableString(row.resolved_at),
    }
  }).filter((row) => row.id)
  return { rows, next_cursor: typeof root.next_cursor === 'string' || (root.next_cursor != null && typeof root.next_cursor === 'object') ? root.next_cursor as PaymentOperationsData['reconciliation']['next_cursor'] : null, total: null }
}

function operationsReport(value: unknown): PaymentOperationsReport {
  const row = object(value)
  return {
    bank_total: money(row.bank_total), cash_total: money(row.cash_total), refund_total: money(row.refund_total),
    paid_count: count(row.paid_count), unpaid_count: count(row.unpaid_count), rejected_transactions: count(row.rejected_transactions),
    late_payments: count(row.late_payments), refund_pending: count(row.refund_pending),
  }
}

function refundRows(value: unknown): PaymentRefund[] {
  return array(object(value).rows).map(object).map((row) => ({
    id: nullableString(row.refund_id) ?? '', payment_id: nullableString(row.payment_id) ?? '', payment_code: nullableString(row.payment_code),
    bank_transaction_id: nullableString(row.bank_transaction_id), source_kind: nullableString(row.source_kind), amount: money(row.amount),
    currency: nullableString(row.currency), reason_code: nullableString(row.reason_code), status: nullableString(row.status),
    requested_by: nullableString(row.requested_by), approved_by: nullableString(row.approved_by), processed_by: nullableString(row.processed_by),
    requested_at: nullableString(row.requested_at), approved_at: nullableString(row.approved_at), processing_at: nullableString(row.processing_at),
    refunded_at: nullableString(row.refunded_at), failed_at: nullableString(row.failed_at), evidence_reference: nullableString(row.evidence_reference),
    failure_code: nullableString(row.failure_code), updated_at: nullableString(row.updated_at), version: nullableString(row.version),
  })).filter((row) => row.id && row.payment_id)
}

function operationResult(value: unknown): PaymentOperationResult {
  const row = object(value)
  return {
    id: nullableString(row.refund_id) ?? nullableString(row.case_id) ?? '', payment_id: nullableString(row.payment_id),
    status: nullableString(row.status), version: nullableString(row.version),
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

export async function getPaymentOperations(query: PaymentQuery, signal?: AbortSignal): Promise<ApiResult<PaymentOperationsData>> {
  const range = vietnamRange(query.from, query.to)
  const [reconciliation, refunds, report] = await Promise.all([
    rpc('admin_list_payment_reconciliation', { p_search: query.search || null, p_status: query.status || null, ...range, p_limit: query.limit, p_cursor: query.cursor }, reconciliationPage, signal),
    rpc('admin_list_payment_refunds', { p_payment_id: null, p_status: null, ...range, p_limit: 100 }, refundRows, signal),
    rpc('admin_get_payment_operations_report', range, operationsReport, signal),
  ])
  const error = reconciliation.error || refunds.error || report.error
  return error || !reconciliation.data || !refunds.data || !report.data
    ? { data: null, error: error ?? 'Không thể tải dữ liệu vận hành thanh toán.' }
    : { data: { reconciliation: reconciliation.data, refunds: refunds.data, report: report.data }, error: null }
}

export const resolveLatePayment = (row: PaymentReconciliationRow, resolution: 'refund_required' | 'dismissed', operationId: string) =>
  rpc('admin_resolve_late_payment', {
    p_bank_transaction_id: row.id, p_expected_transaction_version: row.transaction_version,
    p_expected_case_version: row.case_version, p_resolution: resolution,
    p_reason_code: resolution === 'refund_required' ? 'late_payment_return' : 'not_customer_payment', p_operation_id: operationId,
  }, operationResult)

export const requestLatePaymentRefund = (row: PaymentReconciliationRow, operationId: string) =>
  rpc('admin_request_payment_refund', {
    p_payment_id: row.payment_id, p_bank_transaction_id: row.id, p_amount: row.amount,
    p_reason_code: 'late_payment_return', p_expected_payment_version: row.payment_version, p_operation_id: operationId,
  }, operationResult)

export const requestPaidPaymentRefund = (payment: PaymentDetail, amount: string, reasonCode: string, operationId: string) =>
  rpc('admin_request_payment_refund', {
    p_payment_id: payment.id, p_bank_transaction_id: null, p_amount: amount,
    p_reason_code: reasonCode, p_expected_payment_version: payment.version, p_operation_id: operationId,
  }, operationResult)

export const transitionPaymentRefund = (refund: PaymentRefund, action: 'approve' | 'start_processing' | 'record_refunded' | 'record_failed', operationId: string, evidence?: string) =>
  rpc('admin_transition_payment_refund', {
    p_refund_id: refund.id, p_expected_version: refund.version, p_action: action,
    p_evidence_reference: action === 'record_refunded' ? evidence || null : null,
    p_failure_code: action === 'record_failed' ? evidence || null : null, p_operation_id: operationId,
  }, operationResult)
