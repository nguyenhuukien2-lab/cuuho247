import { useCallback } from 'react'
import { Link, useParams } from 'react-router-dom'
import { getRescuer } from '../lib/adminApi'
import { codeValue, countValue, dateValue, statusValue, textValue } from '../lib/adminFormat'
import { useAdminData } from '../hooks/useAdminData'
import { DataState, KeyValues, ReloadButton } from '../components/ui/AdminData'
import { RescuerActions } from '../components/ui/AdminAction'
import { useAdminAction } from '../hooks/useAdminAction'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { EmptyState } from '../components/ui/EmptyState'

export function RescuerDetailPage() {
  const { id = '' } = useParams()
  const loader = useCallback((signal?: AbortSignal) => getRescuer(id, signal), [id])
  const resource = useAdminData(loader, ['rescuer_profiles', 'rescuer_online_status', 'rescuer_vehicles', 'rescuer_service_capabilities', 'rescue_request_assignments', 'customer_request_reviews'])
  const action = useAdminAction(resource.reload)
  const row = resource.data
  return <><PageHeader eyebrow="ĐỐI TÁC CỨU HỘ / HỒ SƠ" title={row ? textValue(row.full_name) : 'Hồ sơ đối tác'} description={row ? codeValue(row.rescuer_code) : undefined} actions={<><ReloadButton resource={resource}/><Link className="button button-white" to="/rescuers">Danh sách đối tác</Link></>}/>{action.notice}
    <DataState resource={resource}>{!row ? <EmptyState title="Không tìm thấy đối tác cứu hộ" description="Đối tác không tồn tại hoặc bạn chưa có quyền xem."/> : <div className="detail-grid">
      <div><SectionCard title="Hồ sơ đối tác"><KeyValues items={[[ 'Họ tên', textValue(row.full_name)], ['Email', textValue(row.email)], ['Điện thoại', textValue(row.phone)], ['Ngày tạo', dateValue(row.created_at)], ['Số xe', countValue(row.vehicle_count)], ['Số dịch vụ', countValue(row.service_count)], ['Ca hoàn tất', countValue(row.completed_jobs)], ['Đánh giá trung bình', countValue(row.average_rating) + ' / 5']]}/></SectionCard>
        <SectionCard title="Giấy tờ"><EmptyState title="Chưa kết nối dữ liệu giấy tờ" description="Tải và xem tài liệu đối tác chưa được hỗ trợ."/></SectionCard>
        <SectionCard title="Phương tiện & Dịch vụ"><EmptyState title="Chưa có dữ liệu chi tiết" description="Danh sách phương tiện và dịch vụ của đối tác chưa được kết nối."/></SectionCard></div>
      <SectionCard title="Kiểm duyệt & Điều hành"><KeyValues items={[[ 'Trạng thái hồ sơ', statusValue(row.approval_status)], ['Kết nối', row.online_status ? 'Trực tuyến' : 'Ngoại tuyến'], ['Sẵn sàng nhận đơn', row.is_available ? 'Có' : 'Không'], ['Hoạt động gần nhất', dateValue(row.last_seen_at)]]}/><RescuerActions rescuer={row} open={action.open}/></SectionCard>
    </div>}</DataState>{action.dialog}</>
}
