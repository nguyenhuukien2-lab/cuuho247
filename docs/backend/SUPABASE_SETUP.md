# Cấu hình backend Supabase cho môi trường phát triển

> Đường dẫn đã cập nhật sau khi tổ chức repository. Các đường dẫn file bên dưới tính từ Git root; lệnh Flutter/Dart chạy trong `frontend/customer_app` (từ root: `cd frontend/customer_app`), lệnh Node/tools chạy từ root. Kết quả kiểm thử cũ được giữ theo thời điểm của báo cáo; xem [CLEANUP_REPORT.md](../CLEANUP_REPORT.md) cho kết quả sau di chuyển.

Ứng dụng dùng Supabase Auth, PostgREST và Row Level Security. Không đặt `service_role`, mật khẩu database hoặc khóa bí mật vào Flutter; client chỉ được dùng **publishable key** (hoặc anon key cũ).

## 1. Chuẩn bị database

Migration chưa được chạy tự động. Sau khi xác định đúng project phát triển:

1. Cài/đăng nhập Supabase CLI theo quy trình của đội dự án.
2. Link đúng project phát triển và kiểm tra project ref trước khi chạy bất kỳ migration nào.
3. Review rồi áp dụng `backend/supabase/migrations/202609300001_initial_customer_rescue.sql`.
   Sau đó áp migration nâng cấp `backend/supabase/migrations/202610010001_customer_tracking.sql`.
   Contract trạng thái, timeline/RLS, tọa độ, Realtime và test thủ công:
   [P0_CUSTOMER_TRACKING.md](../customer/P0_CUSTOMER_TRACKING.md).
4. Không áp dụng thẳng lên production trước khi test RLS bằng hai tài khoản khác nhau.

Migration tạo/thay đổi:

- `customer_profiles`, tự tạo từ metadata khi đăng ký;
- `customer_vehicles`;
- `rescue_services` và 5 dịch vụ ban đầu;
- `rescue_requests`;
- RLS giới hạn profile, xe và yêu cầu theo `auth.uid()`;
- unique index bảo đảm một yêu cầu active/khách;
- unique idempotency key cho retry;
- RPC `create_customer_rescue_request` tự lấy chủ đơn từ `auth.uid()`, kiểm tra dịch vụ/xe, trả lại đúng row khi retry và trả đơn đang hoạt động khi có gửi cạnh tranh;
- RPC `cancel_own_rescue_request` kiểm tra JWT, chủ đơn và trạng thái `searching`/`accepted`;
- khách chỉ có quyền đọc bảng yêu cầu; tạo/hủy phải đi qua RPC giới hạn. Khách không thể sửa chủ đơn, trạng thái, người cứu hộ hay giá qua Data API.

Migration hiện là migration khởi tạo, chạy trong transaction và dừng với `EXISTING_SCHEMA_REQUIRES_REVIEW` nếu đã có một trong bốn bảng. Nó tạo 4 bảng, 5 dịch vụ, 4 index, các policy, 3 function và trigger `cuuho247_customer_profile_created`. Nó không thay trigger Auth chung của ứng dụng khác. Chưa áp migration này lên database nào.

Trước khi xin xác nhận chạy từ xa:

1. Mở Dashboard, chọn đúng tổ chức và project **phát triển**; ghi nhận tên project và project ref (phần đứng trước `.supabase.co` trong URL). Cần xác nhận môi trường bằng thông tin quản lý dự án; URL tự nó không cho biết dev hay production.
2. Chạy file **chỉ đọc** `backend/supabase/tests/inspect_dev.sql` trong SQL Editor của project đó. Kết quả gồm tên bảng, số row ước lượng, RLS, grants, policy và trigger/function liên quan, không đọc dữ liệu khách hàng hoặc token.
3. Nếu gặp bảng/tên function trùng, kiểm tra cấu trúc và dữ liệu trước; không bỏ chốt kiểm tra chỉ để ép migration chạy. Nếu phiên bản migration cũ đã được áp dụng ngoài phiên làm việc này, cần migration nâng cấp riêng.
4. Đối chiếu schema hiện có với bản migration, trình bày thay đổi và chỉ áp dụng sau khi bạn xác nhận đúng project và cho phép chạy. URL/publishable key của client không cấp quyền chạy DDL.

## 2. Cấu hình Auth

Trong Supabase Dashboard của môi trường phát triển:

- bật Email + Password;
- quyết định có yêu cầu xác nhận email hay không;
- cấu hình Site URL/Redirect URLs đúng domain dev nếu bật email confirmation;
- không tắt RLS để “sửa nhanh” lỗi quyền.

## 3. Chạy Flutter mà không commit cấu hình

Đã tạo file cục bộ `frontend/customer_app/config/supabase.dev.json` với hai giá trị rỗng. Trong Dashboard project dev, mở **Connect** để lấy Project URL và publishable key; điền trực tiếp vào hai trường `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` trong file này. Nếu chưa có project, tạo một project dành riêng cho phát triển trước. Không gửi mật khẩu hoặc token vào hội thoại. File cấu hình riêng đã được `.gitignore` loại trừ và được kiểm tra bằng `git check-ignore`.

```powershell
flutter run -d chrome --dart-define-from-file=config/supabase.dev.json
```

Build tương tự:

```powershell
flutter build web --dart-define-from-file=config/supabase.dev.json
```

