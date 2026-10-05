import { useCallback } from 'react'
import { Link, useParams } from 'react-router-dom'
import { cancelRequest, getRescueRequest } from '../lib/adminApi'
import { canCancel, codeValue, dateValue, moneyValue, serviceValue, statusValue, textValue } from '../lib/adminFormat'
import { useAdminData } from '../hooks/useAdminData'
import { useAdminAction } from '../hooks/useAdminAction'
import { DataState, KeyValues, ReloadButton, UnsupportedButton } from '../components/ui/AdminData'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { StatusBadge } from '../components/ui/StatusBadge'
import { EmptyState } from '../components/ui/EmptyState'

export function RescueRequestDetailPage() {
  const { id = '' } = useParams()
  const loader = useCallback((signal?: AbortSignal) => getRescueRequest(id, signal), [id])
  const resource = useAdminData(loader, ['rescue_requests', 'rescue_quotes', 'rescue_request_assignments'])
  const action = useAdminAction(resource.reload)
  const row = resource.data
  return <><PageHeader eyebrow="YÊU CẦU CỨU HỘ / CHI TIẾT" title="Chi tiết yêu cầu cứu hộ" description={row ? codeValue(row.request_code) : undefined} actions={<><ReloadButton resource={resource}/><Link className="button button-white" to="/requests">Danh sách yêu cầu</Link></>}/>{action.notice}
    <DataState resource={resource}>{!row ? <EmptyState title="Không tìm thấy yêu cầu cứu hộ" description="Yêu cầu không tồn tại hoặc bạn chưa có quyền xem."/> : <>
      <div className="request-summary"><StatusBadge>{statusValue(row.status)}</StatusBadge><span>Thời gian tạo: {dateValue(row.created_at)}</span></div>
      <div className="detail-grid"><div className="detail-main">
        <SectionCard title="Tiến độ can thiệp trực tiếp"><EmptyState title="Chưa có dữ liệu timeline" description="Lịch sử chi tiết chưa được kết nối."/></SectionCard>
        <SectionCard title="Thông tin sự cố & Hiện trường thực tế"><div className="incident-grid">
          <div className="info-panel"><span className="mini-heading">SỰ CỐ</span><h3>{serviceValue(row.service_type)}</h3><p>{textValue(row.problem_description)}</p></div>
          <div className="info-panel warm"><span className="mini-heading">VỊ TRÍ ĐÓN</span><h3>{textValue(row.pickup_address)}</h3><p>Điểm đến: {textValue(row.destination_address)}</p></div>
          <div className="info-panel cool"><span className="mini-heading">ĐỐI TÁC NHẬN ĐƠN</span><h3>{textValue(row.rescuer_name)}</h3><p>{textValue(row.rescuer_phone)}</p></div>
          <div className="info-panel"><span className="mini-heading">THỜI GIAN</span><p>Tiếp nhận: {dateValue(row.accepted_at)}</p><p>Hoàn tất: {dateValue(row.completed_at)}</p></div>
        </div><EmptyState title="Chưa có ảnh hiện trường" description="Ảnh sự cố chưa được kết nối."/><EmptyState title="Bản đồ đang chờ kết nối dữ liệu GPS thật" description="Địa chỉ đón được hiển thị phía trên."/></SectionCard>
        <SectionCard title="Báo giá dịch vụ & Chi phí cứu hộ"><KeyValues items={[[ 'Dịch vụ', serviceValue(row.service_type)], ['Trạng thái báo giá', statusValue(row.quote_status)]]}/><div className="total-row"><span>Tổng báo giá hiện tại</span><strong>{moneyValue(row.quote_amount)}</strong></div></SectionCard>
      </div><div className="detail-side">
        <SectionCard title="Chủ xe / Khách hàng"><KeyValues items={[[ 'Họ tên', textValue(row.customer_name)], ['Số điện thoại', textValue(row.customer_phone)], ['Email', textValue(row.customer_email)]]}/>{row.customer_id && <Link className="button button-soft full-width" to={'/customers/' + row.customer_id}>Xem khách hàng</Link>}</SectionCard>
        <SectionCard title="Phương tiện gặp nạn"><KeyValues items={[[ 'Tên xe', textValue(row.vehicle_name)], ['Biển số', textValue(row.vehicle_plate)]]}/></SectionCard>
        <SectionCard title="Đối tác cứu hộ tiếp nhận"><KeyValues items={[[ 'Đối tác', textValue(row.rescuer_name)], ['Điện thoại', textValue(row.rescuer_phone)]]}/>{row.rescuer_id && <Link className="button button-soft full-width" to={'/rescuers/' + row.rescuer_id}>Xem đối tác</Link>}</SectionCard>
        <SectionCard title="Thao tác điều hành"><div className="stack-actions"><UnsupportedButton>Điều phối lại</UnsupportedButton><UnsupportedButton>Gửi thông báo</UnsupportedButton><button className="danger" disabled={!canCancel(row.status)} onClick={() => action.open({ title: 'Hủy yêu cầu cứu hộ', description: textValue(row.customer_name) + ' · ' + textValue(row.pickup_address), reason: true, run: (reason) => cancelRequest(row.request_id, reason) })}>Hủy đơn</button></div></SectionCard>
      </div></div>
    </>}</DataState>{action.dialog}</>
}
