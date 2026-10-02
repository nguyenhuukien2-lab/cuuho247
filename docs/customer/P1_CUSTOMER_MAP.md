# P1 — Bản đồ OpenStreetMap cho app khách hàng

> Đường dẫn đã cập nhật sau khi tổ chức repository. Các đường dẫn file bên dưới tính từ Git root; lệnh Flutter/Dart chạy trong `frontend/customer_app` (từ root: `cd frontend/customer_app`), lệnh Node/tools chạy từ root. Kết quả kiểm thử cũ được giữ theo thời điểm của báo cáo; xem [CLEANUP_REPORT.md](../CLEANUP_REPORT.md) cho kết quả sau di chuyển.

## Dependencies
- `flutter_map: ^8.3.2` (lock: 8.3.2).
- `latlong2: ^0.10.1` (lock: 0.10.1).
- `url_launcher: ^6.3.2` (đã có transitive; khai báo direct để mở trang bản quyền OSM).
- Nâng SDK constraint trong pubspec lên Dart >=3.6.0, Flutter >=3.27.0 theo yêu cầu tối thiểu của flutter_map. Lockfile chốt dependencies theo SDK đang dùng; khi dùng SDK cũ hơn cần giải lại dependencies phù hợp.

## File thêm/sửa
- `frontend/customer_app/pubspec.yaml`, `frontend/customer_app/pubspec.lock`: dependencies/SDK và lockfile.
- `frontend/customer_app/lib/widgets/rescue_location_map.dart`: widget bản đồ chung, OSM tile HTTPS, user agent app, attribution có link và tự xuống hàng, marker, camera, chọn điểm, khóa tương tác khi gửi, lỗi nền map/tải lại.
- `frontend/customer_app/lib/screens/new_request_screen.dart`: map luôn hiện trong form, chọn điểm cập nhật tọa độ và hủy GPS trả muộn; vẫn giữ text địa chỉ bắt buộc và xác nhận vị trí.
- `frontend/customer_app/lib/widgets/request_location_card.dart`: map cho vị trí đã gửi; thiếu/sai tọa độ hiện “Chưa có tọa độ”. Tracking đang dùng widget này nên không cần sửa trực tiếp new_tracking_screen.dart.
- `frontend/customer_app/lib/screens/history_details_screen.dart`: dùng card vị trí/bản đồ; bỏ phần text vị trí bị lặp trong card thông tin chung.
- `frontend/customer_app/test/flutter_test_config.dart`: tile provider bộ nhớ cho toàn bộ widget test, không gọi OSM public trong test.
- `frontend/customer_app/test/rescue_location_map_test.dart`: có/không/sai tọa độ, marker, camera mặc định/GPS, tracking/lịch sử, thao tác chạm map thật gửi tọa độ, loại bỏ GPS trả muộn, không tràn viewport điện thoại.
- `frontend/customer_app/test/request_location_test.dart`, `frontend/customer_app/test/request_failure_test.dart`: tăng viewport cho các state test của form có thêm map.
- `frontend/customer_app/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`: Flutter pub get sinh lại đăng ký plugin theo dependencies; không sửa thủ công logic Android.
- `P1_CUSTOMER_MAP.md`: tài liệu này.

Không sửa backend/RPC, không migration mới. Không thêm Google Maps API key hoặc secret vào repository.

## Hành vi
Form chưa chọn vị trí: camera về Đà Nẵng (16.0544, 108.2022), zoom 12, không marker và không tự gửi tọa độ mặc định. GPS thành công hoặc địa chỉ đã lưu có tọa độ: camera tới điểm đó, zoom 16, có marker.

Chạm map: đặt marker, cập nhật latitude/longitude, yêu cầu xác nhận lại và bỏ kết quả GPS đang chờ. Địa chỉ nhập tay không bị map thay đổi; không reverse geocoding. Form khóa khi đang gửi hoặc đang retry ảnh của request đã tạo. “Chỉ dùng địa chỉ nhập tay” bỏ tọa độ; gửi thành công cũng bỏ tọa độ trước đơn sau như luồng hiện có.

