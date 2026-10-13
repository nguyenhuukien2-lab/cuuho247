import { Link } from 'react-router-dom'
import { getBankTransactions } from '../lib/paymentApi'
import { dateValue, textValue } from '../lib/adminFormat'
import { usePaymentQuery } from '../hooks/usePaymentQuery'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { StatCard } from '../components/ui/StatCard'
import { StatusBadge } from '../components/ui/StatusBadge'
import { DataTable, ReloadButton } from '../components/ui/AdminData'
import { PaymentFiltersForm, PaymentPagination, PaymentState } from '../components/payments/PaymentUI'
import { paymentCount, paymentMoney } from '../lib/paymentFormat'

const bankStates: Record<string, [string, 'blue' | 'green' | 'orange' | 'red' | 'slate']> = {
  matched: ['Đã khớp', 'blue'], matched_exact: ['Khớp chính xác', 'blue'], unmatched: ['Chưa khớp', 'orange'],
  duplicate: ['Trùng lặp', 'slate'], rejected: ['Bị từ chối', 'red'], verified: ['Đã xác minh', 'green'],
  pending: ['Đang chờ', 'orange'], verifying: ['Đang xác minh', 'blue'], received: ['Đã tiếp nhận', 'slate'],
}
function BankStatus({ value }: { value: string | null }) {
  const entry = value && Object.hasOwn(bankStates, value) ? bankStates[value] : null
  return value ? <StatusBadge tone={entry?.[1] ?? 'slate'}>{entry?.[0] ?? value}</StatusBadge> : <span>—</span>
}

export function BankTransactionsPage() {
  const { resource, filters, page, apply, next, previous } = usePaymentQuery(getBankTransactions)
  const data = resource.error ? null : resource.data
  return <div className="payment-page">
    <PageHeader eyebrow="TÀI CHÍNH / THANH TOÁN" title="Giao dịch ngân hàng" description="Theo dõi giao dịch từ nhà cung cấp, kết quả khớp và trạng thái xác minh." actions={<ReloadButton resource={resource}/>}/>
    <PaymentState resource={resource}>
      <div className="stat-grid payment-bank-stats">
        <StatCard label="Tổng giao dịch" value={paymentCount(data?.summary?.total_count)} icon="wallet"/>
        <StatCard label="Đã khớp" value={paymentCount(data?.summary?.matched_count)} icon="check"/>
        <StatCard label="Chưa khớp" value={paymentCount(data?.summary?.unmatched_count)} icon="clock" tone="orange"/>
        <StatCard label="Trùng lặp" value={paymentCount(data?.summary?.duplicate_count)} icon="clipboard" tone="slate"/>
        <StatCard label="Bị từ chối" value={paymentCount(data?.summary?.rejected_count)} icon="x" tone="red"/>
      </div>
      <SectionCard title="Tra cứu giao dịch" subtitle="Thời gian giao dịch · Giờ Việt Nam"><PaymentFiltersForm bank value={filters} onApply={apply} busy={resource.refreshing}/></SectionCard>
      <SectionCard title="Giao dịch từ nhà cung cấp">
        <DataTable rows={data?.rows ?? []} rowKey={(row) => row.id} hidePagination emptyTitle={resource.error ? 'Chưa có dữ liệu giao dịch được kết nối' : 'Không có giao dịch ngân hàng phù hợp'} columns={[
          { label: 'Nhà cung cấp', render: (row) => textValue(row.provider) },
          { label: 'Mã giao dịch', render: (row) => textValue(row.transaction_id) },
          { label: 'Thanh toán', render: (row) => row.payment_id ? <Link className="id-link" to={'/payments/' + encodeURIComponent(row.payment_id)}>{row.payment_code || row.payment_id}</Link> : textValue(row.payment_code) },
          { label: 'Yêu cầu', render: (row) => textValue(row.request_code) },
          { label: 'Số tiền', render: (row) => paymentMoney(row.amount) },
          { label: 'Tham chiếu', render: (row) => textValue(row.reference) },
          { label: 'Thời gian giao dịch', render: (row) => dateValue(row.occurred_at) },
          { label: 'Kết quả khớp', render: (row) => <BankStatus value={row.match_result}/> },
          { label: 'Xác minh', render: (row) => <BankStatus value={row.verification_status}/> },
        ]}/>
        <PaymentPagination page={page} total={data?.total ?? null} hasNext={!!data?.next_cursor} disabled={resource.loading || resource.refreshing || !!resource.error} onPrevious={previous} onNext={() => next(data?.next_cursor)}/>
      </SectionCard>
    </PaymentState>
  </div>
}
