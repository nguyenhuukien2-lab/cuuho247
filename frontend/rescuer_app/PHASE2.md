# Giai đoạn 2: Nhận đơn thật và xem chuyến đang xử lý

Chỉ thay đổi rescuer_app. Không sửa customer_app hoặc backend/migration, không
push DB, không dùng service_role và không commit tự động.

## Luồng RPC

1. Discovery vẫn dùng `rescuer_list_available_requests`; DTO trước nhận chỉ giữ
   UUID, dịch vụ, loại xe khách, tọa độ coarse và khoảng cách ước tính.
2. Nút Nhận đơn gọi `rescuer_claim_request` với `p_request_id`, xe online hiện tại
   (`p_vehicle_id`) và `p_operation_id` UUID do service quản lý. Nút loading và
   khóa nhận thêm trong lúc RPC chạy; retry lỗi transport giữ cùng operation ID
   cho cùng payload trong phiên app.
3. Backend khóa đơn và tạo assignment; đồng thời cập nhật
   `rescue_requests.provider_id = auth.uid()` và `status = accepted` trong cùng
   transaction. App không tự ghi status/provider/assignment bằng query bảng.
4. Khi có assignment xác nhận, app chuyển tab Đang xử lý, hiện snackbar và gọi
   `rescuer_get_active_job()` để lấy chi tiết được phép xem. RPC claim chỉ trả
   metadata assignment, không đủ để hiển thị liên hệ khách.
5. App thử refresh danh sách. Discovery yêu cầu rescuer idle, nên `RESCUER_BUSY`
   sau claim được xử lý như trạng thái bình thường: xóa card cũ và hướng dẫn mở
   chuyến đang xử lý. Không nhận thêm khi đang có assignment.

`REQUEST_UNAVAILABLE` hiển thị “Đơn đã có người nhận hoặc không còn khả dụng” rồi
tải lại danh sách. Mã này cũng có thể do đơn bị hủy hoặc không còn khớp điều kiện;
app không đọc bảng đơn để suy đoán ai đã nhận.

Nếu mất phản hồi claim, app kiểm tra active-job trước khi cho nhận thêm. Nếu
backend đã commit đúng đơn, app phục hồi chuyến và báo thành công. Nếu chưa đọc
được active-job, UI hiển thị lỗi và chặn nhận thêm đến khi kiểm tra lại thành công.

Nếu claim thành công nhưng chi tiết lỗi, app giữ mã/trạng thái assignment,
hiển thị lỗi và cho tải lại. Không hiển thị PII từ cache cũ hoặc coi claim đã thất bại.

## Chuyến đang xử lý và quyền riêng tư

- Bốn tab: Trang chủ / Đơn mới / Tài khoản / Đang xử lý.
- Active-job được tải khi đăng nhập, refresh và trở lại foreground; phục hồi
  được cả khi rescuer offline. App làm mới chuyến mỗi 45 giây trong foreground
  khi đang có chuyến. Chưa thêm background location.
- Hiển thị trạng thái accepted/en_route/arrived/in_progress, mã đơn, thời điểm
  nhận, dịch vụ/xe khách, tên/số điện thoại, địa điểm/tọa độ chính xác và mô tả
  theo RPC active-job.
- Trước mỗi lần kiểm tra quyền, xóa chi tiết cũ. Kết quả null, lỗi RLS hoặc đổi
  Auth không giữ/khôi phục PII từ response cũ. Có loading/empty/error và nút tải lại.
- RPC hiện chưa trả ảnh; UI ghi chưa có ảnh, không tự mở thêm quyền storage.
- RPC discovery chưa trả thời gian tạo; không hiển thị thời gian tạo suy đoán.
- Chưa gọi RPC cập nhật trạng thái chuyến, báo giá hoặc hoàn tất.

## Test hai tài khoản trên điện thoại

Chạy từ rescuer_app, dùng config local đã có:

```powershell
flutter pub get
flutter devices
flutter run -d <android-device-id> --dart-define-from-file=config/supabase.dev.json
```

1. Customer và rescuer phải khác UID. Customer tạo đơn thật với vị trí, dịch vụ
   và loại xe phù hợp; rescuer đã approved bật online và xem Đơn mới.
2. Kiểm tra card chưa có PII. Bấm Nhận đơn; kiểm tra loading, chuyển tab Đang xử lý
   và snackbar. Xem liên hệ, địa chỉ/tọa độ, mô tả sau khi active-job tải thành công.
3. Bên customer kiểm tra đơn đổi trạng thái sang accepted qua cơ chế subscription
   hoặc tải lại đơn. Không cần thay đổi code customer để ghi trạng thái.
4. Đăng xuất/đăng nhập lại rescuer và kiểm tra chuyến vẫn phục hồi. Thử offline
   rồi tải lại chuyến; chưa có nút cập nhật trạng thái chuyến trong giai đoạn này.
5. Với đơn mới khác và hai rescuer đủ điều kiện, bấm nhận đồng thời: một người
   thành công, người còn lại thấy thông báo đơn không còn khả dụng.
6. Thử mất mạng lúc nhận/tải chuyến, kết nối lại và tải lại; kiểm tra không có
   assignment trùng hoặc card nhận thêm khi đã có chuyến.

## Kiểm tra và file thay đổi

- `flutter pub get`: thành công, dùng cache/temp riêng ở ổ D như README.
- `flutter analyze --no-pub`: không có issue.
- `flutter run -d chrome --web-browser-flag=--headless --web-port=7360 --dart-define-from-file=config/supabase.dev.json --no-pub`: chạy main và kết nối debug service thành công; đã dừng preview sau kiểm tra.
- `git status --short`, `git diff --check -- frontend/rescuer_app`: đã kiểm tra,
  không lỗi whitespace. Customer/backend không có diff; SHA256 migration giữ
  nguyên `9381B39D448662F8A034D962E17BED320478DDA617B308B5497F388C521BC015`.
- `flutter test --no-pub --concurrency=1`: 29 test đạt. Bao gồm claim thành công,
  tranh chấp, busy, mất phản hồi, retry cùng operation UUID, RPC null/terminal,
  xóa PII khi RLS/logout, khóa nút và snackbar. Tests dùng fake/HTTP mock, không
  claim đơn thật hoặc ghi dữ liệu lên Supabase thật.
- `flutter build apk --debug --dart-define-from-file=config/supabase.dev.json --no-pub`:
  thành công, APK ở `build/app/outputs/flutter-apk/app-debug.apk`. Còn cảnh báo KGP
  từ file_picker/package_info_plus và Java native access.
- Không có Android kết nối trong phiên này; chưa xác nhận end-to-end hai tài
  khoản thật, GPS thiết bị hoặc trạng thái trên điện thoại khách hàng.

Files: `lib/models/backend_models.dart`, `lib/services/rescuer_service.dart`,
`lib/app/rescuer_controller.dart`, `lib/screens/preparation/preparation_screen.dart`,
`lib/screens/preparation/active_job_panel.dart`, `test/connected_app_test.dart`,
`test/claim_request_test.dart`, `README.md`, `PHASE2.md`.
