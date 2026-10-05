export function StatusBadge({ children, tone }: { children: React.ReactNode; tone?: 'blue' | 'green' | 'orange' | 'red' | 'slate' }) {
  const label = String(children)
  const resolved = tone ?? (/Hoàn tất|Đã thanh toán|Đã duyệt|Hoạt động|Đã phản hồi|Đang trực tuyến/i.test(label) ? 'green' : /Chờ|Đang xử lý|Đang di chuyển/i.test(label) ? 'blue' : /Hủy|Khóa|Từ chối|Khẩn cấp|Cảnh báo/i.test(label) ? 'red' : 'orange')
  return <span className={'status-badge ' + resolved}><span className="status-dot" />{children}</span>
}
