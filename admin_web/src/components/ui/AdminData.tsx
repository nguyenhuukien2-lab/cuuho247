import { useState } from 'react'
import type { ReactNode } from 'react'
import { RefreshCw, Search } from 'lucide-react'
import { EmptyState } from './EmptyState'
import { statusValue } from '../../lib/adminFormat'

type Resource = { loading: boolean; refreshing: boolean; error: string | null; reload: () => Promise<void>; realtimeWarning: boolean }
export function ReloadButton({ resource }: { resource: Resource }) {
  return <button className="button button-white" disabled={resource.refreshing} onClick={() => void resource.reload()}><RefreshCw size={14}/>{resource.refreshing ? 'Đang tải...' : 'Tải lại'}</button>
}
export function DataState({ resource, children }: { resource: Resource; children: ReactNode }) {
  if (resource.loading) return <div className="page-loading" role="status">Đang tải dữ liệu...</div>
  if (resource.error) return <div className="data-error" role="alert"><strong>Không thể tải dữ liệu</strong><p>{resource.error}</p><ReloadButton resource={resource}/></div>
  return <>{resource.realtimeWarning && <div className="data-notice" role="status">Kết nối cập nhật trực tiếp bị gián đoạn. Dữ liệu vẫn được tải lại định kỳ; bạn có thể bấm Tải lại.</div>}{children}</>
}
export function UnsupportedButton({ children }: { children: ReactNode }) {
  return <button type="button" className="button button-white" disabled title="Chưa hỗ trợ">{children} · Chưa hỗ trợ</button>
}
export function SearchFilter({ query, onQuery, status, onStatus, options, placeholder = 'Tìm kiếm...' }: {
  query: string; onQuery: (value: string) => void; status?: string; onStatus?: (value: string) => void
  options?: string[]; placeholder?: string
}) {
  return <div className="filter-row"><label className="search-field"><Search size={16}/><input aria-label={placeholder} value={query} onChange={(event) => onQuery(event.target.value)} placeholder={placeholder}/></label>{onStatus && <label className="select-field"><select aria-label="Lọc trạng thái" value={status} onChange={(event) => onStatus(event.target.value)}><option value="">Tất cả trạng thái</option>{options?.map((value) => <option value={value} key={value}>{statusValue(value)}</option>)}</select></label>}</div>
}
export function DataTable<T>({ rows, rowKey, columns, emptyTitle }: {
  rows: T[]; rowKey: (row: T) => string; columns: { label: string; render: (row: T) => ReactNode }[]; emptyTitle: string
}) {
  const [page, setPage] = useState(0)
  const total = Math.max(1, Math.ceil(rows.length / 20))
  const current = Math.min(page, total - 1)
  if (!rows.length) return <EmptyState title={emptyTitle} description="Không có dữ liệu phù hợp với bộ lọc hiện tại."/>
  return <><div className="table-scroll"><table><thead><tr>{columns.map((column) => <th key={column.label}>{column.label}</th>)}</tr></thead><tbody>{rows.slice(current * 20, (current + 1) * 20).map((row) => <tr key={rowKey(row)}>{columns.map((column) => <td key={column.label}>{column.render(row)}</td>)}</tr>)}</tbody></table></div><div className="table-footer"><span>{rows.length} kết quả · Trang {current + 1}/{total}</span><div className="row-actions"><button className="small-button" disabled={!current} onClick={() => setPage(current - 1)}>Trước</button><button className="small-button" disabled={current + 1 >= total} onClick={() => setPage(current + 1)}>Sau</button></div></div></>
}
export function KeyValues({ items }: { items: [string, ReactNode][] }) {
  return <div className="key-values">{items.map(([label, value]) => <div key={label}><span>{label}</span><b>{value}</b></div>)}</div>
}