Không truyền hoặc commit `service_role`; RLS không bảo vệ được client nếu khóa đó bị lộ.

## 4. Kiểm tra tối thiểu sau khi cấu hình

1. Đăng ký một email test và xác nhận email nếu project yêu cầu.
2. Đăng nhập, đóng/mở app và xác nhận phiên được phục hồi.
3. Tạo request với địa chỉ tự nhập; kiểm tra chỉ chuyển sang Đang xử lý sau khi row được tạo.
4. Bấm gửi lại khi mạng chập chờn; xác nhận không có row trùng.
5. Thử tạo request active thứ hai; database phải từ chối/ứng dụng phải mở request hiện có.
6. Đăng nhập tài khoản B và xác nhận không đọc được profile, vehicle hoặc request của A.
7. Hủy request và xác nhận row chuyển `cancelled`, xuất hiện trong Lịch sử.

## 5. Script kiểm thử API (chỉ chạy sau khi cấu hình và duyệt môi trường)

`frontend/customer_app/tool/verify_backend.dart` sử dụng HTTP trực tiếp, không dựa vào điều kiện ẩn nút trên giao diện. Tạo `frontend/customer_app/config/backend-tests.dev.json` theo `frontend/customer_app/config/backend-tests.example.json`, nhập hai email/mật khẩu **tài khoản kiểm thử riêng**. File riêng được Git ignore. Script không in thông tin xác thực hoặc body response.

```powershell
dart run tool/verify_backend.dart --register-dev PROJECT_REF_DEV
# Xác nhận email A/B nếu project yêu cầu, sau đó:
dart run tool/verify_backend.dart --verify-dev PROJECT_REF_DEV
```

Lệnh đăng ký tạo tài khoản dev. Lệnh verify tạo/hủy các đơn kiểm thử, để lại lịch sử cho đối chiếu; nó từ chối chạy nếu A/B đã có đơn trước đó. Script không xóa dữ liệu. Mỗi lần chạy mới nên dùng cặp tài khoản test mới. Script kiểm tra đăng nhập đúng/sai, refresh token, lưu/tải đơn, idempotency (cả sau khi hủy), gửi đồng thời, API của B với đơn A, chặn sửa owner/provider/status, hủy/tạo mới và logout. Refresh token qua API chưa chứng minh app tự phục hồi phiên sau khởi động lại; mục này phải kiểm tra thêm trên app.

## 6. Android

`flutter_app/frontend/customer_app/android` đã được tạo riêng từ template SDK Flutter đang cài, không phục hồi Android app cũ ở thư mục cha. Application ID hiện tại: `vn.cuuho247.cuu_ho_247` (dev). Manifest có quyền INTERNET và tên hiển thị “Cứu Hộ 24/7”. `frontend/customer_app/android/local.properties` là cấu hình cục bộ được Git ignore. Chưa có signing phát hành.

Môi trường đã xác minh bằng `flutter doctor -v`: Flutter 3.47.5, Dart 3.13.4, Android SDK/build-tools 36.0.0, platform android-37.0, JDK đi kèm Android Studio 25.0.3; Android licenses đã chấp nhận. Java trên PATH là Oracle 21.0.12.1 nhưng Flutter chọn JDK của Android Studio. Không cần đổi JDK toàn hệ thống cho bước này.

**Build APK hiện bị chặn vì thiếu dung lượng khi cài NDK 28.2.13676358.** Giải phóng đủ dung lượng cho SDK/NDK/Gradle hoặc chuyển SDK sang ổ còn chỗ qua Android Studio rồi cập nhật `frontend/customer_app/android/local.properties`/cấu hình Flutter của máy. Chưa tự xóa SDK hoặc dữ liệu khác. Sau khi có chỗ, thử lại:

```powershell
flutter build apk --debug --dart-define-from-file=config/supabase.dev.json
```

Điện thoại: bật Developer options → USB debugging, kết nối cáp dữ liệu, chấp nhận hộp thoại RSA. Chạy `adb devices -l`; trạng thái phải là `device`, không phải `unauthorized`. Nếu `adb` chưa nằm trên PATH, dùng `C:\Users\ADMIN\AppData\Local\Android\Sdk\platform-tools\adb.exe`.

Emulator: mở Android Studio → Device Manager, tạo thiết bị ảo với system image đã cài và khởi động. Lần kiểm tra này `emulator -list-avds` không trả AVD nào; `adb devices -l` không có thiết bị.

```powershell
flutter devices
flutter run -d DEVICE_ID --dart-define-from-file=config/supabase.dev.json
```

Các lần kiểm tra ở phiên này gọi trực tiếp `bin/cache/dart-sdk/bin/dart.exe bin/cache/flutter_tools.snapshot` với thư mục APPDATA tạm và quyền cache SDK, do wrapper Flutter ở môi trường sandbox từng bị chờ lock/không ghi được cache. Đây là cách chạy kiểm tra trong phiên; chưa xác nhận wrapper `flutter.bat` thông thường hết vấn đề. Không kết thúc các tiến trình IDE/Dart có sẵn.

## Giới hạn giai đoạn này

- Chưa có GPS/map picker; người dùng nhập và xác nhận địa chỉ thủ công.
- Chưa có upload ảnh, app người cứu hộ, realtime provider assignment, admin hoặc thanh toán online.
- Android platform đã được thêm; APK chưa build xong do lỗi dung lượng nêu trên. iOS chưa nằm trong giai đoạn này.
