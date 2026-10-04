import { Inbox } from 'lucide-react'
export function EmptyState({ title = 'Không tìm thấy dữ liệu', description = 'Hãy thử thay đổi từ khóa hoặc bộ lọc.' }: { title?: string; description?: string }) { return <div className="empty-state"><Inbox size={28}/><strong>{title}</strong><p>{description}</p></div> }
