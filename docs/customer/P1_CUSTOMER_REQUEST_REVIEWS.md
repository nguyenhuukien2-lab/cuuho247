# P1 — Đánh giá sau cứu hộ (app khách hàng)

> Đường dẫn đã cập nhật sau khi tổ chức repository. Các đường dẫn file bên dưới tính từ Git root; lệnh Flutter/Dart chạy trong `frontend/customer_app` (từ root: `cd frontend/customer_app`), lệnh Node/tools chạy từ root. Kết quả kiểm thử cũ được giữ theo thời điểm của báo cáo; xem [CLEANUP_REPORT.md](../CLEANUP_REPORT.md) cho kết quả sau di chuyển.

## File thêm/sửa
- `backend/supabase/migrations/202610010005_customer_request_reviews.sql`: bảng mới, RLS, grants, trigger kiểm tra chủ đơn/trạng thái và RPC.
- `frontend/customer_app/lib/services/customer_request_review_service.dart`: model và repository đọc theo request/customer; gửi bằng RPC với JWT của session hiện tại.
- `frontend/customer_app/lib/widgets/customer_request_review_card.dart`: tải đánh giá, chọn 1–5 sao, nhận xét, loading/lỗi/retry, hiển thị kết quả ngay sau khi gửi. Giữ form khi lỗi; bỏ kết quả bất đồng bộ khi đổi tài khoản.
- `frontend/customer_app/lib/screens/history_details_screen.dart`: gắn widget đánh giá chỉ khi status = completed; hỗ trợ inject repository để test.
- `frontend/customer_app/test/customer_request_review_repository_test.dart`: JWT/filter, load có/không review, RPC payload, comment nullable, validation, lỗi backend.
- `frontend/customer_app/test/customer_request_reviews_test.dart`: completed có/không review, 5 trạng thái khác không hiện UI/không đọc review, gửi lỗi giữ form, retry/thành công, loading chống gửi lặp, lỗi tải/retry, đổi session khi đang gửi.
- `P1_CUSTOMER_REQUEST_REVIEWS.md`: tài liệu này.

Không thêm dependency; không cần flutter pub get. Flutter chỉ dùng client Supabase hiện tại với publishable/anon key và session JWT, không dùng service_role.

## Contract backend
`request_id` unique: tối đa 1 review/đơn. `rating` từ 1–5. `comment` nullable, tối đa 2000 ký tự; chuỗi trắng chuyển thành null. Timestamp được tạo/cập nhật ở database.

RLS giới hạn đọc theo chính customer và chủ request; tạo/sửa chỉ cho request completed của chính customer. Không có DELETE grant/policy. Quyền UPDATE chỉ có rating/comment; request_id/customer_id/id/created_at không sửa được qua REST. Trigger kiểm tra cả REST/RPC và khóa request trong transaction để trạng thái không đổi giữa kiểm tra và ghi.

RPC `submit_customer_request_review(p_request_id uuid, p_rating integer, p_comment text default null)` chạy security invoker, giữ RLS và lấy customer_id từ auth.uid(). Gửi lại cùng request cập nhật review hiện có, không tạo bản trùng. Trigger security definer chỉ thực hiện kiểm tra và khóa request theo auth.uid(), với search_path rỗng; không mở quyền ghi trạng thái request cho khách.

UI hiện kết quả sau khi gửi và khi mở lại chi tiết. RPC/RLS hỗ trợ sửa rating/comment của chính khách; phiên P1 này không thêm màn sửa đánh giá riêng.

## Apply migration trên Supabase
1. Chọn đúng project development trong Supabase Dashboard → SQL Editor. Các migration trước đó (initial, tracking, photos, vehicles, saved addresses) cần được áp dụng theo thứ tự; không chạy lại initial trên schema đã có.
2. Mở `backend/supabase/migrations/202610010005_customer_request_reviews.sql`, copy toàn bộ nội dung (bao gồm begin/commit) vào SQL Editor và Run. Không chạy lại migration sau khi đã thành công.
3. Kiểm tra bảng `public.customer_request_reviews` có RLS enabled, 3 policy SELECT/INSERT/UPDATE; không có policy DELETE. Kiểm tra RPC `submit_customer_request_review` tồn tại.
4. Nếu dự án đã dùng Supabase CLI quản lý lịch sử migration, áp dụng migration bằng quy trình CLI hiện có (`supabase db push` sau khi link đúng project), tránh apply đồng thời bằng cả CLI và SQL Editor.

Migration chưa được apply lên Supabase trong phiên này. Test Flutter dùng mock/fake; chưa xác minh RLS/RPC trên database thật.

## Test thủ công
```powershell
flutter run -d chrome --dart-define-from-file=config/supabase.dev.json
```
1. Đăng nhập khách A. Chuẩn bị một request test completed của A. Nếu request đang active, dùng script development có sẵn `backend/supabase/tests/dev_advance_request.sql`: thay đúng UUID, chạy lần lượt searching → accepted → arriving → in_progress → completed. Không nhảy trực tiếp trạng thái vì trigger vòng đời chặn.
2. Mở Lịch sử → chi tiết đơn completed: thấy form sao và nhận xét. Chưa chọn sao mà gửi: hiện yêu cầu chọn sao.
3. Chọn 4 sao, nhập nhận xét, tắt mạng rồi Gửi đánh giá. Sau lỗi: còn 4 sao và nhận xét. Bật mạng, bấm Thử lại: UI đổi ngay thành “Đã đánh giá: 4/5 sao” và nhận xét. Mở lại chi tiết: vẫn hiện đánh giá đã gửi.
4. Một đơn completed khác: gửi 1 hoặc 5 sao, để nhận xét trống; kiểm tra comment null ở database.
5. Mở chi tiết cancelled/searching/accepted/arriving/in_progress: không có đánh giá. Gọi RPC với JWT A cho đơn chưa completed: bị từ chối.
6. Đăng nhập khách B. Dùng JWT B gọi REST/RPC cho đơn/review của A: không đọc được review A, không tạo/sửa review cho đơn A. DELETE review bằng JWT A cũng phải bị từ chối. Không kiểm tra RLS bằng quyền postgres của SQL Editor vì quyền đó bỏ qua RLS.
7. Gọi RPC với JWT A hai lần cho cùng đơn completed: chỉ có một row; id/created_at giữ nguyên, rating/comment và updated_at được cập nhật. Hai lần gửi đồng thời cũng không tạo review trùng.
8. Gọi REST/RPC rating 0, 6 hoặc comment quá 2000 ký tự: bị từ chối. Thử PATCH customer_id/request_id/id: bị từ chối bởi quyền cột/trigger.
9. Đang gửi hoặc tải đánh giá, đăng xuất/đổi tài khoản: không hiện kết quả hay nhận xét của tài khoản cũ.

Điện thoại web cùng Wi-Fi:
```powershell
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080 --dart-define-from-file=config/supabase.dev.json
```
Mở `http://<IP-LAN-máy-tính>:8080`, kiểm tra các bước trên, nút sao, bàn phím nhận xét, cuộn đến nút gửi và kết quả sau gửi. Tính năng đánh giá không yêu cầu GPS.

## Kết quả kiểm tra
- `flutter analyze --no-fatal-infos --no-fatal-warnings`: exit code 0, không error; còn 4 warning unused và 46 info deprecated trong mã cũ, không có diagnostic trong phần review mới.
- `flutter test`: 98 test pass, exit code 0 (81 test hiện có + 17 test review mới).
- Chưa thử tương tác trực tiếp trên Chrome/điện thoại, chưa apply migration hoặc test RLS/RPC trên Supabase thật.
