import { useMemo, useState } from 'react'
import { getServices, toggleService } from '../lib/adminApi'
import { codeValue, countValue, matchesSearch, moneyValue, numberValue, textValue } from '../lib/adminFormat'
import { useAdminData } from '../hooks/useAdminData'
import { DataState, ReloadButton, SearchFilter, UnsupportedButton } from '../components/ui/AdminData'
import { useAdminAction } from '../hooks/useAdminAction'
import { PageHeader } from '../components/ui/PageHeader'
import { StatCard, ServiceIcon } from '../components/ui/StatCard'
import { EmptyState } from '../components/ui/EmptyState'

export function ServicesPage() {
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState('')
  const resource = useAdminData(getServices, ['rescue_services', 'admin_service_catalog'])
  const action = useAdminAction(resource.reload)
  const all = resource.data ?? []
  const rows = useMemo(() => (resource.data ?? []).filter((row) => matchesSearch(query, row.name, row.code, row.admin_code, row.app_service_code) && (!status || row.is_active === (status === 'Đang hoạt động'))).sort((a, b) => numberValue(a.sort_order) - numberValue(b.sort_order)), [resource.data, query, status])
  return <><PageHeader eyebrow="DANH MỤC DỊCH VỤ" title="Quản lý Dịch vụ Cứu Hộ" description="Danh mục và trạng thái dịch vụ được dùng trong hệ thống cứu hộ." actions={<><ReloadButton resource={resource}/><UnsupportedButton>Thêm dịch vụ</UnsupportedButton></>}/>{action.notice}
    <DataState resource={resource}><div className="stat-grid">
      <StatCard label="Tổng dịch vụ" value={String(all.length)} icon="wrench"/>
      <StatCard label="Đang hoạt động" value={String(all.filter((row) => row.is_active).length)} tone="green"/>
      <StatCard label="Đã tắt" value={String(all.filter((row) => !row.is_active).length)} tone="slate"/>
      <StatCard label="Nổi bật" value={String(all.filter((row) => row.is_featured).length)}/>
    </div><div className="service-filter"><SearchFilter query={query} onQuery={setQuery} status={status} onStatus={setStatus} options={['Đang hoạt động', 'Đã tắt']} placeholder="Tìm tên hoặc mã dịch vụ..."/></div>
      <div className="services-grid">{rows.map((row) => <article className="service-card" key={row.service_id}>
        <div className="service-card-top"><span className="icon-box blue"><ServiceIcon name={row.icon || 'wrench'}/></span><div><small>{codeValue(row.code || row.admin_code)}</small><span>{row.is_active ? 'Đang hoạt động' : 'Đã tắt'}</span></div><button className={'toggle ' + (row.is_active ? 'on' : '')} role="switch" aria-checked={row.is_active} aria-label={'Bật tắt ' + textValue(row.name)} onClick={() => action.open({ title: row.is_active ? 'Tắt dịch vụ' : 'Bật dịch vụ', description: textValue(row.name), run: () => toggleService(row.service_id, !row.is_active) })}><i/></button></div>
        <h3>{textValue(row.name)}</h3><p>{row.description || 'Chưa có mô tả'}</p>
        <div className="service-price"><small>Giá tham khảo</small><strong>{moneyValue(row.base_price)} <em>/ {textValue(row.price_unit)}</em></strong></div>
        <div className="service-meta"><span>{row.is_featured ? 'Dịch vụ nổi bật' : 'Dịch vụ tiêu chuẩn'}</span><span>Thứ tự: <b>{countValue(row.sort_order)}</b></span></div>
        <div className="service-actions"><button disabled>Lịch sử giá · Chưa hỗ trợ</button><button disabled>Sửa cấu hình · Chưa hỗ trợ</button></div>
      </article>)}</div>{!rows.length && <EmptyState title="Chưa có dịch vụ" description="Không có dịch vụ phù hợp với bộ lọc hiện tại."/>}
    </DataState>{action.dialog}</>
}
