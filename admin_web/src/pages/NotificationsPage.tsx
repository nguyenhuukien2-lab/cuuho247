import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { EmptyState } from '../components/ui/EmptyState'
import { UnsupportedButton } from '../components/ui/AdminData'
export function NotificationsPage() {
  return <><PageHeader title="Thông báo" description="Trung tâm thông báo điều hành." actions={<UnsupportedButton>Đánh dấu đã đọc</UnsupportedButton>}/>
    <div className="settings-grid"><SectionCard title="Trung tâm thông báo"><EmptyState title="Chưa kết nối dữ liệu thông báo" description="Thông báo sẽ hiển thị khi nguồn dữ liệu được kết nối."/></SectionCard>
      <SectionCard title="Gửi thông báo" subtitle="Chưa hỗ trợ gửi thật"><div className="broadcast"><label>Tiêu đề<input disabled placeholder="Chưa hỗ trợ"/></label><label>Nội dung<textarea disabled placeholder="Chưa hỗ trợ"/></label><div className="button-pair"><UnsupportedButton>Gửi thông báo</UnsupportedButton><UnsupportedButton>Hẹn giờ</UnsupportedButton></div></div></SectionCard></div></>
}
