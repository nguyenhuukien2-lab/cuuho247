# Cứu Hộ 24/7 Đối tác — Giai đoạn 1–4

Entry point `lib/main.dart` mở `ConnectedRescuerApp` và `PreparationScreen` với năm tab Trang chủ / Đơn mới / Đang xử lý / Lịch sử / Tài khoản. Các màn demo cũ còn trong source nhưng không được mở từ entry point này. Xem [Giai đoạn 2](PHASE2.md) cho contract và kịch bản test nhận đơn.

[Giai đoạn 3](PHASE3.md) bổ sung timeline và cập nhật tiến độ chuyến:
Đã nhận đơn → Đang đến điểm cứu hộ → Đã đến nơi → Đang hỗ trợ khách.

[Giai đoạn 4](PHASE4.md) bổ sung báo giá, xác nhận hoàn tất và lịch sử chuyến qua RPC thật.

## Chạy trên điện thoại

Từ `frontend/rescuer_app`, cấu hình file local `config/supabase.dev.json` theo `config/supabase.example.json`. File dev được Git bỏ qua. Chỉ sử dụng URL và publishable/anon key; validator từ chối secret key và JWT có quyền cao hơn anon.

```powershell
flutter pub get
flutter devices
flutter run -d <android-device-id> --dart-define-from-file=config/supabase.dev.json
```

Nếu cache chung không ghi được hoặc ổ C thiếu dung lượng, dùng cache/temp riêng cho cùng terminal:

```powershell
$rescuerCache = Join-Path $PWD '.dart_tool/stage1-pub-cache'
$rescuerTemp = Join-Path $PWD '.dart_tool/stage1-temp'
New-Item -ItemType Directory -Force -Path $rescuerCache, $rescuerTemp | Out-Null
$env:PUB_CACHE = $rescuerCache
$env:TEMP = $rescuerTemp
$env:TMP = $rescuerTemp
flutter pub get
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
flutter run -d <android-device-id> --dart-define-from-file=config/supabase.dev.json --no-pub
```

Cache này được Git bỏ qua; `flutter clean` sẽ xóa cả `.dart_tool`, cần pub get lại sau đó.

## Tính năng đã nối

- Auth email/password, khôi phục session, đăng xuất và xóa dữ liệu khi đổi user.
- Tạo/cập nhật hồ sơ cá nhân qua RPC và version server.
- Thêm/sửa xe: loại xe, biển số, tên/mô tả phương tiện, trạng thái hoạt động.
- Chọn dịch vụ theo xe và loại xe khách, dùng danh mục thật `rescue_services`. Chỉ ghi capability thay đổi để giữ trạng thái duyệt của lựa chọn không đổi.
- Giấy tờ: JPEG/PNG/PDF tối đa 10 MiB, kiểm tra chữ ký file, reserve bằng RPC, upload bucket riêng `rescuer-documents` với `upsert: false`, complete bằng RPC. Retry cùng tệp trong phiên app dùng lại reservation. Có thao tác xác nhận tệp đang chờ complete, không công khai URL giấy tờ.
- Gửi duyệt khi có hồ sơ và giấy tờ hợp lệ cho xe hoạt động. Hiển thị nháp/chờ duyệt/đã duyệt/từ chối; app không tự duyệt profile, xe hoặc capability.
- Checklist và hướng dẫn hoàn tất, nêu rõ lý do không thể bật online.
- GPS foreground: kiểm tra dịch vụ vị trí, xin quyền runtime, hướng dẫn Cài đặt, yêu cầu fix chính xác, xử lý từ chối/tắt GPS/timeout. Android có coarse/fine; không yêu cầu background location.
- Online: lấy GPS trước, gọi `rescuer_set_online`, rồi `rescuer_update_location`. RPC vị trí yêu cầu session từ set_online nên không thể gửi vị trí trước khi tạo session đầu tiên. Nếu ghi GPS lỗi, thử chuyển offline; nếu offline cũng lỗi, hiển thị trạng thái cần kiểm tra lại.
- Đơn mới qua `rescuer_list_available_requests`: pagination, loading/empty/error/retry/checklist. Chỉ giữ dịch vụ, loại xe, khoảng cách và vị trí coarse; không đọc trực tiếp `rescue_requests`, không hiển thị PII khách.
- Cập nhật GPS/đơn mỗi 45 giây khi online và rảnh ở foreground; khi có chuyến, chuyển sang làm mới chuyến. Dừng polling khi background/logout. Phản hồi cũ không cập nhật dữ liệu sau đổi user.

