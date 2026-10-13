import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { Info } from 'lucide-react'
import type { RescueRequest } from '../../lib/adminTypes'
import { countValue, serviceValue } from '../../lib/adminFormat'
import { EmptyState } from '../ui/EmptyState'

const localDay = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Ho_Chi_Minh', year: 'numeric', month: '2-digit', day: '2-digit' })

export function RequestTrend({ requests, days, now }: { requests: RescueRequest[]; days: number; now: string }) {
  const today = new Date(localDay.format(new Date(now)) + 'T00:00:00Z')
  const buckets = Array.from({ length: days }, (_, index) => {
    const date = new Date(today)
    date.setUTCDate(today.getUTCDate() - days + 1 + index)
    return { key: date.toISOString().slice(0, 10), label: date.getUTCDate() + '/' + (date.getUTCMonth() + 1), count: 0 }
  })
  const byDate = new Map(buckets.map((bucket) => [bucket.key, bucket]))
  for (const request of requests) {
    if (!request.created_at || Number.isNaN(Date.parse(request.created_at))) continue
    const bucket = byDate.get(localDay.format(new Date(request.created_at)))
    if (bucket) bucket.count++
  }
  const total = buckets.reduce((sum, bucket) => sum + bucket.count, 0)
  return <>
    <div className="trend-summary"><strong>{countValue(total)}</strong><span>yêu cầu trong {days} ngày</span><span className="chart-key"><i/>Yêu cầu cứu hộ</span></div>
    {total ? <div className="request-trend-chart" role="img" aria-label={'Biểu đồ ' + total + ' yêu cầu trong ' + days + ' ngày. Số liệu chi tiết ở bảng kế tiếp.'}>
      <ResponsiveContainer width="100%" height="100%" minWidth={0}>
        <BarChart data={buckets} margin={{ top: 16, right: 4, left: -24, bottom: 0 }} accessibilityLayer>
          <CartesianGrid stroke="#eaedff" vertical={false}/>
          <XAxis dataKey="label" axisLine={false} tickLine={false} tick={{ fill: '#747686', fontSize: 11 }} dy={8} minTickGap={18}/>
          <YAxis allowDecimals={false} axisLine={false} tickLine={false} tick={{ fill: '#747686', fontSize: 11 }}/>
          <Tooltip cursor={{ fill: '#f2f3ff' }} contentStyle={{ border: 'none', borderRadius: 12, boxShadow: '0 8px 32px #131b2e18', fontSize: 13 }} labelFormatter={(label) => 'Ngày ' + label}/>
          <Bar dataKey="count" name="Yêu cầu" fill="#316bf3" radius={[6, 6, 0, 0]} maxBarSize={48} isAnimationActive={false}/>
        </BarChart>
      </ResponsiveContainer>
    </div> : <div className="trend-empty"><EmptyState title={'Chưa có yêu cầu trong ' + days + ' ngày gần nhất'} description="Biểu đồ sẽ cập nhật khi có yêu cầu cứu hộ mới."/></div>}
    <table className="sr-only"><caption>Số yêu cầu cứu hộ theo ngày (giờ Việt Nam)</caption><thead><tr><th>Ngày</th><th>Yêu cầu</th></tr></thead><tbody>{buckets.map((bucket) => <tr key={bucket.key}><th>{bucket.key}</th><td>{bucket.count}</td></tr>)}</tbody></table>
    <div className="chart-foot"><Info size={15}/><span>Thống kê từ thời gian tạo yêu cầu; dữ liệu được cập nhật cùng danh sách cứu hộ.</span></div>
  </>
}

export function RequestBreakdown({ requests }: { requests: RescueRequest[] }) {
  if (!requests.length) return <EmptyState title="Chưa có dữ liệu phân bổ" description="Trạng thái và dịch vụ sẽ xuất hiện khi có yêu cầu cứu hộ."/>
  const groups = [
    { label: 'Hoàn tất', statuses: ['completed'], color: '#1d4ed8', count: 0 },
    { label: 'Đang xử lý', statuses: ['accepted', 'arriving', 'in_progress'], color: '#879ff4', count: 0 },
    { label: 'Chờ điều phối', statuses: ['searching'], color: '#ed9b5e', count: 0 },
    { label: 'Đã hủy', statuses: ['cancelled'], color: '#d95b68', count: 0 },
    { label: 'Khác / Chưa xác định', statuses: [], color: '#b8bfce', count: 0 },
  ]
  const services = new Map<string, number>()
  for (const request of requests) {
    const group = groups.find((item) => item.statuses.includes(request.status ?? '')) ?? groups[4]
    group.count++
    const service = serviceValue(request.service_type)
    services.set(service, (services.get(service) ?? 0) + 1)
  }
  let offset = 0
  const gradient = groups.map((group) => {
    const start = offset
    offset += group.count / requests.length * 100
    return group.color + ' ' + start + '% ' + offset + '%'
  }).join(', ')
  return <>
    <div className="status-distribution"><div className="status-donut" style={{ background: 'conic-gradient(' + gradient + ')' }} role="img" aria-label={countValue(requests.length) + ' yêu cầu. ' + groups.filter((group) => group.count).map((group) => group.label + ': ' + group.count).join('. ')}><div><strong>{Math.round(groups[0].count / requests.length * 100)}%</strong><span>hoàn tất</span></div></div>
      <div className="legend-list">{groups.filter((group) => group.count || group.statuses.length).map((group) => <div key={group.label}><i style={{ background: group.color }}/><span>{group.label}</span><b>{countValue(group.count)}</b></div>)}</div>
    </div>
    <h3 className="mini-heading">DỊCH VỤ ĐƯỢC YÊU CẦU NHIỀU NHẤT</h3><div className="service-distribution">{[...services].sort((a, b) => b[1] - a[1]).slice(0, 4).map(([label, count]) => <div key={label}><div><span>{label}</span><b>{Math.round(count / requests.length * 100)}%</b></div><div className="service-track"><i style={{ width: count / requests.length * 100 + '%' }}/></div></div>)}</div>
  </>
}
