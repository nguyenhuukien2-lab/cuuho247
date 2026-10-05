import { useCallback } from 'react'
import { Link, useParams } from 'react-router-dom'
import { getCustomer } from '../lib/adminApi'
import { codeValue, countValue, dateValue, moneyValue, statusValue, textValue } from '../lib/adminFormat'
import { useAdminData } from '../hooks/useAdminData'
import { DataState, KeyValues, ReloadButton } from '../components/ui/AdminData'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { EmptyState } from '../components/ui/EmptyState'

export function CustomerDetailPage() {
  const { id = '' } = useParams()
  const loader = useCallback((signal?: AbortSignal) => getCustomer(id, signal), [id])
  const resource = useAdminData(loader, ['customer_profiles', 'customer_vehicles', 'customer_saved_addresses', 'rescue_requests'])
  const row = resource.data
  return <><PageHeader eyebrow="KHÁCH HÀNG / HỒ SƠ" title={row ? textValue(row.full_name) : 'Hồ sơ khách hàng'} description={row ? codeValue(row.customer_code) : undefined} actions={<><ReloadButton resource={resource}/><Link className="button button-white" to="/customers">Danh sách khách hàng</Link></>}/>
    <DataState resource={resource}>{!row ? <EmptyState title="Không tìm thấy khách hàng" description="Khách hàng không tồn tại hoặc bạn chưa có quyền xem."/> : <div className="detail-grid">
      <div><SectionCard title="Thông tin khách hàng"><KeyValues items={[[ 'Họ tên', textValue(row.full_name)], ['Email', textValue(row.email)], ['Điện thoại', textValue(row.phone)], ['Ngày tạo', dateValue(row.created_at)], ['Trạng thái', statusValue(row.status)]]}/></SectionCard>
        <SectionCard title="Hoạt động cứu hộ"><KeyValues items={[[ 'Số xe', countValue(row.vehicle_count)], ['Số địa chỉ', countValue(row.address_count)], ['Số yêu cầu', countValue(row.request_count)], ['Đã hoàn tất', countValue(row.completed_count)], ['Tổng chi tiêu', moneyValue(row.total_spent)]]}/></SectionCard></div>
      <div><SectionCard title="Phương tiện đã lưu"><EmptyState title="Chưa có dữ liệu chi tiết phương tiện" description="Thông tin xe chưa được kết nối."/></SectionCard><SectionCard title="Địa chỉ đã lưu"><EmptyState title="Chưa có dữ liệu chi tiết địa chỉ" description="Danh sách địa chỉ chưa được kết nối."/></SectionCard><SectionCard title="Lịch sử cứu hộ"><EmptyState title="Chưa kết nối lịch sử đơn của khách hàng" description="Tra cứu yêu cầu tại trang Yêu cầu cứu hộ."/></SectionCard></div>
    </div>}</DataState></>
}
