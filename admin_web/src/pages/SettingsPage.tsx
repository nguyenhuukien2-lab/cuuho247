import { APP_NAME } from '../lib/constants'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { EmptyState } from '../components/ui/EmptyState'
import { KeyValues, UnsupportedButton } from '../components/ui/AdminData'
export function SettingsPage() {
  return <><PageHeader title="Cài đặt Hệ thống & Phân Quyền" description="Thông tin hệ thống ở chế độ chỉ đọc." actions={<UnsupportedButton>Lưu thay đổi</UnsupportedButton>}/>
    <div className="settings-grid"><div><SectionCard title="Cấu hình điều phối"><EmptyState title="Cài đặt hệ thống sẽ được cấu hình ở giai đoạn sau." description="Chưa có API lưu cài đặt hệ thống trên Admin Web."/></SectionCard><SectionCard title="Thông tin ứng dụng"><KeyValues items={[[ 'Tên ứng dụng', APP_NAME], ['Khu vực quản trị', 'Admin Web']]}/></SectionCard></div>
      <div><SectionCard title="Thông báo đẩy"><EmptyState title="Chưa hỗ trợ gửi thật" description="Gửi và hẹn giờ thông báo chưa được kết nối."/></SectionCard><SectionCard title="Phân quyền tài khoản"><EmptyState title="Chưa hỗ trợ quản lý phân quyền" description="Quyền thao tác hiện được kiểm tra bởi hệ thống khi thực hiện yêu cầu."/></SectionCard></div></div></>
}
