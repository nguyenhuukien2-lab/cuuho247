# Kiến trúc bảo mật - Cứu Hộ 24/7

## 1. Ranh giới tin cậy

```text
Customer App ──publishable/anon key + JWT──> Supabase Auth ──> RLS / RPC ──> Database
                                            └───────────────> Storage private / Realtime có RLS
Rescuer App ──publishable/anon key + JWT──> Supabase Auth ──> RLS / RPC ──> Database
                                            └───────────────> Storage private
Admin Web   ──anon key + JWT─────────────> Supabase Auth ──> is_admin() ──> AdminRoute
                                                                     └──> Admin view / RPC ──> Database
```

Khóa client nhận diện project, **không** cấp quyền quản trị. `auth.uid()` lấy danh tính từ JWT đã xác minh; kiểm tra role và owner phải nằm trong policy/RPC. Cả ba client đều có thể bị chỉnh sửa và gọi REST/RPC trực tiếp ngoài UI.

## 2. Luồng Customer App

`SupabaseService` đăng nhập/restore phiên; profile, xe, địa chỉ, đơn và mốc trạng thái đọc qua RLS theo `auth.uid()`. Tạo/hủy đơn dùng `create_customer_rescue_request`/`cancel_own_rescue_request`; ảnh dùng reserve → upload private → complete; đánh giá dùng `submit_customer_request_review`. Theo dõi Realtime lọc theo `id`, kiểm tra `customer_id` và phiên hiện tại, reload snapshot khi reconnect. **Kiểm thử** quyền thật bằng hai JWT khác nhau, vì filter ở client không thay thế RLS.

## 3. Luồng Rescuer App

`rescuer_profiles` cùng giấy tờ, xe và capability quyết định trạng thái duyệt. Chỉ RPC khám phá trả dữ liệu thô trước claim; `rescuer_claim_request` khóa đơn và tạo assignment. Sau claim, `rescuer_get_active_job` trả dữ liệu cần xử lý; tiến độ dùng `rescuer_update_job_status`, báo giá dùng `rescuer_create_quote`; cùng chuỗi này xử lý hoàn tất. DTO lịch sử tách khỏi dữ liệu liên hệ đang hoạt động. `private.rescuer_begin_operation` dùng operation ID và khóa giao dịch chống retry/nhận cạnh tranh. Hồ sơ `suspended` và trạng thái xe/dịch vụ phải được kiểm tra lại ở server mỗi lần đổi quyền.

## 4. Luồng Admin Web

`LoginPage` đăng nhập bằng Supabase Auth rồi gọi `is_admin()`; trả false thì sign out. `AdminRoute` kiểm tra lại khi tải trang/thay phiên, có trạng thái loading và chặn route. Đây là lớp UI; view có `has_admin_role()`/`is_admin()`, RPC dùng `private.admin_require_role()`, mới quyết định quyền dữ liệu. `admin_get_dashboard_stats()` che doanh thu đối với vai trò không có quyền tài chính. `AuditLogsPage` và gửi thông báo hiện chưa nối dữ liệu/thao tác thực trên UI, dù schema/policy phía Admin đã có.

## 5. Lớp Supabase và ranh giới chưa xác nhận

- **Auth:** cùng lớp `authenticated` PostgreSQL cho customer và rescuer; vai trò nghiệp vụ được xác định từ hồ sơ/RPC, không mặc nhiên tách bằng hai khóa client.
- **RLS:** bảng khách theo owner; bảng rescuer nhạy cảm chỉ chủ được SELECT, assignment/quote không cấp SELECT client; Admin dùng view có gate riêng.
- **RPC:** nhiều hàm `SECURITY DEFINER`; cần test `EXECUTE`, `search_path`, chủ sở hữu, state và projection. Không coi URL/UUID đoán được là một lớp bảo vệ.
- **Storage:** hai bucket private theo migration; truy cập object quyết định bởi `storage.objects` policies. Signed URL là bearer link có thời hạn, phải kiểm tra ai có thể tạo và chia sẻ.
- **Realtime:** migration chỉ thể hiện publication `rescue_requests`; subscription nhận row dựa vào quyền SELECT/RLS của JWT. Phải xác minh hành vi trên Supabase thật khi role bị chặn hoặc token cũ còn hiệu lực.

## 6. Quản lý khóa

`service_role` chỉ thuộc môi trường server/trusted migration, không vào Flutter, `VITE_*`, bundle JS, repository hoặc log. Flutter dùng `SUPABASE_PUBLISHABLE_KEY` hoặc anon key; Admin Web dùng `VITE_SUPABASE_ANON_KEY`. Secret rotation, domain Auth, MFA, backup, quyền project và Security Advisor phải được kiểm tra trên Dashboard vì mã nguồn không chứng minh cấu hình môi trường.
