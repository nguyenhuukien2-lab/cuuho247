// Frontend projections of the reviewed Admin Payment V1 read-only RPC contracts.
export type PaymentStatus = 'pending' | 'awaiting_payment' | 'verifying' | 'paid' | 'failed' | 'cancelled' | 'expired' | 'refunded'
export type PaymentMethod = 'cash' | 'bank_transfer'
export type Money = string | null
export interface PaymentRow {
  id: string; payment_code: string | null; request_id: string; request_code: string | null
  customer_name: string | null; rescuer_name: string | null
  method: PaymentMethod | null; status: string | null
  amount_expected: Money; amount_received: Money
  created_at: string | null; paid_at: string | null; updated_at: string | null
}
export type PaymentCursor = string | Record<string, string>
export interface PaymentFilters {
  search: string; method: string; status: string; from: string; to: string
  minAmount: string; maxAmount: string
  provider?: string; verificationStatus?: string; matchResult?: string
}
export interface PaymentQuery extends PaymentFilters { cursor: PaymentCursor | null; limit: number }
export interface PaymentPage<T> { rows: T[]; next_cursor: PaymentCursor | null; total: number | null }
// Optional aggregates describe the ENTIRE filtered result, never just one page.
export interface PaymentList extends PaymentPage<PaymentRow> {
  summary?: { amount_expected: Money; amount_received: Money; paid_count: number | null; review_count: number | null }
}
export interface PaymentOverview {
  total_paid: Money; cash_paid: Money; bank_paid: Money
  pending_count: number | null; verifying_count: number | null; review_count: number | null
  series: { date: string; cash_paid: string; bank_paid: string }[]
  recent: PaymentRow[]
}
export interface PaymentPerson { code: string | null; name: string | null; phone: string | null; email: string | null }
export interface PaymentDetail extends PaymentRow {
  version: string | null
  request: { service: string | null; vehicle: string | null; status: string | null; completed_at: string | null } | null
  customer: PaymentPerson | null; rescuer: PaymentPerson | null
  cash_confirmation: { confirmed_by: string | null; confirmed_at: string | null } | null
  bank: { state: string | null; provider: string | null; reference: string | null; bank_name: string | null; account_masked: string | null; expires_at: string | null } | null
  events: { id: string; label: string; actor_name: string | null; created_at: string | null; status: string | null }[] | null
}
export interface BankTransaction {
  id: string; provider: string | null; transaction_id: string | null
  payment_id: string | null; payment_code: string | null; request_code: string | null
  amount: Money; reference: string | null; occurred_at: string | null
  match_result: string | null; verification_status: string | null
}
export interface BankTransactionPage extends PaymentPage<BankTransaction> {
  summary?: { total_count: number | null; matched_count: number | null; unmatched_count: number | null; duplicate_count: number | null; rejected_count: number | null }
}

export interface PaymentReconciliationRow {
  id: string; provider: string | null; provider_scope: string | null; transaction_id: string | null
  amount: Money; currency: string | null; reference: string | null
  occurred_at: string | null; received_at: string | null; transaction_version: string | null
  rejection_code: string | null; receipt_id: string | null; receipt_status: string | null
  receipt_result: string | null; authentication_verified: boolean; signature_verified: boolean
  payment_id: string | null; payment_code: string | null; payment_version: string | null
  request_id: string | null; request_code: string | null; payment_status: string | null
  intent_id: string | null; intent_expires_at: string | null; late_payment: boolean
  case_id: string | null; reconciliation_status: string; case_reason_code: string | null
  case_version: string | null; resolved_by: string | null; resolved_at: string | null
}

export interface PaymentRefund {
  id: string; payment_id: string; payment_code: string | null; bank_transaction_id: string | null
  source_kind: string | null; amount: Money; currency: string | null; reason_code: string | null
  status: string | null; requested_by: string | null; approved_by: string | null; processed_by: string | null
  requested_at: string | null; approved_at: string | null; processing_at: string | null
  refunded_at: string | null; failed_at: string | null; evidence_reference: string | null
  failure_code: string | null; updated_at: string | null; version: string | null
}

export interface PaymentOperationsReport {
  bank_total: Money; cash_total: Money; refund_total: Money
  paid_count: number | null; unpaid_count: number | null; rejected_transactions: number | null
  late_payments: number | null; refund_pending: number | null
}

export interface PaymentOperationsData {
  reconciliation: PaymentPage<PaymentReconciliationRow>
  refunds: PaymentRefund[]
  report: PaymentOperationsReport
}

export interface PaymentOperationResult {
  id: string; payment_id: string | null; status: string | null; version: string | null
}
