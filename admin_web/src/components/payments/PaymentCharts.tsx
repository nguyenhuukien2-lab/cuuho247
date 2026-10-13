import { Area, AreaChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import type { PaymentOverview } from '../../lib/paymentTypes'
import { EmptyState } from '../ui/EmptyState'
import { KeyValues } from '../ui/AdminData'
import { paymentMoney } from '../../lib/paymentFormat'

export function PaymentTrend({ series }: { series: PaymentOverview['series'] }) {
  if (!series.length) return <div className="trend-empty"><EmptyState title="Chưa có dữ liệu biểu đồ" description="Số tiền đã xác nhận theo ngày sẽ hiển thị khi có dữ liệu thanh toán."/></div>
  const points = series.map((point) => ({ ...point, cash: Number(point.cash_paid), bank: Number(point.bank_paid) }))
  // Keep exact strings in the accessible table. Never chart rounded bigint money.
  const valid = points.every((point) => /^\d+$/.test(point.cash_paid) && /^\d+$/.test(point.bank_paid) && Number.isSafeInteger(point.cash) && Number.isSafeInteger(point.bank))
  return <>
    {valid ? <div className="payment-chart" role="img" aria-label="Thanh toán theo thời gian. Số tiền chi tiết trong bảng theo ngày.">
      <ResponsiveContainer width="100%" height="100%" minWidth={0}>
        <AreaChart data={points} margin={{ top: 16, right: 12, left: 0, bottom: 8 }} accessibilityLayer>
          <CartesianGrid stroke="var(--admin-line)" vertical={false}/>
          <XAxis dataKey="date" axisLine={false} tickLine={false} tick={{ fontSize: 11, fill: 'var(--admin-muted)' }} minTickGap={24}/>
          <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 11, fill: 'var(--admin-muted)' }} width={70} tickFormatter={(value: number) => new Intl.NumberFormat('vi-VN', { notation: 'compact' }).format(value)}/>
          <Tooltip formatter={(value) => paymentMoney(String(value))} contentStyle={{ borderColor: 'var(--admin-line)', borderRadius: 10, fontSize: 12 }}/>
          <Area dataKey="cash" name="Tiền mặt" type="monotone" stroke="var(--admin-primary)" fill="var(--admin-primary)" fillOpacity={0.12} strokeWidth={2} isAnimationActive={false}/>
          <Area dataKey="bank" name="Chuyển khoản" type="monotone" stroke="var(--admin-muted)" fill="var(--admin-muted)" fillOpacity={0.06} strokeWidth={2} strokeDasharray="4 4" isAnimationActive={false}/>
        </AreaChart>
      </ResponsiveContainer>
    </div> : <p className="muted-note">Xem số tiền chính xác trong bảng theo ngày.</p>}
    <div className="payment-chart-legend"><span><i/>Tiền mặt</span><span><i/>Chuyển khoản</span></div>
    <details className="payment-chart-data"><summary>Xem số liệu theo ngày</summary><div className="table-scroll"><table><caption>Thanh toán theo ngày (giờ Việt Nam)</caption><thead><tr><th>Ngày</th><th>Tiền mặt</th><th>Chuyển khoản</th></tr></thead><tbody>{series.map((point) => <tr key={point.date}><th>{point.date}</th><td>{paymentMoney(point.cash_paid)}</td><td>{paymentMoney(point.bank_paid)}</td></tr>)}</tbody></table></div></details>
  </>
}

export function PaymentMethodShare({ cash, bank }: { cash: string | null | undefined; bank: string | null | undefined }) {
  const available = cash != null && bank != null && /^\d+$/.test(cash) && /^\d+$/.test(bank)
  const cashValue = available ? BigInt(cash!) : 0n
  const bankValue = available ? BigInt(bank!) : 0n
  const total = cashValue + bankValue
  const share = total > 0n ? Number(bankValue * 1000n / total) / 10 : null
  return <>
    {available && share !== null ? <div className="payment-method-share"><div className="status-donut" style={{ background: `conic-gradient(var(--admin-primary) ${share}%, var(--admin-line) ${share}% 100%)` }} role="img" aria-label={`Chuyển khoản chiếm ${share.toLocaleString('vi-VN')}% số tiền đã xác nhận`}><div><strong>{share.toLocaleString('vi-VN')}%</strong><span>chuyển khoản</span></div></div></div> : <EmptyState title="Chưa có tỷ trọng thanh toán" description="Tỷ trọng dựa trên số tiền mặt và chuyển khoản đã được xác nhận."/>}
    <KeyValues items={[["Tiền mặt", paymentMoney(cash)], ["Chuyển khoản", paymentMoney(bank)]]}/>
  </>
}
