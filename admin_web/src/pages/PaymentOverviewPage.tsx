import { useCallback, useState } from 'react'
import { Link } from 'react-router-dom'
import { useAdminData } from '../hooks/useAdminData'
import { getPaymentOverview } from '../lib/paymentApi'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { StatCard } from '../components/ui/StatCard'
import { ReloadButton } from '../components/ui/AdminData'
import { PaymentState, PaymentsTable } from '../components/payments/PaymentUI'
import { defaultPaymentFilters, paymentCount, paymentMoney, validateFilters } from '../lib/paymentFormat'
import { PaymentMethodShare, PaymentTrend } from '../components/payments/PaymentCharts'

export function PaymentOverviewPage() {
  const [range, setRange] = useState({ from: '', to: '' })
  const [draft, setDraft] = useState(range)
  const [error, setError] = useState('')
  const loader = useCallback((signal?: AbortSignal) => getPaymentOverview(range, signal), [range])
  const resource = useAdminData(loader)
  const data = resource.error ? null : resource.data
  return <div className="payment-page">
    <PageHeader eyebrow="TÀI CHÍNH / THANH TOÁN" title="Quản lý thanh toán" description="Theo dõi thanh toán tiền mặt, chuyển khoản và các giao dịch cần kiểm tra." actions={<ReloadButton resource={resource}/>}/>
    <PaymentState resource={resource}>
      <form className="payment-range" aria-label="Khoảng thời gian thống kê" onSubmit={(event) => {
        event.preventDefault()
        const validation = validateFilters({ ...defaultPaymentFilters, ...draft })
        setError(validation)
        if (!validation) setRange({ ...draft })
      }}>
        <label className="payment-field"><span>Thống kê từ ngày</span><input type="date" value={draft.from} onChange={(event) => setDraft({ ...draft, from: event.target.value })}/></label>
        <label className="payment-field"><span>Thống kê đến ngày</span><input type="date" value={draft.to} onChange={(event) => setDraft({ ...draft, to: event.target.value })}/></label>
        <button className="button button-white" disabled={resource.refreshing}>Áp dụng thời gian</button>
      </form>
      {error && <p className="payment-filter-error" role="alert">{error}</p>}
      <div className="stat-grid payment-stats">
        <StatCard label="Tổng đã thanh toán" value={paymentMoney(data?.total_paid)} icon="wallet" note="Số tiền đã xác nhận"/>
        <StatCard label="Tiền mặt đã xác nhận" value={paymentMoney(data?.cash_paid)} icon="check" tone="green"/>
        <StatCard label="Chuyển khoản đã xác nhận" value={paymentMoney(data?.bank_paid)} icon="wallet"/>
        <StatCard label="Đang chờ" value={paymentCount(data?.pending_count)} icon="clock" tone="orange"/>
        <StatCard label="Đang xác minh" value={paymentCount(data?.verifying_count)} icon="shield"/>
        <StatCard label="Cần kiểm tra" value={paymentCount(data?.review_count)} icon="bell" tone="red"/>
      </div>
      <div className="payment-overview-charts">
        <SectionCard title="Thanh toán theo thời gian" subtitle="Số tiền đã xác nhận · VND · Giờ Việt Nam"><PaymentTrend series={data?.series ?? []}/></SectionCard>
        <SectionCard title="Tỷ trọng phương thức"><PaymentMethodShare cash={data?.cash_paid} bank={data?.bank_paid}/></SectionCard>
      </div>
      <SectionCard title="Thanh toán gần đây" action={<Link className="text-link" to="/payments/list">Xem tất cả →</Link>}><PaymentsTable rows={data?.recent ?? []} unavailable={!!resource.error}/></SectionCard>
    </PaymentState>
  </div>
}