Tracking/lịch sử có cặp tọa độ hợp lệ sẽ có map và marker vị trí cứu hộ đã gửi. Không có cặp tọa độ hợp lệ thì hiện “Chưa có tọa độ”. Không bổ sung vị trí người cứu hộ hoặc cập nhật GPS liên tục.

Map cao 240px, rộng theo card; text/ghi công có thể xuống hàng trên điện thoại. Cần Internet để tải nền map. Nếu lỗi tải tile: hiện thông báo và nút Tải lại bản đồ; vẫn có thể nhập địa chỉ hoặc lấy GPS.

## Nguồn/tile
- Tiles: https://tile.openstreetmap.org/{z}/{x}/{y}.png
- Ghi công có link tới https://www.openstreetmap.org/copyright
- User-Agent package: com.cuuho247.customer (trình duyệt quản lý User-Agent/Referer trên web).
- Giữ caching mặc định của NetworkTileProvider; không bulk download/prefetch/offline tiles.
- Tài liệu: https://docs.fleaflet.dev/layers/tile-layer
- Chính sách tile public: https://operations.osmfoundation.org/policies/tiles/

## Chrome
```powershell
flutter pub get
flutter run -d chrome --dart-define-from-file=config/supabase.dev.json
```
1. Mở tab Cứu hộ: thấy nền Đà Nẵng, chưa có marker. Không tự xin quyền GPS.
2. Nhập địa chỉ, chọn sự cố, bấm Lấy vị trí hiện tại và cấp quyền: camera tới GPS, có marker và text tọa độ.
3. Chạm điểm khác trên bản đồ: marker/tọa độ thay đổi; checkbox xác nhận bị bỏ chọn. Text địa chỉ vẫn còn. Xác nhận lại, gửi; kiểm tra latitude/longitude request và map trong tracking.
4. Chọn điểm khi GPS đang chờ: GPS trả sau đó không được ghi đè điểm đã chọn.
5. Để địa chỉ rỗng dù đã chọn điểm: không gửi được. Chọn Chỉ dùng địa chỉ nhập tay: gửi request không có tọa độ; tracking hiện “Chưa có tọa độ”.
6. Địa chỉ đã lưu có tọa độ: chọn từ dropdown, map tới địa chỉ đó. Chọn địa chỉ không có tọa độ: bỏ marker cũ.
7. Mở Lịch sử → chi tiết đơn có tọa độ: map và marker đúng; đơn cũ không tọa độ có empty state.
8. Tắt mạng/chặn tile.openstreetmap.org: map báo lỗi nền và có nút tải lại. Form text/GPS không bị mất. Bật mạng và thử Tải lại bản đồ.

## Điện thoại web
```powershell
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080 --dart-define-from-file=config/supabase.dev.json
```
Mở `http://<IP-LAN-máy-tính>:8080` trên điện thoại cùng Wi-Fi để kiểm tra tile, pan/zoom, chạm chọn điểm, cuộn form, bàn phím và các card tracking/lịch sử. Thử chiều rộng 360–390px; không được có overflow hay cuộn ngang.

Để thử GPS thật trên điện thoại dùng bản web phục vụ qua HTTPS; HTTP qua IP LAN thường không cho geolocation. Chrome máy tính ở localhost có thể xin quyền GPS. Chọn điểm bằng map không cần quyền GPS.

## Kiểm tra tự động
```powershell
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```
Widget tests dùng tile trong bộ nhớ: kiểm tra map/marker/camera/tap/state thật, không chứng minh tile server đang phục vụ hoặc GPS của thiết bị. Chưa kiểm thử tương tác trực tiếp trên Chrome/điện thoại trong phiên này.

Kết quả cuối:
- `flutter pub get`: exit code 0.
- `flutter analyze --no-fatal-infos --no-fatal-warnings --no-pub`: exit code 0, không error; còn 4 warning unused và 46 info deprecated trong mã cũ. Dùng --no-pub vì đã chạy pub get riêng trước đó.
- `flutter test --no-pub`: 108 test pass, exit code 0 (98 test trước đó + 10 test map mới).
- Chưa chạy kiểm thử tương tác trực tiếp trên Chrome/điện thoại hoặc kiểm tra tile/GPS thật tại runtime.
