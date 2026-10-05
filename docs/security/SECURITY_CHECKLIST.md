# Checklist kiểm thử bảo mật

> Mọi ô đang để trống: tài liệu không xác nhận ca nào đã qua trên Supabase triển khai. Chạy trên staging với dữ liệu giả: Customer A/B, Rescuer A/B (approved, pending, suspended), admin từng role và admin blocked. Ghi ngày, môi trường, JWT role, request/response đã che PII, kết quả và ticket lỗi; rollback dữ liệu thử nghiệm.

## Auth và session

- [ ] Chưa đăng nhập không đọc được profile, đơn, quote, tài liệu, admin view hoặc RPC được bảo vệ.
- [ ] Logout xóa session, đóng channel; tab khác/reload không tiếp tục xem dữ liệu khi không có phiên.
- [ ] Token/password/signed URL không xuất hiện trong log client, server, analytics, crash report.
- [ ] Customer bị blocked không tạo đơn; nếu hiện chưa có `account_status`, đánh dấu **chưa hỗ trợ**, không coi là passed.
- [ ] Rescuer suspended/blocked không online, khám phá hoặc nhận đơn; admin blocked không vào dashboard và không gọi RPC/view.
- [ ] Refresh token, phiên cũ và kết nối Realtime sau thay đổi role/status được kiểm tra.

## Customer

- [ ] Customer A không SELECT/UPDATE profile B; không đọc/sửa xe và địa chỉ đã lưu của B.
- [ ] A không đọc đơn, sự kiện trạng thái, ảnh/metadata, đánh giá và mã đơn của B.
- [ ] A không hủy đơn B; không hủy đơn ở trạng thái cấm; retry hủy không tạo sự kiện lặp.
- [ ] Chỉ chủ đơn `completed` được đánh giá; không tạo đánh giá trùng hoặc sửa đánh giá của B.
- [ ] Tạo đơn từ xe không thuộc mình, dịch vụ tắt, đầu vào sai và yêu cầu đồng thời bị xử lý an toàn.
- [ ] Thử spam tạo đơn và upload ảnh; ghi rõ ngưỡng hiện có và khoảng trống rate limit.

## Rescuer

- [ ] Chưa approved/suspended không bật online hoặc claim.
- [ ] Trước khi nhận, discovery/Get Available Request không có SĐT, email, địa chỉ/GPS chính xác hoặc URL ảnh.
- [ ] A không claim/hoàn tất/tạo báo giá cho đơn do B nhận; không sửa báo giá của B.
- [ ] Hai rescuer claim cùng một đơn đồng thời: chỉ một assignment có hiệu lực; rescuer đang bận không nhận quá khả năng.
- [ ] Chuyển trạng thái chỉ đúng thứ tự; không hoàn tất thiếu quote đã phát hành; không hoàn tất sau hủy.
- [ ] Quote sai tổng/âm, thay đổi sau xác nhận, retry cùng operation ID được xử lý đúng.
- [ ] Đối tác không tự phê duyệt hồ sơ, không upload/đọc giấy tờ của đối tác khác.

## Admin và doanh thu

- [ ] User thường gọi `is_admin`, từng admin view/RPC trực tiếp: không lấy được dữ liệu hay thay đổi trạng thái.
- [ ] Support không xem doanh thu nếu bị giới hạn; finance không duyệt đối tác; partner_reviewer không hủy đơn; operator không xem quote/doanh thu trái quyền.
- [ ] Admin blocked không truy cập sau reload, token refresh và kết nối mới; kiểm tra quyền với session cũ.
- [ ] Super_admin không tự khóa/hạ cấp; kiểm tra super_admin cuối cùng.
- [ ] Duyệt/từ chối/khóa/hủy/bật tắt dịch vụ ghi audit đầy đủ actor, target, reason; rollback không để log giả.
- [ ] Client không INSERT/UPDATE/DELETE `admin_audit_logs`; đánh giá lại quyền đọc log của từng role.
- [ ] Báo cáo doanh thu thể hiện rõ số từ quote và số thực thu (nếu sau này có), không gọi lẫn nhau.
- [ ] Thử HTML/script trong tên, lý do, nhận xét; kiểm tra CSP, security headers và không lộ token trên Admin Web.

## Storage

- [ ] Bucket `rescue-request-photos` và `rescuer-documents` là private ở môi trường thật; public URL/anonymous không tải được.
- [ ] Customer A không upload/đọc/xóa ảnh của B; slot, path, MIME, size và số lượng được kiểm tra.
- [ ] Rescuer chưa nhận đơn không tải ảnh; sau nhận chỉ đối tác được giao tải được khi luồng đó được triển khai.
- [ ] Reviewer/super_admin chỉ tải giấy tờ khi có quyền và luồng cấp URL; finance/support không tải được.
- [ ] Rescuer A không tải/upload giấy tờ B; signed URL hết hạn và không cấp mới sau thu hồi quyền.
- [ ] Object và metadata không mồ côi sau thay thế/xóa theo chính sách lưu giữ.

## Realtime

- [ ] Đối chiếu bảng trong `supabase_realtime` publication với tài liệu; chỉ kênh cần thiết được bật.
- [ ] Customer A không nhận event đơn B dù bỏ filter client; payload không lộ old row nhạy cảm.
- [ ] Rescuer chưa nhận không nhận chi tiết đơn; admin blocked/role thấp không nhận dữ liệu admin/doanh thu.
- [ ] Subscription cleanup khi rời trang, logout, đổi tài khoản; reconnect không nhân đôi channel; mất mạng không crash.

## API key, môi trường và vận hành

- [ ] Không có giá trị `service_role` trong frontend, bundle web/APK hoặc `.env` đưa vào build; chỉ anon/publishable key công khai.
- [ ] `.env` thực không commit; `.env.example` không có key/token thật; kiểm tra lịch sử Git và artifact phát hành bằng công cụ quét secret.
- [ ] Không hard-code access/refresh token, signed URL hoặc mật khẩu trong test fixture/log.
- [ ] Service role (nếu có) chỉ nằm ở server/trusted CI với secret manager, quyền tối thiểu và quy trình rotate.
- [ ] Test RLS/RPC/Storage trên staging sau mỗi migration; review diff GRANT/REVOKE và policy trước deploy.

## Tiêu chí đóng đợt kiểm thử

Các ca P0 trong [roadmap](SECURITY_ROADMAP.md) phải có bằng chứng PASS hoặc ticket chặn phát hành, có người duyệt và ngày kiểm thử. Không đánh dấu PASS chỉ vì màn hình ẩn nút hay migration có policy; phải thử trực tiếp bằng JWT/REST/RPC/Storage/Realtime của role không được phép.
