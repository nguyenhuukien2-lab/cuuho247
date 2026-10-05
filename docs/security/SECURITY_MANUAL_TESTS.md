# Ca kiểm thử bảo mật thủ công

> Chạy trên staging với tài khoản giả trong [kế hoạch](SECURITY_TEST_PLAN.md). Dùng app hoặc client REST/RPC/Storage/Realtime với **JWT người dùng thật** và anon/publishable key; không dùng `service_role`. Mỗi ca phải xác nhận bản ghi đích tồn tại, ghi kết quả đã che PII, và thử API trực tiếp bên cạnh UI. Ký hiệu: CA/CB = hai khách, RA/RB = hai đối tác.

| ID | Cách thực hiện | Kỳ vọng / bằng chứng |
|---|---|---|
| AUTH-01 | Mở deep link đơn/admin khi chưa login; gọi REST/RPC không bearer token | Không có bản ghi bảo vệ; route chuyển login. |
| AUTH-02 | Đăng nhập rồi logout; mở lại trang/tab, thử RPC và Realtime cũ | Phiên không còn dùng được; channel đóng; không có dữ liệu mới. |
| AUTH-03 | Admin active đang mở dashboard, chuyển status thành blocked bằng fixture/quy trình test; reload, refresh token và reconnect | View/RPC từ chối, route chặn. Không tự chỉnh trực tiếp production. |
| CUS-01 | CA mở profile mình; qua REST đổi filter sang `user_id` của CB, thử không filter | CA thấy đúng mình; CB không hiện. |
| CUS-02 | CA lấy UUID xe và địa chỉ của CB qua REST SELECT, rồi thử UPDATE/DELETE trong **staging có rollback/hậu kiểm** | Đọc chéo `0 row`; mutation bị chặn, dữ liệu CB giữ nguyên. |
| CUS-03 | CA mở lịch sử/chi tiết đơn của CB bằng UUID/deep link; gọi REST `rescue_requests`, `request_status_events`, `rescue_request_photos`, `customer_request_reviews` không filter | Không thấy đơn, vị trí, ảnh, review hoặc mã hiển thị của CB. CA vẫn xem được đơn mình. |
| CUS-04 | CA gọi `cancel_own_rescue_request` với UUID đơn CB, sau đó thử đơn completed | Bị chặn; trạng thái và số event không đổi. Chỉ dùng fixture và hậu kiểm. |
| CUS-05 | CA gửi review cho đơn CB và cho đơn chưa completed | Bị chặn; không có review giả. Chạy trên staging riêng nếu bật mutation. |
| PRE-01 | RA approved/online chưa nhận đơn CB; gọi `rescuer_list_available_requests` và `rescuer_get_available_request` bằng UUID đơn | Chỉ trường tối thiểu; kiểm tra response thô không chứa SĐT, email, địa chỉ/GPS chính xác, ảnh hay signed URL. Đừng chỉ nhìn màn hình. |
| PRE-02 | RA thử REST `rescue_requests` và Storage ảnh CB trước claim | Không lấy được hàng/ảnh chi tiết; UI không phải bằng chứng duy nhất. |
| PRE-03 | RA đã claim đơn giả; RB chưa claim thử chi tiết và cập nhật trạng thái/báo giá của RA | RB bị chặn; RA chỉ thấy đúng đơn được giao. Claim/quote chỉ chạy trong fixture riêng. |
| PRE-04 | Rescuer pending/suspended thử online, discovery, claim; rescuer đang bận thử claim đồng thời | Bị chặn theo trạng thái/công suất; một đơn chỉ có một assignment hiệu lực. |
| ADM-01 | CA hoặc RA gọi `is_admin()`, `admin_get_dashboard_stats`, từng admin view và RPC mutation với UUID fixture hợp lệ | `is_admin=false`; view rỗng hoặc bị từ chối; RPC mutation bị từ chối trước khi ghi, không phải lỗi do UUID không tồn tại. Chỉ dùng fixture staging. |
| ADM-02 | FI gọi dashboard, `admin_quotes_view`, rồi `admin_approve_rescuer` | Quote/doanh thu có quyền; approve bị từ chối; audit không có quyết định duyệt giả. |
| ADM-03 | OP gọi dashboard, `admin_quotes_view`, `admin_block_rescuer`/`admin_cancel_request` | `revenue_visible=false`, quote view không lộ; block/cancel chỉ thành công với fixture hợp lệ và ghi audit. |
| ADM-04 | SU đọc view khách/đơn, gọi `admin_cancel_request`, `admin_approve_rescuer` | Xem theo quyền hỗ trợ; hai mutation bị chặn. |
| ADM-05 | PR đọc `admin_rescuers_view`, `admin_rescuer_documents_view`, gọi `admin_approve_rescuer`; thử `admin_quotes_view`/cancel | Đọc metadata/duyệt theo quyền; không xem quote hay hủy đơn; file giấy tờ chưa mặc định tải được. |
| ADM-06 | FI/OP/SU/PR gọi INSERT/UPDATE/DELETE trực tiếp `admin_audit_logs`; thử admin blocked | Không ghi/sửa/xóa log; blocked không đọc/ghi qua API. |
| STO-01 | Mở object giả ở `rescue-request-photos` và `rescuer-documents` bằng public URL hoặc không đăng nhập | Không tải được; xác nhận `public=false` trong dashboard/SQL preflight. |
| STO-02 | CA dùng path ảnh CB; RA trước claim dùng path ảnh đơn CB; thử `createSignedUrl`/download | Không cấp/tải được nếu trái quyền. Nếu RA sau claim vẫn không tải được, ghi **BLOCKED — thiếu luồng cấp quyền**, không mở bucket. |
| STO-03 | RA tải giấy tờ RB; PR tải file từ metadata; thử URL ký đã hết hạn | RA bị chặn; PR hiện chỉ có metadata nên file là **BLOCKED** cho đến khi có gateway; URL đã hết hạn thất bại. |
| RT-01 | CA subscribe `rescue_requests` không filter và UUID đơn CB; CB tạo/cập nhật đơn giả | CA không nhận payload CB; ghi payload đã che PII. |
| RT-02 | RA chưa claim nghe bảng/kênh đơn, ảnh, assignment; phát thay đổi đơn CB giả | Không có phone/email/GPS/địa chỉ chi tiết. Nếu bảng chưa trong publication, ghi **N/A**, không gọi là PASS. |
| RT-03 | FI/OP/SU/PR và admin blocked thử kênh admin/quote; đổi role rồi refresh/reconnect | Không nhận dữ liệu ngoài vai trò; blocked không tiếp tục nhận trên phiên mới. |
| RT-04 | Rời trang, logout, đổi tài khoản, mất mạng/reconnect nhiều lần | Channel cleanup, không nhân đôi callback, không crash hoặc giữ dữ liệu account trước. |

## Hậu kiểm mutation

Trước mỗi ca thay đổi dữ liệu, chụp trạng thái/phiên bản/số audit bằng fixture giả; sau test xác nhận đơn, profile, quote và audit đúng kỳ vọng. `ROLLBACK` của SQL Editor **không** hoàn tác lời gọi app/API, upload Storage, push/email hoặc sự kiện đã phát. Với approve/block/cancel/toggle, chuẩn bị cách khôi phục hợp lệ và người chịu trách nhiệm trước khi chạy. Không chạy các ca này trên dữ liệu thật.
