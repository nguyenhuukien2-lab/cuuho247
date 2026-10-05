import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { EmptyState } from '../components/ui/EmptyState'
import { UnsupportedButton } from '../components/ui/AdminData'
export function OperationsMapPage() {
  return <><PageHeader title="Bản đồ hoạt động" description="Theo dõi vị trí cứu hộ trên toàn mạng lưới." actions={<UnsupportedButton>Điều phối trên bản đồ</UnsupportedButton>}/>
    <div className="map-layout"><SectionCard title="Bản đồ điều hành"><div className="map-unavailable"><EmptyState title="Bản đồ đang chờ kết nối dữ liệu GPS thật" description="Vị trí xe và điểm cứu hộ sẽ hiển thị khi kết nối sẵn sàng."/></div></SectionCard><div className="map-side"><SectionCard title="Yêu cầu gần đây"><EmptyState title="Chưa có dữ liệu vị trí" description="Tra cứu yêu cầu tại trang Yêu cầu cứu hộ."/></SectionCard><SectionCard title="Đối tác gần nhất"><EmptyState title="Chưa có dữ liệu GPS" description="Chưa hỗ trợ xác định đối tác gần nhất."/></SectionCard></div></div></>
}
