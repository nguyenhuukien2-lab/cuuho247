# Rà soát Supabase Realtime

> Subscription ở client không phải ranh giới bảo mật. Phải kiểm thử JWT và quyền đọc hàng của người nhận trên Supabase đã triển khai; rà soát tĩnh không chứng minh được cấu hình publication/runtime.

## 1. Hiện trạng quan sát được

- Migration customer tracking thêm `rescue_requests` vào publication `supabase_realtime`. Chưa thấy migration tương ứng cho các bảng khác trong danh sách dưới đây; cần kiểm tra publication của môi trường thật.
- Customer app đăng ký `postgres_changes` cho `rescue_requests` với filter UUID đơn, kiểm tra lại `customer_id`/session và tải snapshot; có xử lý hủy subscription.
- Admin Web dùng hook `useAdminData.ts` đăng ký thay đổi của một số bảng và polling định kỳ; hook có cleanup. Cần test xem subscription của admin bị đổi role/blocked được thu hồi thế nào.
- Trong rescuer app đã rà soát không thấy subscription Realtime cho các bảng đơn; luồng đối tác hiện thiên về RPC/tải lại. Không coi các kịch bản Realtime của đối tác là chức năng đã có.

## 2. Ma trận bảng cần xác minh

| Bảng | Dữ liệu nhạy cảm | Quyền sự kiện mong muốn | Việc xác minh |
|---|---|---|---|
| `rescue_requests` | Vị trí, địa chỉ, liên kết khách/đối tác, trạng thái | Khách chủ đơn; đối tác chỉ theo quyền đã nhận/phiên khám phá tối thiểu; admin active có role | Kiểm tra publication, RLS SELECT, payload old/new và JWT A/B. Không phát toàn row chứa PII cho đối tác chưa nhận. |
| `request_status_events` | Lịch sử di chuyển/trạng thái | Bên thuộc đơn, admin phù hợp | Kiểm tra có thực sự trong publication; filter UUID và RLS. |
| `rescue_request_assignments` | Liên kết đối tác/đơn | Đối tác được giao, chủ đơn theo dữ liệu cần thiết, admin | Migration nền tảng không cấp đọc trực tiếp phổ quát; kiểm tra thiết kế trước khi bật publication. |
| `rescuer_online_status` | Tình trạng trực tuyến | Chính đối tác; admin điều phối có quyền | Tránh kênh công khai toàn bộ vị trí/trạng thái đối tác. |
| `rescue_quotes` | Giá và khoản phí | Chủ đơn/đối tác được giao theo RPC, finance/super_admin theo quyền | Không phát báo giá/doanh thu cho role khác. |
| `customer_request_reviews` | Đánh giá, nhận xét | Chủ đơn; admin được phép | Kiểm tra publication và policy trước khi đăng ký client. |

## 3. Rủi ro và biện pháp

- Filter ở client có thể bị sửa. Chỉ RLS/RPC/view phía server mới ngăn Customer A hoặc đối tác lạ lấy sự kiện của B.
- `rescue_requests` có trường nhạy cảm; ngay cả sự kiện UPDATE để báo “có thay đổi” vẫn phải được kiểm tra payload thực tế. Nếu cần thông báo đơn chờ nhận cho nhiều đối tác, nên dùng projection/broadcast tối thiểu với quyền riêng thay vì đưa toàn bộ hàng.
- Với JWT đã phát hành, quyền bị khóa/đổi role có thể không mất ngay trên connection cũ. Xác minh hành vi refresh/reconnect, chính sách TTL và đóng kênh khi sign-out hoặc lỗi quyền.
- Xóa subscription khi rời màn hình, logout, đổi tài khoản; không để callback giữ dữ liệu sau đổi user. Lỗi mạng/Realtime không làm crash app; đồng bộ lại bằng RPC/snapshot khi kết nối phục hồi.

## 4. Checklist kiểm thử trên môi trường staging

- [ ] Liệt kê publication thực tế và đối chiếu các bảng trên; không bật bảng chỉ để “cho đủ”.
- [ ] Customer A subscribe UUID đơn B và subscription không filter: không nhận dữ liệu B.
- [ ] Đối tác chưa nhận đơn không nhận số điện thoại, email, địa chỉ/GPS chính xác từ event; thử cả INSERT/UPDATE/DELETE và old row.
- [ ] Đối tác A sau nhận chỉ thấy sự kiện đơn A; sau bị đình chỉ/thu hồi assignment không nhận thêm payload nhạy cảm sau reconnect.
- [ ] Admin active từng role chỉ nhận dữ liệu theo quyền; admin blocked hoặc demoted không tiếp tục nhận trên phiên mới/refresh.
- [ ] Rời trang/logout hủy channel; reconnect không tạo nhiều subscription; mất mạng không crash và tải lại trạng thái chuẩn.
- [ ] Không có event báo giá/doanh thu gửi cho support/operator/partner_reviewer nếu không được phép.

## Việc cần triển khai sau

Viết test tích hợp với JWT của hai khách, hai đối tác và từng role admin; ghi rõ publication/payload được phép; chỉ bổ sung kênh đối tác khi đã có projection tối thiểu và policy được kiểm thử. Chưa thay đổi Realtime trong giai đoạn này.
