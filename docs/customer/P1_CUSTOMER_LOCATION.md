# P1 — GPS và vị trí thật cho app khách hàng

> Đường dẫn đã cập nhật sau khi tổ chức repository. Các đường dẫn file bên dưới tính từ Git root; lệnh Flutter/Dart chạy trong `frontend/customer_app` (từ root: `cd frontend/customer_app`), lệnh Node/tools chạy từ root. Kết quả kiểm thử cũ được giữ theo thời điểm của báo cáo; xem [CLEANUP_REPORT.md](../CLEANUP_REPORT.md) cho kết quả sau di chuyển.

## Schema/RPC được dùng lại

Đã kiểm tra hai migration trong repository, không tạo migration mới:

- `backend/supabase/migrations/202609300001_initial_customer_rescue.sql`: bảng
  `rescue_requests` đã có `latitude`, `longitude` kiểu `double precision`, nullable,
  có giới hạn miền giá trị.
- `backend/supabase/migrations/202610010001_customer_tracking.sql` (P0): RPC
  `create_customer_rescue_request` đã nhận `p_latitude`, `p_longitude` mặc định null;
  yêu cầu cả hai null hoặc cùng hợp lệ. RPC lưu tọa độ và trả về request đầy đủ.
- `AppController.createRequest`, `SupabaseService.createRescueRequest` và
  `RescueRequestData.fromJson` đã truyền/đọc các trường này từ P0 nên giữ nguyên.

Backend chạy app cần đã áp dụng hai migration theo thứ tự trên. Phiên P1 này
kiểm tra contract trong mã nguồn; không xác minh schema hay ghi dữ liệu lên
Supabase đang triển khai. Retry cùng idempotency key vẫn trả request gốc theo P0;
nếu đã có request active thì backend trả request đó, không ghi đè tọa độ.

## Luồng sử dụng

Khách bấm **Lấy vị trí hiện tại** để bắt đầu xin quyền/lấy vị trí. Không tự bật
hộp thoại xin quyền khi khởi động app hoặc khi IndexedStack dựng form ở tab ẩn.
Địa chỉ text vẫn bắt buộc, không tự reverse geocode hay thay địa chỉ đã nhập.

Form hiển thị chưa lấy vị trí, đang lấy, đã lấy, từ chối quyền hoặc không hỗ trợ/lỗi.
Thành công hiển thị tọa độ và gửi cả cặp cùng địa chỉ text qua RPC cũ. Khi chưa lấy,
bị từ chối, tắt GPS, lỗi hoặc timeout, khách vẫn xác nhận địa chỉ và gửi với cặp null.
Thời gian chờ mỗi thao tác nền tảng tối đa 20 giây. **Chỉ dùng địa chỉ nhập tay**
bỏ tọa độ đã lấy hoặc bỏ qua kết quả đang chờ. Có thể bấm lấy vị trí để thử lại.

Khi vị trí thay đổi, cần xác nhận lại địa điểm cứu hộ. Không thay đổi tọa độ của
yêu cầu đang gửi nếu GPS trả về muộn. Sau khi gửi thành công, hoặc đổi tài khoản,
form bỏ tọa độ cũ để không tự gắn vào yêu cầu sau. Gửi lỗi vẫn giữ dữ liệu và khóa retry.

Tracking hiển thị địa chỉ và tọa độ đã lưu trên request; request cũ không có GPS
hiển thị thông báo chỉ dùng địa chỉ nhập tay. Đây là vị trí cứu hộ tại lúc gửi,
không phải theo dõi khách/người cứu hộ liên tục.

`RescueCoordinates` và `RequestLocationCard` là cấu trúc độc lập với thư viện map,
có thể nối map sau. Không cần map API key.

## Package và Android

