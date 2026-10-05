# Rà soát bảo mật Admin Web và Admin BE

> Nguồn: `admin_web/src` và migration admin trong `admin_web/backend/supabase/migrations`. Chỉ mô tả điều quan sát được trong mã nguồn; cần kiểm thử trên database triển khai.

## 1. Đăng nhập và AdminRoute

- Admin Web dùng Supabase Auth email/password qua anon key. `LoginPage` và `AdminRoute` kiểm tra phiên rồi gọi `is_admin()`; người không phải admin bị sign out. Route có trạng thái loading/error. `is_admin()` trong migration chỉ công nhận `admin_profiles.status='active'`.
- Kiểm tra route là lớp trải nghiệm người dùng, không thay cho quyền ở view/RPC. Sau khi tài khoản bị khóa/đổi vai trò, mọi RPC và view phải tự kiểm tra lại. Cần test refresh token, tab đang mở và kết nối Realtime cũ.
- Không lưu password/token trong log hoặc telemetry; tránh thêm lưu session thủ công ngoài cơ chế SDK. Xác minh logout thật sự xóa phiên trên trình duyệt.

## 2. Quyền dữ liệu hiện có

| Tài nguyên | Vai trò được cấp trong migration | Điểm cần thử |
|---|---|---|
| `admin_customers_view`, `admin_rescue_requests_view`, `admin_reviews_view` | `super_admin`, `operator`, `support` | Truy cập bằng REST trực tiếp với finance/reviewer phải bị chặn. |
| `admin_rescuers_view` | `super_admin`, `operator`, `partner_reviewer` | Không lộ thông tin đối tác cho role khác. |
| `admin_rescuer_documents_view` | `super_admin`, `partner_reviewer` | View chỉ là metadata; không tự cho phép tải file Storage. |
| `admin_quotes_view` | `super_admin`, `finance` | Không thấy giá/doanh thu qua view khác, RPC hoặc Realtime. |
| `admin_services_view` | Mọi admin active | Chỉ `super_admin`/`operator` được thay đổi qua RPC. |
| `admin_get_dashboard_stats` | Mọi admin active | Chỉ `super_admin`/`finance` thấy `today_revenue`; vai trò khác có `revenue_visible=false`. |

Các RPC thay đổi dữ liệu: duyệt/từ chối đối tác cho `super_admin`/`partner_reviewer`; khóa đối tác, hủy đơn, bật/tắt dịch vụ cho `super_admin`/`operator`. Xem [rà soát RPC](SECURITY_RPC_REVIEW.md) để thử đầu vào và trạng thái.

## 3. Admin profile và tự khóa

Migration giới hạn quyền sửa admin profile cho super_admin và có kiểm tra chống tự thay đổi gây mất quyền. Cần test thêm: super_admin tự khóa mình, hạ cấp chính mình, khóa super_admin cuối cùng, actor đã bị blocked gọi RPC bằng phiên cũ. Nếu quy tắc “super admin cuối cùng” chưa có thì đưa vào backlog, không giả định đã bảo vệ.

## 4. Audit log

- `admin_audit_logs` không cho client tự INSERT/UPDATE/DELETE trực tiếp theo policy/grant đã rà soát; thao tác admin ghi log phía BE. Cần kiểm tra tính nguyên tử: mutation thành công thì có log, mutation thất bại không có log sai.
- RLS hiện cho mọi admin active đọc audit log. Cần quyết định có giới hạn theo vai trò hoặc che metadata nhạy cảm không. Hiện `AuditLogsPage.tsx` là giao diện chưa nối dữ liệu audit; việc BE có log không đồng nghĩa admin tra cứu được trong UI.
- Ghi actor UUID, target, action, reason, timestamp, kết quả; tránh ghi token, password, signed URL, số điện thoại đầy đủ hoặc giấy tờ vào payload log. Định nghĩa thời gian lưu/kiểm soát truy cập log.

## 5. Thông báo và UI

BE có đường gửi thông báo admin cho `super_admin`/`operator`/`support`, nhưng `NotificationsPage.tsx` đang ở trạng thái chưa kết nối. Khi bật UI, kiểm tra người nhận/role và nội dung không lộ dữ liệu của khách khác.

Admin Web cần kiểm tra XSS ở nội dung tự do (tên, lý do, nhận xét), chính sách CSP và security headers khi deploy, dependency audit, cache trình duyệt cho trang nhạy cảm, cùng việc không đưa dữ liệu cá nhân/quote vào URL. React escape mặc định là lợi thế, nhưng không chứng minh an toàn nếu có HTML injection hoặc thư viện render tùy biến; kiểm tra mã trước phát hành.

## 6. Checklist chấp nhận

- [ ] User thường đăng nhập vẫn không truy cập route, view hoặc RPC admin bằng REST trực tiếp.
- [ ] Admin blocked không vào dashboard sau tải lại và không gọi được RPC/view với token mới; xác minh phiên cũ.
- [ ] Finance không duyệt đối tác; support không hủy đơn; reviewer không xem báo giá; operator không thấy doanh thu.
- [ ] Mọi quyết định từ chối/khóa/hủy có reason và đúng audit log; client không thể giả/chỉnh/xóa log.
- [ ] Super_admin không tự khóa; xác minh trường hợp admin cuối cùng.
- [ ] Giấy tờ chỉ xem theo quyền sau khi có luồng Storage, không dùng public URL.
- [ ] Thử XSS bằng chuỗi HTML trong các trường tự do; kiểm tra CSP/headers và token không xuất hiện trong log/browser analytics.

## Đề xuất sau rà soát

Nối giao diện audit với view/RPC giới hạn role; thiết kế quyền tải giấy tờ; test tự động ma trận vai trò trên môi trường staging; chuẩn hóa CSP và bộ header khi deploy. Chưa sửa Admin Web hoặc migration.
