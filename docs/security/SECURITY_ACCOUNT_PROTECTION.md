# Bảo vệ tài khoản và phiên đăng nhập

## 1. Tài khoản khách hàng

**Đã thấy trong mã:** `customer_profiles`, xe, địa chỉ, đơn và ảnh dùng owner `auth.uid()`; tạo đơn qua RPC, có idempotency key và một đơn active/khách. Khách có thể cập nhật profile/xe/địa chỉ của mình theo RLS. `customer_profiles` hiện **không có** `account_status`; không thể ghi rằng “blocked customer bị từ chối tạo đơn”.

**Cần kiểm thử:** JWT A đọc/sửa ID B; giả `customer_id`; phiên hết hạn; một người tạo nhiều đơn liên tục sau khi hủy; retry cùng khóa và khóa khác. **Đề xuất sau:** migration mới thêm trạng thái `active/blocked/pending/deleted` nếu nghiệp vụ thống nhất; kiểm tra ở RPC tạo đơn và các thao tác cần khóa. “Deleted” cần thiết kế retention/ẩn danh, không chỉ là nhãn.

## 2. Tài khoản đối tác

**Đã thấy:** profile duyệt `draft/submitted/approved/rejected/suspended`; RPC nhận đơn yêu cầu approved, xe/capability phù hợp, online/vị trí còn hiệu lực, không bận. `admin_block_rescuer` đổi suspended, tắt online và không khóa đối tác đang có job để tránh bỏ dở ca. Đối tác không có grant trực tiếp để tự ghi `verification_status`.

**Cần kiểm thử:** revoked/suspended trong khi giữ token cũ; thiết bị thứ hai; lost reply; tranh claim; profile `rejected`/xe hết duyệt; session_id cũ cập nhật GPS. Cơ chế ngừng job đang chạy khi cần khóa khẩn cấp cần quy trình điều phối riêng.

## 3. Tài khoản Admin

`is_admin()` chỉ đúng nếu có `admin_profiles.status='active'`; `has_admin_role()` kiểm tra role. `AdminRoute` và LoginPage sign out người không có quyền; `private.admin_require_role()` chặn RPC. Guard ngăn super_admin tự đổi role/status của mình. Các thao tác hồ sơ Admin và RPC quan trọng có trigger/audit; xem [Admin review](SECURITY_ADMIN_REVIEW.md).

**Cần kiểm thử:** khóa Admin giữa phiên, token refresh, nhiều tab, role giảm quyền, route đang mở, subscription Realtime còn sống. Chặn ở UI không thay cho API. RLS `admin_audit_logs` hiện cho mọi Admin active đọc, nên xem lại mức độ dữ liệu trong metadata.

## 4. Session và log

- Logout phải xóa dữ liệu nhạy cảm ở bộ nhớ, hủy subscription và vô hiệu hóa phiên theo chính sách sản phẩm. App rescuer hiện gọi `signOut(scope: SignOutScope.local)`; cần xác nhận có yêu cầu logout toàn bộ thiết bị hay không.
- Admin dùng Supabase client mặc định, SDK có thể persist session trong browser storage; không tự sao chép token sang app state/log. Kiểm tra XSS/CSP vì XSS trên Admin có thể lấy phiên.
- Hàm debug log khách có danh sách chuỗi cần che, trong đó có tên biến `SUPABASE_SERVICE_ROLE_KEY`; đó là **mã che log**, không phải bằng chứng khóa được cấp. Cần kiểm thử với lỗi chứa dữ liệu nhạy cảm không nằm trong danh sách che.
- Trên Supabase Dashboard cần xác minh email confirmation, TTL JWT, redirect allowlist, giới hạn login, chính sách mật khẩu, recovery, thời gian giữ phiên; repo không chứa cấu hình runtime này.

## 5. 2FA và phục hồi

**Đề xuất giai đoạn sau:** MFA bắt buộc cho Admin có quyền cao, backup/recovery có kiểm soát, cảnh báo đăng nhập thiết bị lạ, rà soát phiên và thu hồi phiên. Đối tác/khách có thể dùng email verification/OTP theo trải nghiệm được phê duyệt. Không bật đại trà trước khi kiểm thử quy trình cứu hộ khẩn cấp khi mất thiết bị.