## Giới hạn backend hiện có

- Sửa tại chỗ và Mở khóa xe chỉ bật nếu danh mục thật có mã tương ứng (`repair`, `locksmith`). Nếu thiếu, UI ghi rõ chưa hỗ trợ; không dùng `other` thay thế.
- Chưa có trường ghi chú/khu vực hoạt động hồ sơ; mô tả phương tiện dùng `display_name` hiện có.
- RPC danh sách đơn chưa trả thời gian tạo nên UI chưa hiển thị thời gian tạo.
- Đã cập nhật tiến độ, báo giá, hoàn tất và lịch sử cơ bản. Chưa làm thanh toán, hủy chuyến hoặc thống kê thu nhập nâng cao.
- Chưa có RPC đọc lại chi tiết báo giá và lưu ghi chú hoàn tất. Sau mở lại app chỉ xem tổng tiền từ chuyến; trường ghi chú hoàn tất bị khóa và có hướng dẫn. Xem PHASE4.md để biết contract và giới hạn.
- Không sửa customer app hay migration; không dùng service_role, không commit, không push database. Việc duyệt do quy trình quản trị backend thực hiện.

## Kịch bản kiểm tra điện thoại

1. Đăng nhập rescuer, tạo hồ sơ, thêm xe và chọn dịch vụ/loại xe khách.
2. Upload căn cước, bằng lái và đăng ký đúng xe, gửi duyệt; kiểm tra chờ duyệt và online bị khóa kèm lý do.
3. Sau khi quản trị duyệt hồ sơ, xe và capability: bật GPS, bật online, cấp quyền vị trí chính xác. Thử từ chối quyền, từ chối vĩnh viễn và tắt GPS để kiểm tra hướng dẫn.
4. Xem Đơn mới: empty state hoặc đơn thật phù hợp dịch vụ/loại xe và bán kính server. Đơn cùng UID rescuer bị loại trừ.
5. Tắt/bật online, đổi xe, background/mở lại, mất mạng, refresh, đăng xuất/đăng nhập. Sửa hồ sơ/xe đã duyệt có thể cần duyệt lại theo RPC.

## File triển khai và kiểm tra

- `lib/screens/preparation/`: UI, form và thành phần dùng chung.
- `lib/app/connected_app.dart`, `rescuer_controller.dart`: Auth gate, lifecycle, checklist và orchestration RPC/GPS.
- `lib/models/backend_models.dart`: snapshot/readiness/projection đơn an toàn.
- `lib/services/rescuer_service.dart`, `location_service.dart`, `document_picker.dart`: RPC/storage, lỗi, GPS, chọn tệp.
- `pubspec.yaml`, `pubspec.lock`: dependencies.
- `test/connected_app_test.dart`, `document_upload_test.dart`: controller/UI/privacy/retry upload.

`flutter pub get` thành công với cache riêng. `flutter analyze --no-pub`: không issue. `flutter test --no-pub --concurrency=1`: 39 test đạt, gồm hai test UI local cũ. Tests dùng fake service/HTTP, không ghi dữ liệu lên Supabase thật.

`flutter build apk --debug --dart-define-from-file=config/supabase.dev.json --no-pub`: thành công sau `flutter clean`, pub get lại và đặt cache/temp ở ổ D; APK ở `build/app/outputs/flutter-apk/app-debug.apk`. Lỗi cache Kotlin khác ổ đĩa và class plugin của output cũ đã hết. Build còn cảnh báo plugin file_picker/package_info_plus dùng Kotlin Gradle Plugin và Java API deprecated.

`flutter run -d chrome --web-browser-flag=--headless --web-port=7359 --dart-define-from-file=config/supabase.dev.json --no-pub`: kết nối debug service và chạy main thành công.

Máy chỉ có Windows/Chrome/Edge, chưa có Android kết nối; chưa kiểm tra GPS/online/claim end-to-end trên điện thoại với tài khoản thật. Customer app và backend không có diff; hash migration giữ nguyên so với đầu lượt.
