# Sổ rủi ro bảo mật

> Mức độ/khả năng là đánh giá ưu tiên sơ bộ, không phải kết quả pentest. “Cần xác minh” nghĩa là chưa có bằng chứng khai thác; “khoảng trống xác nhận” là điều nhìn thấy trong mã/migration. Cập nhật trạng thái sau test staging và sau mỗi deploy.

| Mã | Mô tả | Mức độ | Khả năng | Ảnh hưởng | Cách kiểm tra | Cách xử lý | Ưu tiên / trạng thái |
|---|---|---|---|---|---|---|---|
| SEC-001 | User A đọc dữ liệu user B qua RLS/RPC | Rất cao | Chưa biết | Lộ PII, vị trí, lịch sử | JWT A/B gọi SELECT/RPC mọi bảng, bỏ filter client | Policy owner/assignment, test chéo role | P0 / cần xác minh runtime |
| SEC-002 | Đối tác thấy SĐT/GPS khách trước khi nhận | Rất cao | Chưa biết | Theo dõi/quấy rối khách | Discovery, REST, Realtime và Storage trước claim | Projection tối thiểu; cấp chi tiết sau assignment | P0 / RPC discovery đã giảm dữ liệu; cần kiểm tra các đường khác |
| SEC-003 | User thường gọi được RPC/view admin | Rất cao | Chưa biết | Thao tác/đọc dữ liệu quản trị | JWT thường gọi trực tiếp toàn bộ RPC/view | Gate role/status trong DB, REVOKE/GRANT đúng | P0 / mã có kiểm tra, cần test deploy |
| SEC-004 | Ảnh/giấy tờ Storage bị public hoặc vượt quyền | Rất cao | Chưa biết | Lộ ảnh, giấy tờ | Xem `public` bucket, anonymous URL, object path chéo | Bucket private; policy và URL ký ngắn hạn | P0 / migration khai báo private; xác minh runtime |
| SEC-005 | Service role/secret bị lộ trong frontend/artifact | Rất cao | Thấp theo nguồn đã xem | Bỏ qua RLS, truy cập rộng | Quét source, Git history, bundle/APK, CI log | Gỡ, rotate, đưa vào trusted environment | P0 / chưa phát hiện giá trị service role ở source/config đã kiểm tra |
| SEC-006 | Realtime phát payload nhạy cảm quá rộng | Cao | Chưa biết | Lộ PII/GPS/quote | JWT A/B subscribe không filter; kiểm tra payload INSERT/UPDATE/DELETE | RLS server, projection tối thiểu, publication chọn lọc | P0 / cần test runtime |
| SEC-007 | Admin role thấp thao tác vượt quyền | Cao | Chưa biết | Duyệt/hủy/khóa trái phép | Gọi trực tiếp từng RPC/view bằng 5 role | Kiểm tra role từng RPC/view và regression test | P0 / migration có matrix, cần test deploy |
| SEC-008 | Audit log bị client giả/chỉnh/xóa | Cao | Chưa biết | Mất khả năng truy vết | REST INSERT/UPDATE/DELETE bằng JWT admin/thường | Chỉ BE ghi log, hạn chế SELECT, kiểm tra nguyên tử | P0 / migration hạn chế ghi, cần test deploy |
| SEC-009 | Báo giá bị sửa sau xác nhận/hoàn tất | Cao | Chưa biết | Gian lận giá/tranh chấp | Gửi quote revision, sửa trực tiếp và retry sau completed | Bất biến DB, state/owner check, version lock | P0 / có cơ chế revision/immutable, cần test cạnh tranh |
| SEC-010 | Không có cơ chế khóa customer để chặn lạm dụng | Cao | Trung bình | Spam, tài khoản xấu vẫn tạo đơn | Kiểm tra schema/RPC `account_status`; thử tài khoản bị xử lý | Migration trạng thái và gate tạo đơn, quy trình mở khóa | P1 / **khoảng trống xác nhận** |
| SEC-011 | Spam tạo đơn/upload ảnh | Cao | Trung bình | Tốn chi phí, nghẽn vận hành | Burst/concurrency test theo user/IP và giới hạn ảnh | Rate limit, quota, giám sát, chống bot phù hợp | P1 / có giới hạn đơn đang hoạt động/ảnh, chưa thấy limit theo giờ |
| SEC-012 | Đối tác nhận quá nhiều đơn cùng lúc | Cao | Thấp theo mã đã xem | Không phục vụ kịp, sai trạng thái | Claim song song nhiều đơn và retry | Lock/kiểm tra idle, test cạnh tranh | P0 / logic claim kiểm tra idle, cần test race |
| SEC-013 | UI đối tác thiếu mã `rescuer_code` vì projection profile không chọn cột | Thấp | Cao | Hiện “Chưa có mã”, khó đối soát | So sánh `loadSnapshot()` với UI profile | Thêm cột vào SELECT ở đợt sửa code | P2 / **khoảng trống xác nhận**, không phải lỗ hổng truy cập |
| SEC-014 | Người được giao/reviewer không tải được ảnh hoặc giấy tờ cần xử lý | Trung bình | Cao | Chậm cứu hộ/duyệt hồ sơ; dễ dẫn tới chia sẻ file thủ công thiếu an toàn | JWT đối tác đã nhận và reviewer thử Storage | Thiết kế signed URL có quyền, TTL, audit | P1 / **khoảng trống xác nhận** |
| SEC-015 | Audit log có BE nhưng trang tra cứu chưa nối dữ liệu | Trung bình | Cao | Khó phát hiện và điều tra sự cố | Kiểm tra `AuditLogsPage` và truy vấn log | Nối UI qua nguồn dữ liệu có role gate | P1 / **khoảng trống xác nhận** |

## Thứ tự xử lý

Đầu tiên kiểm thử SEC-001, 002, 003, 004, 005, 006 trên môi trường thật/staging vì tác động lộ dữ liệu có thể rất lớn. Sau đó xử lý các khoảng trống đã xác nhận (SEC-010, 014, 015), đồng thời chạy test cạnh tranh cho SEC-009 và 012. Không diễn giải rủi ro giả định là sự cố đã xảy ra.
