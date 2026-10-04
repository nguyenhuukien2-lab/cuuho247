export type Tone = 'blue' | 'green' | 'orange' | 'red' | 'slate'
export type RequestStatus = 'Đang xử lý' | 'Hoàn tất' | 'Chờ điều phối' | 'Đã hủy'
export const dashboardStats = [
  { label: 'Tổng khách hàng', value: '12,480', note: '+12.5% so với tháng trước', tone: 'blue' as Tone, icon: 'users' },
  { label: 'Tổng đối tác', value: '284', note: 'Đối tác mới tuần này', tone: 'orange' as Tone, icon: 'shield' },
  { label: 'Đơn hôm nay', value: '86', note: '+18% hôm qua', tone: 'blue' as Tone, icon: 'clipboard' },
  { label: 'Đơn đang xử lý', value: '14', note: 'Thời gian xử lý 6.2 phút', tone: 'blue' as Tone, icon: 'clock' },
  { label: 'Đơn hoàn tất', value: '68', note: 'Tỷ lệ hoàn thành 94.2%', tone: 'blue' as Tone, icon: 'check' },
  { label: 'Đơn đã hủy', value: '4', note: '4.6% mức thấp', tone: 'red' as Tone, icon: 'x' },
  { label: 'Doanh thu tạm tính', value: '48,250,000₫', note: '+34.6% tuần này', tone: 'blue' as Tone, icon: 'wallet' },
  { label: 'Đối tác online', value: '142', note: 'Chiếm 68% lực lượng', tone: 'orange' as Tone, icon: 'truck' },
]
export const chartData = [
  { day: 'Thứ 2', orders: 48, revenue: 24 }, { day: 'Thứ 3', orders: 54, revenue: 31 },
  { day: 'Thứ 4', orders: 63, revenue: 39 }, { day: 'Thứ 5', orders: 68, revenue: 36 },
  { day: 'Thứ 6', orders: 75, revenue: 43 }, { day: 'Thứ 7', orders: 72, revenue: 48 },
  { day: 'Chủ nhật', orders: 70, revenue: 34 },
]
export const statusDistribution = [
  { name: 'Hoàn tất', value: 78, color: '#1155d9' },
  { name: 'Đang xử lý', value: 12, color: '#75a0f1' },
  { name: 'Đang di chuyển', value: 6, color: '#fb8a58' },
  { name: 'Đã hủy', value: 4, color: '#e74646' },
]
export const rescueRequests: { id: string; customer: string; phone: string; vehicle: string; plate: string; incident: string; location: string; service: string; team: string; status: RequestStatus; time: string; amount: number }[] = [
  { id: 'CH-0086', customer: 'Lê Hoàng Long', phone: '0905 123 456', vehicle: 'Hyundai Creta', plate: '43A-582.19', incident: 'Xe không đề nổ, nghi hỏng ắc quy', location: 'Cầu Rồng, Đà Nẵng', service: 'Kích bình ắc quy', team: 'Cứu Hộ Hải Châu 01', status: 'Đang xử lý', time: '14:28', amount: 900000 },
  { id: 'CH-0085', customer: 'Trần Minh Tuấn', phone: '0988 776 211', vehicle: 'Toyota Vios', plate: '43C-492.90', incident: 'Xẹp lốp trên đường Võ Nguyên Giáp', location: 'Sơn Trà, Đà Nẵng', service: 'Vá lốp lưu động', team: 'Cứu Hộ Sơn Trà 24/7', status: 'Hoàn tất', time: '14:12', amount: 450000 },
  { id: 'CH-0084', customer: 'Nguyễn Thị Mai', phone: '0912 345 678', vehicle: 'Mazda CX-5', plate: '43A-862.27', incident: 'Xe chết máy khi đang di chuyển', location: 'Ngũ Hành Sơn, Đà Nẵng', service: 'Cẩu & kéo xe', team: 'Cứu Hộ Liên Chiểu Express', status: 'Chờ điều phối', time: '13:56', amount: 1250000 },
  { id: 'CH-0083', customer: 'Vũ Đình Trọng', phone: '0971 889 900', vehicle: 'Ford Ranger', plate: '43H-271.05', incident: 'Hết nhiên liệu trên đường tránh', location: 'Hải Châu, Đà Nẵng', service: 'Tiếp nhiên liệu', team: 'Garage Hòa Khánh Auto', status: 'Hoàn tất', time: '13:35', amount: 320000 },
  { id: 'CH-0082', customer: 'Phan Quốc Hưng', phone: '0934 122 334', vehicle: 'Honda City', plate: '43A-851.91', incident: 'Khóa cửa xe, chìa khóa bên trong', location: 'Thanh Khê, Đà Nẵng', service: 'Mở khóa ô tô', team: 'Cứu Hộ Hải Châu 01', status: 'Đã hủy', time: '12:41', amount: 0 },
]
export const activityFeed = [
  { title: 'Đơn khẩn cấp mới', detail: 'Khách báo xe không đề nổ tại khu vực Cầu Rồng', time: 'Vừa xong', tone: 'orange' as Tone },
  { title: 'Xe cứu hộ đã xuất phát', detail: 'Tổ Hải Châu 01 đang di chuyển đến hiện trường', time: '2 phút trước', tone: 'blue' as Tone },
  { title: 'Báo giá đã được duyệt', detail: 'Khách hàng xác nhận báo giá 900.000₫', time: '16 phút trước', tone: 'green' as Tone },
  { title: 'Đánh giá 5 sao', detail: 'Trần Minh Tuấn gửi lời cảm ơn đội Sơn Trà', time: '20 phút trước', tone: 'slate' as Tone },
]
export const customers = [
  { id: 'KH-00021', name: 'Lê Hoàng Long', phone: '0905 123 456', email: 'long.le@danang.vn', tier: 'Hội viên Vàng', vehicle: 'Hyundai Creta · 43A-582.19', orders: 14, spent: 14520000, status: 'Hoạt động' },
  { id: 'KH-00019', name: 'Trần Minh Tuấn', phone: '0988 776 211', email: 'minhtuan.tran@gmail.com', tier: 'Hội viên', vehicle: 'Toyota Vios · 43C-492.90', orders: 8, spent: 4800000, status: 'Hoạt động' },
  { id: 'KH-00018', name: 'Nguyễn Thị Mai', phone: '0912 345 678', email: 'mai.nguyen@gmail.com', tier: 'Hội viên Vàng', vehicle: 'Mazda CX-5 · 43A-862.27', orders: 22, spent: 28990000, status: 'Hoạt động' },
  { id: 'KH-00017', name: 'Vũ Đình Trọng', phone: '0971 889 900', email: 'trong.vu@logistics.com', tier: 'Thành viên', vehicle: 'Ford Ranger · 43H-271.05', orders: 11, spent: 11600000, status: 'Hoạt động' },
  { id: 'KH-00016', name: 'Phan Quốc Hưng', phone: '0934 122 334', email: 'hung.pq@outlook.com', tier: 'Hội viên', vehicle: 'Honda City · 43A-851.91', orders: 1, spent: 0, status: 'Khóa' },
]
export const rescuers = [
  { id: 'RC-001', name: 'Cứu Hộ Hải Châu 01', area: 'Hải Châu, Đà Nẵng', person: 'Trần Minh Hoàng', phone: '0905 123 456', status: 'Đang trực tuyến', service: 'Cẩu kéo · Kích bình · Vá lốp', vehicle: 'Hyundai Mighty EX8', jobs: 48, rating: 4.9, approval: 'Đã duyệt' },
  { id: 'RC-002', name: 'Cứu Hộ Sơn Trà 24/7', area: 'Sơn Trà, Đà Nẵng', person: 'Nguyễn Văn Bình', phone: '0955 888 999', status: 'Đang trực tuyến', service: 'Cẩu kéo · Thay lốp', vehicle: 'Hino 500 Series', jobs: 36, rating: 4.8, approval: 'Đã duyệt' },
  { id: 'RC-003', name: 'Cứu Hộ Liên Chiểu Express', area: 'Liên Chiểu, Đà Nẵng', person: 'Lê Quang Vỹ', phone: '0903 778 882', status: 'Ngoại tuyến', service: 'Kích bình · Cẩu kéo', vehicle: 'Isuzu QKR 270', jobs: 28, rating: 4.7, approval: 'Đã duyệt' },
  { id: 'RC-004', name: 'Garage Hòa Khánh Auto', area: 'Liên Chiểu, Đà Nẵng', person: 'Đặng Công Tuấn', phone: '0905 442 110', status: 'Chưa hoạt động', service: 'Mở khóa · Sửa tại chỗ', vehicle: 'HOWO 5 tấn', jobs: 0, rating: 0, approval: 'Chờ duyệt' },
  { id: 'RC-005', name: 'Cứu Hộ Cẩm Lệ Pro', area: 'Cẩm Lệ, Đà Nẵng', person: 'Huỳnh Bá Cường', phone: '0914 777 123', status: 'Đang trực tuyến', service: 'Cẩu kéo · Vá lốp', vehicle: 'Kia K250', jobs: 24, rating: 4.9, approval: 'Đã duyệt' },
]
export const services = [
  { id: 'SRV-TR-01', name: 'Cẩu & Kéo Xe Ô Tô', description: 'Ứng cứu xe gặp sự cố, đưa xe tới gara an toàn với đội xe chuyên dụng.', price: 500000, unit: 'ca', equipment: 'Xe cứu hộ sàn trượt, dây kéo', jobs: 5420, rating: 5.0, icon: 'truck' },
  { id: 'SRV-BT-02', name: 'Kích Bình Ắc Quy & Sạc 12V/24V', description: 'Cứu hộ không khởi động được xe, kiểm tra bình và hỗ trợ kích điện tại chỗ.', price: 200000, unit: 'lần', equipment: 'Máy kích bình, đồng hồ đo', jobs: 3890, rating: 4.8, icon: 'battery' },
  { id: 'SRV-TR-03', name: 'Vá Vỏ & Thay Lốp Sơ Cua Lưu Động', description: 'Vá lốp, thay lốp dự phòng nhanh chóng tại hiện trường.', price: 250000, unit: 'ca', equipment: 'Bộ tháo lốp, máy nén khí', jobs: 2750, rating: 4.7, icon: 'disc' },
  { id: 'SRV-FL-04', name: 'Tiếp Nhiên Liệu Khẩn Cấp', description: 'Giao nhanh nhiên liệu phù hợp khi xe cạn xăng hoặc dầu trên đường.', price: 150000, unit: 'chuyến', equipment: 'Bình chứa tiêu chuẩn', jobs: 940, rating: 4.9, icon: 'fuel' },
  { id: 'SRV-LK-05', name: 'Mở Khóa Cửa & Cốp Xe Ô Tô', description: 'Mở khóa an toàn, bảo vệ xe và hỗ trợ khi quên chìa khóa.', price: 300000, unit: 'ca', equipment: 'Bộ dụng cụ mở khóa', jobs: 680, rating: 4.9, icon: 'key' },
  { id: 'SRV-RP-06', name: 'Sửa Chữa Khắc Phục Tại Chỗ', description: 'Xử lý sự cố cơ bản tại nơi xe gặp nạn, kiểm tra và tư vấn phương án.', price: 250000, unit: 'ca', equipment: 'Bộ dụng cụ đa năng', jobs: 1200, rating: 4.7, icon: 'wrench' },
]
export const quotes = [
  { id: 'BG-2024-0081', customer: 'Lê Hoàng Long', team: 'Cứu Hộ Hải Châu 01', item: 'Cước kéo xe 450.000₫ · Kích bình 250.000₫ · Phí đêm 200.000₫', total: 900000, method: 'VNPay / QR', status: 'Đã thanh toán' },
  { id: 'BG-2024-0080', customer: 'Trần Minh Tuấn', team: 'Cứu Hộ Sơn Trà 24/7', item: 'Kích ắc quy 300.000₫ · Công thợ 150.000₫', total: 450000, method: 'Tiền mặt', status: 'Đã thanh toán' },
  { id: 'BG-2024-0079', customer: 'Nguyễn Thị Mai', team: 'Cứu Hộ Liên Chiểu Express', item: 'Vá lốp & thay bánh sơ cua 350.000₫', total: 350000, method: 'Ví MoMo', status: 'Đã thanh toán' },
  { id: 'BG-2024-0078', customer: 'Phan Quốc Hưng', team: 'Garage Hòa Khánh Auto', item: 'Cẩu xe tai nạn 1.500.000₫ · Phụ phí 600.000₫', total: 2100000, method: 'Chuyển khoản', status: 'Chờ khách duyệt' },
]
export const reviews = [
  { id: 'CH-0086', name: 'Lê Hoàng Long', rating: 5, text: 'Đội cứu hộ đến rất nhanh giữa lúc kẹt xe Cầu Rồng, tài xế vui vẻ và tận tình. Kịp thời, không làm dây bẩn xe. Rất an tâm!', service: 'Cẩu & kéo xe', team: 'Cứu Hộ Hải Châu 01', status: 'Đã phản hồi' },
  { id: 'CH-0085', name: 'Trần Minh Tuấn', rating: 5, text: 'Xe em trên đèo Gia Vị nên đêm rất may có các bác tới tận nơi khi trời 24h nhanh chóng, giá đúng niêm yết không chặt chém.', service: 'Vá lốp', team: 'Cứu Hộ Sơn Trà 24/7', status: 'Đã phản hồi' },
  { id: 'CH-0082', name: 'Phan Quốc Hưng', rating: 2, text: 'Thời gian điều phối xe cứu hộ đến hiện trường khá lâu (gần 40 phút), hy vọng trung tâm bổ sung thêm xe trực ở khu công nghiệp.', service: 'Mở khóa xe', team: 'Garage Hòa Khánh Auto', status: 'Đang xử lý CSKH' },
  { id: 'CH-0084', name: 'Nguyễn Thị Mai', rating: 5, text: 'Kỹ thuật viên và tài xế luôn đúng giờ, chu đáo và sạch sẽ.', service: 'Kích bình', team: 'Cứu Hộ Liên Chiểu Express', status: 'Đã phản hồi' },
]
export const notifications = [
  { title: 'Thông báo cứu hộ khẩn cấp', description: 'Đơn CH-0086 cần điều phối ngay tại Cầu Rồng', time: 'Vừa xong', type: 'Khẩn cấp' },
  { title: 'Nhắc nhở nạp bình ga', description: 'Đội Sơn Trà 24/7 cần kiểm tra thiết bị', time: '12 phút trước', type: 'Hệ thống' },
  { title: 'Cập nhật chính sách giá', description: 'Biểu phí cao điểm mới đã sẵn sàng để duyệt', time: '35 phút trước', type: 'Thông báo' },
]
export const mapHotspots = [
  { name: 'Cầu Rồng & Trần Hưng Đạo', detail: '2 ca đang chờ hỗ trợ', level: 'Rất cao', x: 48, y: 53 },
  { name: 'Đốc điền Hàm Xẻo', detail: '1 ca mới tiếp nhận', level: 'Cảnh báo', x: 67, y: 31 },
  { name: 'Trục QL14B - Cẩm Lệ', detail: '1 sự cố xe tải', level: 'Theo dõi', x: 28, y: 72 },
]
export const onlineTeams = [
  { name: 'Cứu Hộ Hải Châu 01', distance: '1.2 km', vehicle: 'Xe kéo', eta: '4 phút', x: 57, y: 49 },
  { name: 'Cứu Hộ Cẩm Lệ 02', distance: '2.1 km', vehicle: 'Xe cẩu', eta: '7 phút', x: 36, y: 66 },
  { name: 'Cứu Hộ Sơn Trà 03', distance: '3.4 km', vehicle: 'Xe máy', eta: '9 phút', x: 68, y: 64 },
]
export const customerStats = [
  { label: 'Tổng khách hàng', value: '12,480', note: '+12.5% so với tháng trước', icon: 'users' },
  { label: 'Khách hàng đang hoạt động', value: '9,842', note: 'Tỷ lệ tương tác 78.8%', icon: 'check' },
  { label: 'Khách hàng mới tháng này', value: '416', note: '+8% tăng trưởng tuần này', icon: 'clipboard', tone: 'orange' as Tone },
  { label: 'Tổng phương tiện đã lưu', value: '15,230', note: 'Bình quân 1.22 xe/người', icon: 'truck' },
]
export const rescuerStats = [
  { label: 'Tổng đối tác', value: '284', note: '+24 đối tác tháng này', icon: 'shield' },
  { label: 'Đang trực tuyến', value: '142', note: '50% sẵn sàng điều phối', icon: 'truck' },
  { label: 'Hồ sơ chờ duyệt', value: '12', note: '3 yêu cầu từ hôm nay', tone: 'orange' as Tone, icon: 'clipboard' },
  { label: 'Đã phê duyệt', value: '268', note: '84.3% đạt chuẩn chất lượng', icon: 'check' },
  { label: 'Tạm khóa / Cảnh báo', value: '4', note: 'Vi phạm SLA / bị khiếu nại', tone: 'red' as Tone, icon: 'x' },
]
export const serviceStats = [
  { label: 'Tổng dịch vụ hoạt động', value: '6/6', note: '100% khả dụng', icon: 'clipboard' },
  { label: 'Dịch vụ yêu cầu nhiều nhất', value: 'Cẩu & Kéo Xe', note: '42% tổng lưu lượng', icon: 'truck' },
  { label: 'Đơn giá trung bình / ca', value: '650.000₫', note: '+8.4% so với tháng trước', icon: 'wallet' },
  { label: 'Thời gian đáp ứng TB', value: '12.5 phút', note: 'Nhanh hơn cam kết 5.4 phút', tone: 'orange' as Tone, icon: 'clock' },
]
export const quoteStats = [
  { label: 'Tổng doanh thu tạm tính', value: '1,248,500,000₫', note: '+34.2% so với tháng trước', icon: 'wallet' },
  { label: 'Thực thu cứu hộ hôm nay', value: '48,250,000₫', note: '86 ca cứu hộ thành công', icon: 'clipboard' },
  { label: 'Phí chiết khấu đã thu (15%)', value: '187,275,000₫', note: 'Đã nhận đối soát 142 đối tác gara', tone: 'orange' as Tone, icon: 'wallet' },
  { label: 'Báo giá chờ khách xác nhận', value: '12', note: 'Tổng giá trị tạm tính 4,600,000₫', tone: 'red' as Tone, icon: 'clipboard' },
]
export const reviewStats = [
  { label: 'Điểm đánh giá trung bình', value: '4.88 / 5.0', note: 'Quy mô 3,420 lượt đánh giá', icon: 'shield' },
  { label: 'Tỷ lệ hài lòng', value: '92.4%', note: '+3.2% so với tháng trước', icon: 'check' },
  { label: 'Khiếu nại đang cần xử lý', value: '06', note: 'Hạn SLA xử lý: Trong 2h', tone: 'red' as Tone, icon: 'clipboard' },
  { label: 'Tốc độ giải quyết phản hồi', value: '18 phút', note: 'Mục tiêu trung bình 25 phút', tone: 'orange' as Tone, icon: 'clock' },
]
export const requestOverview = [
  { label: 'Tổng yêu cầu', value: '86', note: 'Trong hôm nay', tone: '' },
  { label: 'Đang xử lý', value: '14', note: 'Trung bình 6.2 phút', tone: 'blue' },
  { label: 'Chờ điều phối', value: '4', note: 'Cần xử lý ngay', tone: 'orange' },
  { label: 'Hoàn thành', value: '68', note: 'Tỉ lệ 94.2%', tone: 'green' },
]
export const revenueSources = [
  { name: 'Kéo & Cứu hộ', value: 62, color: '#1155d9' },
  { name: 'Kích bình & sự cố', value: 22, color: '#507df0' },
  { name: 'Vá vỏ lốp', value: 12, color: '#f97316' },
  { name: 'Mở khóa cửa & Khác', value: 4, color: '#94a3b8' },
]
export const serviceRanking = [
  { label: 'Cẩu & kéo xe', value: 42 }, { label: 'Kích bình ắc quy', value: 28 },
  { label: 'Vá vỏ & Thay lốp', value: 18 }, { label: 'Tiếp nhiên liệu', value: 12 },
]
export const ratingDistribution = [{ star: 5, value: 84 }, { star: 4, value: 10 }, { star: 3, value: 4 }, { star: 2, value: 1 }, { star: 1, value: 1 }]
export const operationsStats = [
  { label: 'Trực chiến', value: '142 xe' }, { label: 'Chờ điều phối', value: '04 ca' }, { label: 'ETA phản ứng TB', value: '8.4 phút' },
]
export const systemStats = [
  { label: 'Độ trễ GPS Gateway', value: '18ms', note: 'Ổn định' },
  { label: 'Tỷ lệ đẩy Push FCM', value: '99.84%', note: 'Đã gửi thành công' },
  { label: 'Bảo mật tài khoản 2FA', value: '12 / 12 User', note: 'Được kích hoạt' },
  { label: 'Tổng đài trực tiếp', value: '08 Ca trực LIVE', note: 'Đang vận hành' },
]
export const settingsDefaults = { scanRadius: 5, driverTimeout: 45, hourlyLimit: 5, backupDispatch: true, nightSurcharge: '+25% Cước sàn', slaTarget: '8.4 phút', brand: 'Cứu Hộ 24/7', hotline: '1900 6868', email: 'sos@cuuho247.vn', radioChannel: 'Kênh 01 Vùng 1' }
export const incidentTimeline = [
  { name: 'Đã tiếp nhận', time: '14:28' }, { name: 'Đang điều phối', time: '14:29' },
  { name: 'Đội cứu hộ phản hồi', time: '14:32' }, { name: 'Đang di chuyển', time: '14:35' },
  { name: 'Dự kiến đến', time: '14:43' },
]