Thêm dependency trực tiếp `geolocator: ^14.0.2`; lockfile chốt **14.1.1** cùng các
implementation nền tảng do package kéo theo. Hỗ trợ Web và Android theo
[tài liệu geolocator](https://pub.dev/packages/geolocator).

Đã khai báo trong `frontend/customer_app/android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

Android kiểm tra dịch vụ vị trí, quyền hiện có rồi xin quyền khi cần. Từ chối
vĩnh viễn được hướng dẫn mở Cài đặt ứng dụng; không lặp hộp thoại xin quyền.
Chấp nhận quyền vị trí gần đúng. Không thêm quyền vị trí nền hay chạy location stream.
AndroidX đã bật; compileSdk theo Flutter SDK hiện tại là 36 (package yêu cầu ít
nhất 35). Cần thử runtime trên máy/emulator có Location bật.

Web gọi `getCurrentPosition` để trình duyệt xin quyền trực tiếp; không dùng
`requestPermission` của implementation web vì hàm đó gộp lỗi timeout/unavailable
thành từ chối quyền. Web phải chạy trên HTTPS hoặc localhost.

## File thay đổi

| File | Nội dung |
|---|---|
| `frontend/customer_app/pubspec.yaml`, `frontend/customer_app/pubspec.lock` | Dependency và phiên bản khóa |
| `frontend/customer_app/android/app/src/main/AndroidManifest.xml` | Quyền vị trí Android |
| `frontend/customer_app/lib/services/location_service.dart` | Service định vị, phân loại lỗi, kiểu tọa độ dùng lại |
| `frontend/customer_app/lib/screens/new_request_screen.dart` | GPS, trạng thái, nhập tay, truyền tọa độ vào controller |
| `frontend/customer_app/lib/screens/new_tracking_screen.dart` | Hiển thị vị trí đã lưu |
| `frontend/customer_app/lib/widgets/request_location_card.dart` | Card vị trí không cần map |
| `frontend/customer_app/lib/app/app_shell.dart` | Reset form khi đổi danh tính đăng nhập |
| `frontend/customer_app/test/location_service_test.dart` | Quyền, tắt GPS, web, timeout, lỗi và tọa độ không hợp lệ |
| `frontend/customer_app/test/request_location_test.dart` | Trạng thái form, payload, fallback, retry, kết quả muộn, dispose |
| `frontend/customer_app/test/tracking_test.dart` | Tracking có/không tọa độ, bao gồm giá trị 0 |
| `P1_CUSTOMER_LOCATION.md` | Báo cáo và hướng dẫn kiểm thử |

Các file cache sinh tự động `frontend/customer_app/.dart_tool/package_config.json`,
`frontend/customer_app/.dart_tool/package_graph.json`, `frontend/customer_app/.flutter-plugins-dependencies` được cập nhật,
đã nằm trong `.gitignore`.

## Kiểm tra tự động

- `flutter pub get`: đạt, resolve `geolocator 14.1.1`.
- `flutter test`: **28/28 đạt**.
- `flutter build web --no-pub`: **đạt**, gồm bước Wasm dry run.
- `flutter analyze`: **0 error, 4 warning, 46 info; exit code 1**. Các warning
  unused trong `login_screen.dart` cũ và info `withOpacity` deprecated đã tồn tại
  ở P0. Không phải analyzer sạch; không tắt warning/info để báo đạt.

Lưu ý môi trường: chạy trực tiếp ở workspace gặp lỗi quyền cache SDK/ghi lockfile
Windows. Các lệnh Flutter trên chạy bằng SDK 3.47.5 / Dart 3.13.4 trên bản sao
cùng mã nguồn trong thư mục tạm có quyền ghi, không đổi ACL dự án. Lockfile và
metadata package đã đồng bộ về workspace. Test dùng nền tảng/controller giả để
kiểm tra hành vi; chưa xác nhận hộp thoại quyền Chrome/Android hoặc RPC trên backend thật.

## Test thủ công trên Chrome

1. Đảm bảo backend dev đã áp dụng migration P0 và `frontend/customer_app/config/supabase.dev.json`
   có URL/publishable key đúng. Chạy:

   ```powershell
   flutter pub get
   flutter run -d chrome --web-port=7357 --dart-define-from-file=config/supabase.dev.json
   ```

2. Đăng nhập khách không có yêu cầu active. Mở tab **Cứu hộ**, chọn sự cố, nhập
   địa chỉ và liên hệ. Bấm **Lấy vị trí hiện tại**, cho phép Chrome truy cập vị trí.
   Kiểm tra trạng thái đang lấy → đã lấy và tọa độ. Xác nhận vị trí rồi gửi.
   Tab **Đang xử lý** phải hiển thị địa chỉ và cùng cặp tọa độ; tải lại trang vẫn còn.

3. Kiểm tra payload trong DevTools → Network, RPC `create_customer_rescue_request`:
   `p_location_text` là địa chỉ đã nhập, `p_latitude`/`p_longitude` là số.
   Có thể đối chiếu `location_text`, `latitude`, `longitude` của đúng UUID request
   trong Supabase dev. Kết thúc/hủy request trước khi thử tạo request khác.

4. Trong Chrome Site settings → Location, reset quyền rồi bấm lấy vị trí và chọn
   **Block**. Form phải báo từ chối quyền, vẫn gửi được địa chỉ sau khi xác nhận;
   RPC gửi hai tọa độ null và tracking báo dùng địa chỉ nhập tay. Cho phép lại
   quyền rồi bấm **Lấy vị trí hiện tại** để kiểm tra thử lại.

5. DevTools → More tools → Sensors → Location: dùng custom location để kiểm tra
   cặp biết trước, hoặc **Location unavailable** để kiểm tra lỗi. Đây là tọa độ
   giả lập; tắt override để kiểm tra vị trí thiết bị thật. Lỗi vẫn cho gửi địa chỉ.

6. Trong lúc trạng thái đang lấy vị trí, xác nhận địa chỉ rồi gửi luôn. Kết quả GPS
   trả muộn không được gắn vào đơn. Hoặc bấm **Chỉ dùng địa chỉ nhập tay** khi đã có
   GPS rồi gửi: payload phải chứa hai null.

7. Thử đóng/rời form khi đang lấy GPS; thử đăng xuất và đăng nhập khách khác.
   Không có lỗi UI và không giữ tọa độ của khách trước. Sau khi gửi thành công,
   quay lại form để kiểm tra yêu cầu tiếp theo cần lấy GPS mới.

8. Trên Android: kiểm tra Allow while using app, approximate location, Deny,
   từ chối vĩnh viễn và tắt Location. Mỗi trường hợp không lấy được GPS vẫn phải
   gửi cứu hộ bằng địa chỉ thủ công.
