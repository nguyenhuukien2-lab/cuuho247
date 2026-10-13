import { getPaymentList } from '../lib/paymentApi'
import { usePaymentQuery } from '../hooks/usePaymentQuery'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { StatCard } from '../components/ui/StatCard'
import { ReloadButton } from '../components/ui/AdminData'
import { PaymentFiltersForm, PaymentPagination, PaymentState, PaymentsTable } from '../components/payments/PaymentUI'
import { paymentCount, paymentMoney } from '../lib/paymentFormat'

export function PaymentListPage() {
  const { resource, filters, page, apply, next, previous } = usePaymentQuery(getPaymentList)
  const data = resource.error ? null : resource.data
  return <div className="payment-page">
    <PageHeader eyebrow="TÀI CHÍNH / THANH TOÁN" title="Danh sách thanh toán" description="Tra cứu khoản phải thu, số tiền đã nhận và trạng thái của từng yêu cầu cứu hộ." actions={<ReloadButton resource={resource}/>}/>
    <PaymentState resource={resource}>
      <div className="stat-grid payment-list-stats">
        <StatCard label="Tổng tiền dự kiến" value={paymentMoney(data?.summary?.amount_expected)} icon="wallet"/>
        <StatCard label="Tổng tiền đã nhận" value={paymentMoney(data?.summary?.amount_received)} icon="wallet" tone="green"/>
        <StatCard label="Đã thanh toán" value={paymentCount(data?.summary?.paid_count)} icon="check"/>
        <StatCard label="Cần kiểm tra" value={paymentCount(data?.summary?.review_count)} icon="bell" tone="red"/>
      </div>
      <SectionCard title="Bộ lọc thanh toán" subtitle="Ngày tạo thanh toán · Số tiền dự kiến · Giờ Việt Nam">
        <PaymentFiltersForm value={filters} onApply={apply} busy={resource.refreshing}/>
      </SectionCard>
      <SectionCard title="Giao dịch thanh toán">
        <PaymentsTable rows={data?.rows ?? []} unavailable={!!resource.error}/>
        <PaymentPagination page={page} total={data?.total ?? null} hasNext={!!data?.next_cursor} disabled={resource.loading || resource.refreshing || !!resource.error} onPrevious={previous} onNext={() => next(data?.next_cursor)}/>
      </SectionCard>
    </PaymentState>
  </div>
}
