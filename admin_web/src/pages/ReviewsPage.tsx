import { useMemo, useState } from 'react'
import { getReviews } from '../lib/adminApi'
import { codeValue, dateValue, matchesSearch, newestFirst, numberValue, textValue } from '../lib/adminFormat'
import { initials } from '../lib/format'
import { useAdminData } from '../hooks/useAdminData'
import { DataState, ReloadButton, SearchFilter, UnsupportedButton } from '../components/ui/AdminData'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { StatCard } from '../components/ui/StatCard'
import { EmptyState } from '../components/ui/EmptyState'

export function ReviewsPage() {
  const [query, setQuery] = useState('')
  const [filter, setFilter] = useState('')
  const resource = useAdminData(getReviews, ['customer_request_reviews'])
  const all = useMemo(() => newestFirst(resource.data ?? []), [resource.data])
  const rows = useMemo(() => all.filter((row) => matchesSearch(query, row.customer_name, row.rescuer_name, codeValue(row.request_code), row.comment) && (!filter || (filter === '5 sao' ? numberValue(row.rating) === 5 : numberValue(row.rating) < 3))), [all, query, filter])
  const average = all.length ? all.reduce((sum, row) => sum + numberValue(row.rating), 0) / all.length : 0
  return <><PageHeader eyebrow="CHẤT LƯỢNG DỊCH VỤ" title="Đánh giá & Phản hồi Dịch vụ" description="Theo dõi đánh giá khách hàng gửi từ ứng dụng." actions={<><ReloadButton resource={resource}/><UnsupportedButton>Xuất báo cáo</UnsupportedButton></>}/>
    <DataState resource={resource}><div className="stat-grid">
      <StatCard label="Tổng đánh giá" value={String(all.length)}/>
      <StatCard label="Điểm trung bình" value={average.toLocaleString('vi-VN', { maximumFractionDigits: 2 })}/>
      <StatCard label="Đánh giá 5 sao" value={String(all.filter((row) => numberValue(row.rating) === 5).length)} tone="green"/>
      <StatCard label="Dưới 3 sao" value={String(all.filter((row) => numberValue(row.rating) < 3).length)} tone="orange"/>
    </div><SearchFilter query={query} onQuery={setQuery} status={filter} onStatus={setFilter} options={['5 sao', 'Dưới 3 sao']} placeholder="Tìm khách hàng, đối tác, mã ca, nội dung..."/>
      <div className="review-layout"><div><SectionCard title="Phân bố xếp hạng sao">{all.length ? <><div className="rating-score"><strong>{average.toFixed(2)}</strong><span>★ / 5</span></div>{[5, 4, 3, 2, 1].map((star) => { const count = all.filter((row) => numberValue(row.rating) === star).length; return <div className="rating-line" key={star}><span>{star} sao</span><i><b style={{ width: count / all.length * 100 + '%' }}/></i><strong>{count}</strong></div> })}</> : <EmptyState title="Chưa có đánh giá" description="Chưa có dữ liệu xếp hạng."/>}</SectionCard></div>
      <div><div className="section-heading outside"><div><h2>Đánh giá gần đây</h2><p>{rows.length} kết quả · Mới nhất trước</p></div></div>{rows.length ? rows.map((row) => {
        const rating = Math.min(5, Math.max(0, Math.round(numberValue(row.rating))))
        return <article className={'review-card' + (rating < 3 ? ' negative' : '')} key={row.review_id}><div className="review-top"><span className="avatar">{initials(row.customer_name || '?')}</span><div><b>{textValue(row.customer_name)}</b><small>{codeValue(row.request_code)} · {dateValue(row.created_at)}</small></div><span className="stars" aria-label={rating + ' sao'}>{'★'.repeat(rating)}{'☆'.repeat(5 - rating)}</span></div><blockquote>{textValue(row.comment)}</blockquote><div className="review-footer"><span>Đối tác: <b>{textValue(row.rescuer_name)}</b></span><button disabled>Phản hồi · Chưa hỗ trợ</button></div></article>
      }) : <EmptyState title="Chưa có đánh giá" description="Không có đánh giá phù hợp với bộ lọc hiện tại."/>}</div></div>
    </DataState></>
}
