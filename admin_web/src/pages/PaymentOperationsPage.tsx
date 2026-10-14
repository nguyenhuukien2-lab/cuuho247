import { useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { getPaymentOperations, requestLatePaymentRefund, resolveLatePayment, transitionPaymentRefund } from '../lib/paymentApi'
import type { PaymentReconciliationRow, PaymentRefund } from '../lib/paymentTypes'
import { usePaymentQuery } from '../hooks/usePaymentQuery'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { StatCard } from '../components/ui/StatCard'
import { DataTable, ReloadButton } from '../components/ui/AdminData'
import { PaymentPagination, PaymentState } from '../components/payments/PaymentUI'
import { dateValue, textValue } from '../lib/adminFormat'
import { defaultPaymentFilters, paymentCount, paymentMoney, validateFilters } from '../lib/paymentFormat'
import { StatusBadge } from '../components/ui/StatusBadge'

const operationStatus: Record<string, [string, 'blue' | 'green' | 'orange' | 'red' | 'slate']> = {
  pending: ['Chờ đối soát', 'orange'], refund_required: ['Cần hoàn tiền', 'red'], dismissed: ['Đã loại trừ', 'slate'],
  requested: ['Đã yêu cầu', 'orange'], approved: ['Đã duyệt', 'blue'], processing: ['Đang xử lý', 'blue'],
  refunded: ['Đã hoàn', 'green'], failed: ['Thất bại', 'red'],
}
function OperationStatus({ value }: { value: string | null }) {
  const item = value ? operationStatus[value] : undefined
  return <StatusBadge tone={item?.[1] ?? 'slate'}>{item?.[0] ?? value ?? '—'}</StatusBadge>
}

export function PaymentOperationsPage() {
  const { resource, filters, page, apply, next, previous } = usePaymentQuery(getPaymentOperations)
  const [draft, setDraft] = useState(filters)
  const [filterError, setFilterError] = useState('')
  const [actionError, setActionError] = useState('')
  const [busy, setBusy] = useState('')
  const [evidence, setEvidence] = useState<Record<string, string>>({})
  const operations = useRef(new Map<string, string>())
  const data = resource.error ? null : resource.data

  const run = async (key: string, action: (operationId: string) => ReturnType<typeof resolveLatePayment>) => {
    if (busy) return
    const operationId = operations.current.get(key) ?? crypto.randomUUID()
    operations.current.set(key, operationId)
    setBusy(key); setActionError('')
    const result = await action(operationId)
    setBusy('')
    if (result.error) { setActionError(result.error); return }
    operations.current.delete(key)
    await resource.reload()
  }
  const resolve = (row: PaymentReconciliationRow, resolution: 'refund_required' | 'dismissed') =>
    run(`resolve:${row.id}:${resolution}`, (id) => resolveLatePayment(row, resolution, id))
  const requestRefund = (row: PaymentReconciliationRow) =>
    run(`request:${row.id}`, (id) => requestLatePaymentRefund(row, id))
  const transition = (refund: PaymentRefund, action: 'approve' | 'start_processing' | 'record_refunded' | 'record_failed') =>
    run(`refund:${refund.id}:${action}`, (id) => transitionPaymentRefund(refund, action, id, evidence[refund.id]?.trim()))

  return <div className="payment-page">
    <PageHeader eyebrow="TÀI CHÍNH / THANH TOÁN" title="Vận hành thanh toán" description="Đối soát giao dịch bị từ chối, xử lý late payment và quản lý hoàn tiền có kiểm soát." actions={<ReloadButton resource={resource}/>}/>
    <PaymentState resource={resource}>
      <form className="payment-filters" aria-label="Bộ lọc vận hành thanh toán" onSubmit={(event) => {
        event.preventDefault()
        const validation = validateFilters(draft)
        setFilterError(validation)
        if (!validation) apply(draft)
      }}>
        <label className="payment-field"><span>Reference, giao dịch, payment</span><input aria-label="Reference, giao dịch, payment" maxLength={128} value={draft.search} onChange={(event) => setDraft({ ...draft, search: event.target.value })}/></label>
        <label className="payment-field"><span>Trạng thái đối soát</span><select aria-label="Trạng thái đối soát" value={draft.status} onChange={(event) => setDraft({ ...draft, status: event.target.value })}><option value="">Tất cả</option><option value="pending">Chờ đối soát</option><option value="refund_required">Cần hoàn tiền</option><option value="dismissed">Đã loại trừ</option></select></label>
        <label className="payment-field"><span>Từ ngày</span><input aria-label="Đối soát từ ngày" type="date" value={draft.from} onChange={(event) => setDraft({ ...draft, from: event.target.value })}/></label>
        <label className="payment-field"><span>Đến ngày</span><input aria-label="Đối soát đến ngày" type="date" value={draft.to} onChange={(event) => setDraft({ ...draft, to: event.target.value })}/></label>
        <div className="payment-filter-actions"><button className="button button-blue" disabled={resource.refreshing || !!busy}>Áp dụng</button><button className="button button-white" type="button" disabled={resource.refreshing || !!busy} onClick={() => { setDraft(defaultPaymentFilters); apply(defaultPaymentFilters) }}>Xóa lọc</button></div>
      </form>
      {filterError && <p className="payment-filter-error" role="alert">{filterError}</p>}
      {actionError && <div className="data-notice payment-notice" role="alert">Không thể hoàn tất thao tác. Dữ liệu có thể đã thay đổi; hãy tải lại và kiểm tra audit trail.</div>}
      <div className="stat-grid payment-ops-stats">
        <StatCard label="Chuyển khoản" value={paymentMoney(data?.report.bank_total)} icon="wallet"/>
        <StatCard label="Tiền mặt" value={paymentMoney(data?.report.cash_total)} icon="wallet"/>
        <StatCard label="Đã thanh toán" value={paymentCount(data?.report.paid_count)} icon="check" tone="green"/>
        <StatCard label="Chưa thanh toán" value={paymentCount(data?.report.unpaid_count)} icon="clock" tone="orange"/>
        <StatCard label="Giao dịch bị từ chối" value={paymentCount(data?.report.rejected_transactions)} icon="x" tone="red"/>
        <StatCard label="Late payment" value={paymentCount(data?.report.late_payments)} icon="bell" tone="orange"/>
        <StatCard label="Tổng đã hoàn" value={paymentMoney(data?.report.refund_total)} icon="wallet"/>
        <StatCard label="Hoàn tiền đang mở" value={paymentCount(data?.report.refund_pending)} icon="clipboard"/>
      </div>

      <SectionCard title="Hàng chờ đối soát" subtitle="Chỉ giao dịch rejected/unmatched; payment status không bị thay đổi">
        <DataTable rows={data?.reconciliation.rows ?? []} rowKey={(row) => row.id} hidePagination emptyTitle="Không có giao dịch cần đối soát" columns={[
          { label: 'Giao dịch', render: (row) => <><strong>{textValue(row.transaction_id)}</strong><small>{textValue(row.provider)}</small></> },
          { label: 'Reference', render: (row) => textValue(row.reference) },
          { label: 'Số tiền', render: (row) => paymentMoney(row.amount) },
          { label: 'Từ chối', render: (row) => <><OperationStatus value={row.reconciliation_status}/><small>{textValue(row.rejection_code)}</small></> },
          { label: 'Webhook receipt', render: (row) => <><strong>{textValue(row.receipt_status)}</strong><small>{row.authentication_verified ? 'Đã xác thực' : 'Chưa xác thực'} · {textValue(row.receipt_result)}</small></> },
          { label: 'Payment / yêu cầu', render: (row) => row.payment_id ? <><Link className="id-link" to={'/payments/' + encodeURIComponent(row.payment_id)}>{row.payment_code || row.payment_id}</Link><small>{textValue(row.request_code)}</small></> : <span>Không tìm thấy</span> },
          { label: 'Nhận lúc', render: (row) => dateValue(row.received_at) },
          { label: 'Xử lý có kiểm soát', render: (row) => <div className="payment-operation-actions">
            {row.reconciliation_status === 'pending' && row.late_payment && <><button className="small-button" disabled={!!busy} onClick={() => void resolve(row, 'refund_required')}>Chuyển sang hoàn tiền</button><button className="small-button" disabled={!!busy} onClick={() => void resolve(row, 'dismissed')}>Loại trừ</button></>}
            {row.reconciliation_status === 'refund_required' && row.payment_id && row.payment_version && <button className="small-button" disabled={!!busy || data?.refunds.some((item) => item.bank_transaction_id === row.id && item.status !== 'failed')} onClick={() => void requestRefund(row)}>Tạo yêu cầu hoàn</button>}
            {row.resolved_at && <small>{dateValue(row.resolved_at)}</small>}
          </div> },
        ]}/>
        <PaymentPagination page={page} total={null} hasNext={!!data?.reconciliation.next_cursor} disabled={resource.loading || resource.refreshing || !!resource.error || !!busy} onPrevious={previous} onNext={() => next(data?.reconciliation.next_cursor)}/>
      </SectionCard>

      <SectionCard title="Hoàn tiền" subtitle="V1 thủ công: yêu cầu → duyệt bởi người khác → xử lý → ghi nhận kết quả có bằng chứng">
        <DataTable rows={data?.refunds ?? []} rowKey={(row) => row.id} hidePagination emptyTitle="Chưa có yêu cầu hoàn tiền" columns={[
          { label: 'Payment', render: (row) => <Link className="id-link" to={'/payments/' + encodeURIComponent(row.payment_id)}>{row.payment_code || row.payment_id}</Link> },
          { label: 'Số tiền', render: (row) => paymentMoney(row.amount) },
          { label: 'Lý do', render: (row) => textValue(row.reason_code) },
          { label: 'Trạng thái', render: (row) => <OperationStatus value={row.status}/> },
          { label: 'Thời gian', render: (row) => dateValue(row.updated_at ?? row.requested_at) },
          { label: 'Audit actor', render: (row) => <small>Yêu cầu: {textValue(row.requested_by)}<br/>Duyệt: {textValue(row.approved_by)}<br/>Xử lý: {textValue(row.processed_by)}</small> },
          { label: 'Thao tác', render: (row) => <div className="payment-operation-actions">
            {row.status === 'requested' && <button className="small-button" disabled={!!busy} onClick={() => void transition(row, 'approve')}>Duyệt</button>}
            {row.status === 'approved' && <button className="small-button" disabled={!!busy} onClick={() => void transition(row, 'start_processing')}>Bắt đầu xử lý</button>}
            {row.status === 'processing' && <><input aria-label={'Bằng chứng hoàn tiền ' + row.id} placeholder="Mã xác nhận ngân hàng" maxLength={128} value={evidence[row.id] ?? ''} onChange={(event) => setEvidence({ ...evidence, [row.id]: event.target.value })}/><button className="small-button" disabled={!!busy || !(evidence[row.id]?.trim())} onClick={() => void transition(row, 'record_refunded')}>Ghi nhận đã hoàn</button><button className="small-button" disabled={!!busy || !/^[a-z][a-z0-9_]{0,63}$/.test(evidence[row.id]?.trim() ?? '')} onClick={() => void transition(row, 'record_failed')}>Ghi nhận thất bại</button></>}
            {row.evidence_reference && <small>Bằng chứng: {row.evidence_reference}</small>}{row.failure_code && <small>Lỗi: {row.failure_code}</small>}
          </div> },
        ]}/>
      </SectionCard>
    </PaymentState>
  </div>
}
