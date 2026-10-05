# Kế hoạch bảo mật tổng thể - Cứu Hộ 24/7

> Bản rà soát mã nguồn ngày 05/10/2026. Đây là kế hoạch, không phải chứng nhận môi trường Supabase đang triển khai an toàn. Ký hiệu **Đã thấy trong mã**, **Cần kiểm thử**, **Đề xuất** được dùng xuyên suốt bộ tài liệu. Không áp migration hay thay đổi database trong lần rà soát này.

## 1. Mục tiêu bảo mật

- Bảo vệ tài khoản khách hàng, đối tác và quản trị viên; buộc thao tác nhạy cảm phải kiểm tra danh tính, chủ sở hữu, vai trò và trạng thái ở server.
- Khách chỉ đọc hồ sơ, xe, địa chỉ, đơn, ảnh và đánh giá của mình. Đối tác trước khi nhận đơn chỉ thấy thông tin đủ để quyết định nhận; không thấy điện thoại, email, địa chỉ hoặc GPS chính xác của khách.
- Người dùng thường không thể gọi RPC Admin; tài khoản Admin bị khóa không thể tiếp tục đọc dữ liệu hoặc thực hiện thao tác mới.
- Ảnh sự cố và giấy tờ luôn ở bucket private; không dùng `service_role` trong Flutter hoặc Admin Web; báo giá và doanh thu chỉ đến đúng vai trò.
- Có audit đáng tin cậy cho thao tác Admin, kiểm thử xuyên vai trò và quy trình ứng phó khi phát hiện lộ lọt.

## 2. Phạm vi và bằng chứng

| Thành phần | Nguồn đã đọc | Ranh giới quan trọng |
|---|---|---|
| Customer App | `frontend/customer_app/lib`, cấu hình app | Auth, bảng chủ sở hữu, RPC đơn/ảnh/đánh giá, Realtime đơn |
| Rescuer App | `frontend/rescuer_app/lib`, cấu hình app | Hồ sơ duyệt, vị trí, khám phá, nhận đơn, báo giá, giấy tờ |
| Admin Web | `admin_web/src` | Login, `AdminRoute`, view/RPC, refresh Realtime |
| Database | `backend/supabase/migrations`, `admin_web/backend/supabase/migrations` | RLS, grants, `SECURITY DEFINER`, Storage, audit |
| Kiểm thử hiện có | `backend/supabase/tests`, `admin_web/backend/supabase/tests`, test Flutter/Playwright | Chưa thay thế kiểm thử JWT/PostgREST/Storage trên môi trường triển khai |

**Dữ liệu cần bảo vệ:** tên, điện thoại, email, GPS và lịch sử vị trí, địa chỉ lưu, xe và biển số, mô tả/ảnh sự cố, hồ sơ và giấy tờ đối tác, báo giá và chỉ số doanh thu, nội dung thông báo, nhật ký Admin, access/refresh token và khóa cấu hình.

## 3. Nguyên tắc áp dụng

1. Quyền tối thiểu theo vai trò **và** bản ghi; UI chỉ hỗ trợ trải nghiệm, RLS/RPC mới là chốt quyền.
2. Không tin ID, status, số tiền, loại file hay vị trí do client tự khai; truy lại dữ liệu có thẩm quyền trong database.
3. Không cấp UPDATE trực tiếp cho trạng thái đơn, assignment, quote và audit; thao tác qua RPC kiểm tra state, version và idempotency.
4. `SECURITY DEFINER` phải giới hạn `EXECUTE`, cố định `search_path`, kiểm tra `auth.uid()` và trả projection nhỏ nhất.
5. Tệp nhạy cảm chỉ lưu private; signed URL cấp cho người có quyền, thời hạn ngắn, không đưa vào log/phân tích hành vi.
6. Audit các thao tác Admin có actor, mục tiêu, lý do, trước/sau và thời gian; không ghi mật khẩu/token/giấy tờ vào audit.
7. Giảm dữ liệu theo thời điểm cần dùng; đóng quyền xem chính xác khi job kết thúc trừ trường hợp khiếu nại có kiểm soát.

## 4. Quyền theo vòng đời đơn

| Trạng thái đơn | Khách hàng | Đối tác | Admin hợp lệ | Phải ẩn / cấm |
|---|---|---|---|---|
| `searching` | Xem đơn, ảnh của mình; được hủy | Nếu đủ điều kiện online/duyệt: dịch vụ, loại xe, tọa độ **làm thô** qua RPC khám phá; được nhận | `super_admin`/`operator`/`support` xem view điều phối; `super_admin`/`operator` có thể hủy | Không lộ liên hệ, mô tả riêng tư, vị trí chính xác, ảnh cho đối tác chưa nhận; không sửa status trực tiếp |
| `accepted` | Xem tiến độ và đối tác được phân công; được hủy nếu server cho phép | Chỉ đối tác đã nhận xem liên hệ/địa điểm cần hỗ trợ, cập nhật bước hợp lệ | Theo vai trò view/RPC; theo dõi assignment | Đối tác khác không xem chi tiết; không nhận trùng |
| `arriving` | Theo dõi tiến độ; được hủy theo RPC hiện tại | Đối tác sở hữu job cập nhật bước tiếp theo | Vai trò điều phối xem; `super_admin`/`operator` có thể hủy | Không cho nhảy trạng thái hay lấy job của người khác |
| `in_progress` | Xem tiến độ và báo giá hợp lệ; đánh giá chưa được mở | Đối tác sở hữu job gửi báo giá qua `rescuer_create_quote`, hoàn tất sau khi có báo giá hợp lệ | Điều phối xem; `super_admin`/`finance` xem tiền qua view thích hợp | Không hủy bằng Admin RPC hiện tại; không sửa trực tiếp quote hoặc tự đặt giá đã chốt |
| `completed` | Xem lịch sử, gửi/sửa đánh giá của đơn hoàn tất theo policy hiện có | Xem DTO lịch sử tối thiểu; không còn quyền sửa job | Tùy vai trò; doanh thu chỉ `super_admin`/`finance` | Không chuyển ngược trạng thái; không mở rộng liên hệ/GPS lịch sử vô hạn |
| `cancelled` | Xem lịch sử và mốc hủy | Chỉ xem DTO lịch sử job của mình | Vai trò được cấp xem lịch sử/audit | Không tiếp tục nhận, báo giá, hoàn tất hoặc sửa trạng thái |

**Lưu ý:** `arriving` ở đơn bao gồm bước nội bộ `en_route`/`arrived` của assignment. “Khách thấy thông tin đối tác” và “đối tác thấy ảnh sau nhận” là mục tiêu sản phẩm cần đối chiếu với projection/policy thực tế; không suy ra quyền từ nhãn UI. Chi tiết tại [kiến trúc](SECURITY_ARCHITECTURE.md), [quyền](SECURITY_ROLE_MATRIX.md) và [rủi ro](SECURITY_RISKS.md).

## 5. Cách dùng bộ tài liệu

Đọc [rủi ro](SECURITY_RISKS.md) trước, thực hiện [checklist](SECURITY_CHECKLIST.md) trên project thử nghiệm với tài khoản riêng cho từng vai trò, rồi triển khai theo [roadmap](SECURITY_ROADMAP.md). Mỗi thay đổi bảo mật sau này cần migration mới, test âm tính, peer review và kế hoạch rollback riêng.
