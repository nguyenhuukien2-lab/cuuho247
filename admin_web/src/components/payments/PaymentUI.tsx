import { useState } from 'react'
import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { DataTable, ReloadButton } from '../ui/AdminData'
import { StatusBadge } from '../ui/StatusBadge'
import { PAYMENT_BACKEND_BLOCKED, PAYMENT_PERMISSION_DENIED } from '../../lib/paymentApi'
import { dateValue, textValue } from '../../lib/adminFormat'
import type { PaymentFilters, PaymentRow, PaymentStatus } from '../../lib/paymentTypes'
import { defaultPaymentFilters, methodLabel, paymentCount, paymentMoney, paymentStatuses as statuses, validateFilters } from '../../lib/paymentFormat'
import '../../styles/payments.css'

export function PaymentStatusBadge({ status }: { status: string | null | undefined }) {
  if (!status) return <span>—</span>
  const entry = Object.hasOwn(statuses, status) ? statuses[status as PaymentStatus] : undefined
  return <StatusBadge tone={entry?.[1] ?? 'slate'}>{entry?.[0] ?? 'Trạng thái chưa hỗ trợ'}</StatusBadge>
}
type Resource = { loading: boolean; refreshing: boolean; error: string | null; reload: () => Promise<void>; realtimeWarning: boolean }
export function PaymentState({ resource, children }: { resource: Resource; children: ReactNode }) {
  if (resource.loading) return <div className="payment-skeleton" role="status" aria-label="Đang tải thanh toán"><span>Đang tải thanh toán...</span>{Array.from({ length: 6 }, (_, index) => <i key={index}/>)}</div>
  if (resource.error && resource.error !== PAYMENT_BACKEND_BLOCKED) return <div className="data-error" role="alert"><strong>{resource.error === PAYMENT_PERMISSION_DENIED ? 'Không có quyền xem thanh toán' : 'Không thể tải dữ liệu thanh toán'}</strong><p>{resource.error === PAYMENT_PERMISSION_DENIED ? 'Chỉ quản trị viên tài chính hoặc quản trị viên cấp cao được truy cập.' : 'Kết nối dữ liệu bị gián đoạn. Vui lòng thử lại.'}</p><ReloadButton resource={resource}/></div>
  return <>{resource.error === PAYMENT_BACKEND_BLOCKED && <div className="data-notice payment-notice" role="status"><strong>Dữ liệu thanh toán chưa được kết nối</strong><p>Chức năng tra cứu đang chờ kết nối dữ liệu. Vui lòng thử lại sau.</p><ReloadButton resource={resource}/></div>}{children}</>
}
export function PaymentFilterFields({ value, onChange, bank = false }: { value: PaymentFilters; onChange: (value: PaymentFilters) => void; bank?: boolean }) {
  const field = (key: keyof PaymentFilters, label: string, type = 'text') => <label className="payment-field"><span>{label}</span><input type={type} value={value[key]} maxLength={key === 'search' ? 128 : undefined} inputMode={key.includes('Amount') ? 'numeric' : undefined} onChange={(event) => onChange({ ...value, [key]: event.target.value })}/></label>
  return <div className="payment-filters">
    {field('search', bank ? 'Tìm mã giao dịch, tham chiếu' : 'Tìm mã thanh toán, yêu cầu, tên')}
    {bank && <><label className="payment-field"><span>Nhà cung cấp</span><input aria-label="Nhà cung cấp" value={value.provider ?? ''} maxLength={64} onChange={(event) => onChange({ ...value, provider: event.target.value.trim().toLowerCase() })}/></label>
      <label className="payment-field"><span>Trạng thái xác minh</span><select aria-label="Trạng thái xác minh" value={value.verificationStatus ?? ''} onChange={(event) => onChange({ ...value, verificationStatus: event.target.value })}><option value="">Tất cả trạng thái</option><option value="unverified">Chưa xác minh</option><option value="matched">Đã khớp</option><option value="verified">Đã xác minh</option><option value="rejected">Bị từ chối</option></select></label>
      <label className="payment-field"><span>Kết quả khớp</span><select aria-label="Kết quả khớp" value={value.matchResult ?? ''} onChange={(event) => onChange({ ...value, matchResult: event.target.value })}><option value="">Tất cả kết quả</option><option value="pending">Đang chờ</option><option value="matched">Đã khớp</option><option value="matched_exact">Khớp chính xác</option><option value="unmatched">Chưa khớp</option><option value="duplicate">Trùng lặp</option><option value="rejected">Bị từ chối</option></select></label></>}
    {!bank && <><label className="payment-field"><span>Phương thức</span><select aria-label="Phương thức" value={value.method} onChange={(event) => onChange({ ...value, method: event.target.value })}><option value="">Tất cả phương thức</option><option value="cash">Tiền mặt</option><option value="bank_transfer">Chuyển khoản</option></select></label>
      <label className="payment-field"><span>Trạng thái</span><select aria-label="Trạng thái" value={value.status} onChange={(event) => onChange({ ...value, status: event.target.value })}><option value="">Tất cả trạng thái</option>{Object.entries(statuses).map(([key, [label]]) => <option key={key} value={key}>{label}</option>)}</select></label></>}
    {field('from', bank ? 'Giao dịch từ ngày' : 'Tạo từ ngày', 'date')}{field('to', bank ? 'Giao dịch đến ngày' : 'Tạo đến ngày', 'date')}
    {field('minAmount', bank ? 'Số tiền tối thiểu (VND)' : 'Dự kiến tối thiểu (VND)')}{field('maxAmount', bank ? 'Số tiền tối đa (VND)' : 'Dự kiến tối đa (VND)')}
  </div>
}
export function PaymentFiltersForm({ value, onApply, bank = false, busy = false }: { value: PaymentFilters; onApply: (value: PaymentFilters) => void; bank?: boolean; busy?: boolean }) {
  const [draft, setDraft] = useState(value)
  const [error, setError] = useState('')
  return <form aria-label={bank ? 'Bộ lọc giao dịch ngân hàng' : 'Bộ lọc thanh toán'} onSubmit={(event) => {
    event.preventDefault()
    const validation = validateFilters(draft)
    setError(validation)
    if (!validation) onApply(draft)
  }}>
    <PaymentFilterFields value={draft} onChange={setDraft} bank={bank}/>
    {error && <p className="payment-filter-error" role="alert">{error}</p>}
    <div className="payment-filter-actions"><button className="button button-blue" disabled={busy} type="submit">Áp dụng bộ lọc</button><button className="button button-white" disabled={busy} type="button" onClick={() => { setDraft(defaultPaymentFilters); setError(''); onApply(defaultPaymentFilters) }}>Xóa bộ lọc</button></div>
  </form>
}
export function PaymentsTable({ rows, unavailable = false }: { rows: PaymentRow[]; unavailable?: boolean }) {
  return <DataTable rows={rows} rowKey={(row) => row.id} hidePagination emptyTitle={unavailable ? 'Chưa có dữ liệu để hiển thị' : 'Không có thanh toán phù hợp'} columns={[
    { label: 'Mã thanh toán', render: (row) => <Link className="id-link" to={'/payments/' + encodeURIComponent(row.id)}>{row.payment_code || row.id}</Link> },
    { label: 'Yêu cầu', render: (row) => textValue(row.request_code || row.request_id) },
    { label: 'Khách hàng', render: (row) => textValue(row.customer_name) },
    { label: 'Đối tác', render: (row) => textValue(row.rescuer_name) },
    { label: 'Phương thức', render: (row) => <StatusBadge tone={row.method === 'bank_transfer' ? 'blue' : 'slate'}>{methodLabel(row.method)}</StatusBadge> },
    { label: 'Dự kiến', render: (row) => paymentMoney(row.amount_expected) },
    { label: 'Đã nhận', render: (row) => paymentMoney(row.amount_received) },
    { label: 'Trạng thái', render: (row) => <PaymentStatusBadge status={row.status}/> },
    { label: 'Thanh toán lúc', render: (row) => dateValue(row.paid_at) },
    { label: 'Cập nhật lúc', render: (row) => dateValue(row.updated_at) },
    { label: 'Chi tiết', render: (row) => <Link className="text-link" aria-label={'Xem thanh toán ' + (row.payment_code || row.id)} to={'/payments/' + encodeURIComponent(row.id)}>Xem chi tiết</Link> },
  ]}/>
}
export function PaymentPagination({ page, total, hasNext, disabled, onPrevious, onNext }: { page: number; total: number | null; hasNext: boolean; disabled: boolean; onPrevious: () => void; onNext: () => void }) {
  return <div className="table-footer"><span>{total == null ? 'Chưa có tổng số kết quả' : `${paymentCount(total)} kết quả`} · Trang {page + 1}</span><div className="row-actions"><button className="small-button" disabled={disabled || page === 0} onClick={onPrevious}>Trước</button><button className="small-button" disabled={disabled || !hasNext} onClick={onNext}>Sau</button></div></div>
}
