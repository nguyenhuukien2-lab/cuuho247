# Backend Supabase

Sáu migration khách hàng được giữ nguyên. Migration người cứu hộ mới chỉ là file
local để review, chưa áp lên DB; không chạy `db push` hoặc nối backend thật vào app.

## Thứ tự áp dụng

1. `backend/supabase/migrations/202609300001_initial_customer_rescue.sql`
2. `backend/supabase/migrations/202610010001_customer_tracking.sql`
3. `backend/supabase/migrations/202610010002_customer_request_photos.sql`
4. `backend/supabase/migrations/202610010003_customer_vehicles.sql`
5. `backend/supabase/migrations/202610010004_customer_saved_addresses.sql`
6. `backend/supabase/migrations/202610010005_customer_request_reviews.sql`

Sau sáu file trên có bản nháp local
`backend/supabase/migrations/202610020001_rescuer_backend_foundation.sql`.
Đọc [báo cáo triển khai](rescuer_backend_implementation.md) và hoàn thành các kiểm
thử/quyết định còn lại trước khi xem xét áp dụng; không thêm vào quy trình deploy tự động.

Các đường dẫn trên tính từ Git root. Xác định đúng project, chạy SQL kiểm kê, đối chiếu migration đã áp và schema hiện có trước khi thực thi file trong Supabase Dashboard SQL Editor. Migration khởi tạo có chốt kiểm tra schema; không bỏ chốt hoặc chạy lại để ép thành công. Chưa có config.toml/CLI project link từ bản ban đầu; không tự tạo project khác hoặc chạy db push trong lượt này.

## SQL dev và cấu hình

- `backend/supabase/tests/inspect_dev.sql`: kiểm kê chỉ đọc, không trả bản ghi khách hàng.
- `backend/supabase/tests/dev_advance_request.sql`: công cụ thay đổi trạng thái đơn dev theo UUID; không chạy tự động hoặc trên production.
- `functions/` và `seed/` chỉ có file giữ thư mục. Chưa có Edge Functions hay seed SQL độc lập. Dữ liệu dịch vụ khởi tạo nằm trong migration có sẵn, không trích ra hoặc sửa SQL.
- Client config nằm trong `frontend/customer_app/config`; cấu hình riêng không được Git theo dõi.

## Tài liệu và bằng chứng

- [Thiết kế backend người cứu hộ](rescuer_backend_plan.md): schema/RPC/RLS đề xuất,
  quyền riêng tư, concurrency và phần cần xác minh; đã tạo migration local, chưa áp.
- [Triển khai backend người cứu hộ](rescuer_backend_implementation.md): phần SQL
  đã viết, kiểm tra offline, cách kiểm thử DB local và các blocker trước rollout.

- [Setup Supabase](SUPABASE_SETUP.md): Auth, schema, RPC, RLS, quy trình kiểm kê và triển khai.
- [Kiểm thử giai đoạn 1](KIEM_THU_GIAI_DOAN_1.md): bằng chứng kiểm kê/migration và các giới hạn tại thời điểm báo cáo.
- [Tracking và Realtime](../customer/P0_CUSTOMER_TRACKING.md#contract-và-triển-khai).
- [GPS dùng lại RPC](../customer/P1_CUSTOMER_LOCATION.md#schemarpc-được-dùng-lại).
- [Migration/RLS/RPC ảnh](../customer/P1_CUSTOMER_PHOTOS.md#migration-và-triển-khai-backend).
- [Xe](../customer/P1_CUSTOMER_VEHICLES.md#migration-cần-áp-dụng).
- [Địa chỉ](../customer/P1_CUSTOMER_SAVED_ADDRESSES.md#backend).
- [Review](../customer/P1_CUSTOMER_REQUEST_REVIEWS.md#contract-backend).

Báo cáo P0/P1 chứa cả contract backend và luồng app; giữ bản đầy đủ trong docs/customer và dẫn tới phần backend ở đây để bảo toàn bằng chứng, tránh tạo bản sao nội dung có thể lệch nhau.
