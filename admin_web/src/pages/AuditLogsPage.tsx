import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { EmptyState } from '../components/ui/EmptyState'
export function AuditLogsPage() {
  return <><PageHeader title="Nhật ký quản trị" description="Theo dõi thao tác điều hành trên hệ thống."/><SectionCard title="Lịch sử thao tác"><EmptyState title="Chưa kết nối nhật ký quản trị" description="Danh sách lịch sử sẽ hiển thị khi nguồn dữ liệu được kết nối."/></SectionCard></>
}
