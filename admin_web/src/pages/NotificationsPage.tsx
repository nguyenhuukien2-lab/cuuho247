import { useState } from 'react'
import { Bell, CheckCheck } from 'lucide-react'
import { notifications } from '../mocks/mockData'
import { PageHeader } from '../components/ui/PageHeader'
import { SectionCard } from '../components/ui/SectionCard'
import { StatusBadge } from '../components/ui/StatusBadge'
export function NotificationsPage() {
  const [read, setRead] = useState<string[]>([])
  return <><PageHeader title="Thông báo" description="Dòng sự kiện và cảnh báo mới nhất từ trung tâm điều hành." actions={<button className="button button-white" onClick={() => setRead(notifications.map((item) => item.title))}><CheckCheck size={15}/> Đánh dấu tất cả đã đọc</button>}/><SectionCard title="Trung tâm thông báo" subtitle="Những sự kiện cần theo dõi"><div className="notification-page-list">{notifications.map((item) => <button key={item.title} className={read.includes(item.title) ? 'read' : ''} onClick={() => setRead([...read, item.title])}><span className="icon-box blue"><Bell size={17}/></span><span><b>{item.title}</b><small>{item.description}</small></span><StatusBadge>{item.type}</StatusBadge><em>{item.time}</em></button>)}</div></SectionCard></>
}
