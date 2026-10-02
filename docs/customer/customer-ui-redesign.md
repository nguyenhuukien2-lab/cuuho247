# Báo cáo thiết kế lại UI/UX app khách hàng Cứu Hộ 24/7

> Đường dẫn đã cập nhật sau khi tổ chức repository. Các đường dẫn file bên dưới tính từ Git root; lệnh Flutter/Dart chạy trong `frontend/customer_app` (từ root: `cd frontend/customer_app`), lệnh Node/tools chạy từ root. Kết quả kiểm thử cũ được giữ theo thời điểm của báo cáo; xem [CLEANUP_REPORT.md](../CLEANUP_REPORT.md) cho kết quả sau di chuyển.

Ngày thực hiện: 02/10/2026. Workspace: `D:\DAndroidStudioProjects\flutter_app`.

## Vấn đề ở giao diện trước

- Header và các khối thông tin có độ nổi bật gần như nhau; logo, lời chào và nội dung phụ dùng nhiều chiều cao.
- Nhiều section cùng một kiểu card, đôi khi lồng card, khiến khó xác định hành động chính và thứ tự đọc.
- Form dài, phần chọn dịch vụ/phương tiện/vị trí chưa tách rõ; hành động gửi nằm xa và lỗi liên hệ có thể ở ngoài viewport.
- Lịch sử dùng khối thông tin lớn thay vì các dòng dễ quét; chi tiết cần gom theo cấu trúc biên nhận.
- Hồ sơ và các trang quản lý thiếu cùng một kiểu header, input, trạng thái lỗi và CTA.
- Bố cục phải thích nghi với nhãn tiếng Việt dài, chữ phóng lớn, safe area và bàn phím; thay đổi màu/bo góc đơn thuần không giải quyết các vấn đề này.

## Thiết kế đã áp dụng

- Material 3, Roboto, nền sáng, navy `#123B66`, cam `#E85D04`, màu và spacing tập trung trong theme. CTA cam dùng chữ tối để đáp ứng tương phản; trạng thái nhấn cam đậm dùng chữ trắng.
- Trang chủ: header gọn, hero navy, CTA cứu hộ cam; đủ năm dịch vụ theo hai cột; lựa chọn phương tiện riêng. Đơn hoạt động dùng trạng thái thật và mở tracking.
- Cứu hộ: các section mở thay vì mỗi section một card; dịch vụ có selected state; input xe và địa chỉ đồng nhất; GPS/bản đồ/địa chỉ đã lưu trong cùng nhóm; ba ô ảnh; xác nhận ngay trước hành động gửi.
- CTA gửi cố định ở đáy vùng nội dung, loading giữ kích thước. Form giữ các input được mount để validation, focus và cuộn tới trường lỗi hoạt động cả khi trường nằm ngoài màn hình. Bàn phím và NavigationBar không chiếm vùng cuộn của nội dung.
- Đang xử lý: trạng thái lớn, timeline ngay bên dưới; địa chỉ/bản đồ tiếp theo; thông tin đơn theo label/value, ảnh riêng, hủy có xác nhận và lỗi gần hành động. Chỉ hiển thị thời gian cập nhật khi response thực sự có `updated_at`.
- Lịch sử: segmented filter, nhóm theo ngày thật, row gọn bấm được toàn bộ; trạng thái chip; địa chỉ tối đa hai dòng; chỉ hiển thị chi phí có dữ liệu.
- Chi tiết: bố cục biên nhận, section địa điểm/ảnh/timeline riêng; đánh giá chỉ cho completed, sao có vùng bấm 48px.
- Tài khoản: profile gọn, tên viết hoa đầu từ chỉ khi hiển thị; settings list cho xe/địa chỉ; đăng xuất tiết chế. Editor có app bar, input và CTA đồng nhất. Dialog xóa nêu tên đối tượng và hậu quả.
- Năm tab dùng IndexedStack, nhãn tiếng Việt 11px, NavigationBar 72px cộng safe area; fade 180ms và tôn trọng reduce motion. Đổi tab đóng bàn phím nhưng giữ draft.
- Bản đồ cho phép chọn điểm, zoom và GPS; kéo dọc trên bản đồ cuộn trang thay vì giữ thao tác. Không thêm gradient, animation lặp, dữ liệu vận hành giả hoặc chức năng chưa triển khai.
- Loading, lỗi có thử lại, empty CTA, disabled/pressed/focused/selected state dùng chung thành phần và theme. Lỗi tại section được hiển thị ngay trong nội dung.

## Nghiệp vụ được giữ

Auth/session, GPS, OpenStreetMap, Realtime và vòng đời subscription, ảnh/chụp/thư viện, quản lý xe/địa chỉ, lịch sử và đánh giá tiếp tục dùng các controller/repository/service hiện có. Không sửa schema, RPC, RLS, migration hoặc thêm dependency; không triển khai người cứu hộ, admin hay thanh toán.

Validation địa chỉ vẫn trim và chặn rỗng/khoảng trắng trước controller/service/RPC; GPS không thay thế địa chỉ bằng chữ; chọn địa chỉ đã lưu và sửa tay gửi nội dung controller mới nhất; chỉ dùng địa chỉ tay chỉ xóa tọa độ. Dữ liệu và ảnh giữ khi lỗi, validation client không tạo clientRequestId mới. Các test idempotency, retry ảnh và ánh xạ LOCATION_REQUIRED tiếp tục qua.

Thay đổi model chỉ thêm đọc các giá trị liên hệ tùy chọn và dấu hiệu có thời gian cập nhật thật. Giá trị fallback updatedAt cho logic sắp xếp/Realtime được giữ, giao diện không trình bày fallback như thời gian cập nhật từ máy chủ. Không đổi lời gọi backend.

Số lượng xe/địa chỉ chỉ trình bày ở trang quản lý sau khi tải thành công; trang tài khoản không tạo số lượng giả vì state hiện tại không có danh sách dùng chung.

## File sửa/thêm

Có 31 file mã/test trong lượt thiết kế lại. Thêm mới `frontend/customer_app/lib/widgets/customer_ui.dart` và `frontend/customer_app/test/customer_redesign_test.dart`; các file còn lại được sửa. Báo cáo này là một file tài liệu bổ sung.

- `frontend/customer_app/lib/app/app_theme.dart`
- `frontend/customer_app/lib/app/app_shell.dart`
- `frontend/customer_app/lib/app/app_controller.dart`
- `frontend/customer_app/lib/widgets/customer_ui.dart`
- `frontend/customer_app/lib/widgets/rescue_widgets.dart`
- `frontend/customer_app/lib/widgets/form_section.dart`
- `frontend/customer_app/lib/widgets/saved_address_picker.dart`
- `frontend/customer_app/lib/widgets/saved_vehicle_picker.dart`
- `frontend/customer_app/lib/widgets/customer_profile_card.dart`
- `frontend/customer_app/lib/widgets/request_photos_card.dart`
- `frontend/customer_app/lib/widgets/customer_request_review_card.dart`
- `frontend/customer_app/lib/widgets/request_location_card.dart`
- `frontend/customer_app/lib/widgets/request_timeline.dart`
- `frontend/customer_app/lib/widgets/rescue_location_map.dart`
- `frontend/customer_app/lib/screens/new_home_screen.dart`
- `frontend/customer_app/lib/screens/new_request_screen.dart`
- `frontend/customer_app/lib/screens/new_tracking_screen.dart`
- `frontend/customer_app/lib/screens/new_history_screen.dart`
- `frontend/customer_app/lib/screens/history_details_screen.dart`
- `frontend/customer_app/lib/screens/new_account_screen.dart`
- `frontend/customer_app/lib/screens/new_auth_screen.dart`
- `frontend/customer_app/lib/screens/customer_vehicles_screen.dart`
- `frontend/customer_app/lib/screens/customer_saved_addresses_screen.dart`
- `frontend/customer_app/test/app_shell_test.dart`
- `frontend/customer_app/test/history_details_test.dart`
- `frontend/customer_app/test/customer_profile_card_test.dart`
- `frontend/customer_app/test/request_address_validation_test.dart`
- `frontend/customer_app/test/customer_vehicles_test.dart`
- `frontend/customer_app/test/tracking_test.dart`
- `frontend/customer_app/test/mobile_ui_test.dart`
- `frontend/customer_app/test/customer_redesign_test.dart`

## Kiểm tra thực hiện

```powershell
flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
flutter test --no-pub
```

- Analyze: exit code 0, không có error; còn 44 vấn đề có sẵn (4 warning, 40 info) tại các màn hình cũ. Không có diagnostic trong các file giao diện đang sửa.
- Toàn bộ test: **165/165 qua**, exit code 0. Log: `frontend/customer_app/build/ui_full_test.log`.
- Test layout bao gồm 360×800 và 390×844, text scale 1.0/1.3, safe area trên 28px/dưới 20px, bàn phím 300px; năm tab và giữ draft, validation/focus, địa chỉ dài, ba ảnh, timeline, lịch sử, đánh giá, tài khoản và editor.
- Test mới kiểm tra palette/tương phản chữ chính, nhãn NavigationBar không ellipsis, vùng bấm dịch vụ/sao, reduce motion, validation khi input ngoài viewport và cuộn trang bằng kéo trên map.
- Test nghiệp vụ cũ được giữ; các điều chỉnh finder theo UI mới không bỏ assertion controller/service, idempotency hoặc ảnh.
- Đọc nghiêm ngặt UTF-8: 31/31 file mã/test hợp lệ; không tìm thấy chuỗi mojibake trong phạm vi này.
- Xuất ảnh render với Roboto/MaterialIcons thật từ SDK và xem trực tiếp các màn: trang chủ, form, lỗi liên hệ, tracking, lịch sử, tài khoản, đăng nhập và editor hồ sơ với bàn phím. 13/13 test xuất ảnh qua; đây là render widget test.
- Ảnh review nằm trong `frontend/customer_app/build/ui_review`; log xuất ảnh: `frontend/customer_app/build/ui_capture_test.log`.

Lệnh xuất lại ảnh:

```powershell
flutter test --no-pub --dart-define=CAPTURE_CUSTOMER_UI=true test/customer_redesign_test.dart
```

Test sử dụng tile provider xác định sẵn, không gọi tile OpenStreetMap công khai. Các giá trị minh họa trong ảnh là fixture test, không được đưa vào app. Map nền trống trong ảnh review không phản ánh việc tải bản đồ trên điện thoại.

Thư mục tạm cho các lượt test trên máy này đặt ở `frontend/customer_app/build/test_temp` trên ổ D vì ổ C không còn đủ dung lượng; không đổi cấu hình app.

## Chưa kiểm thử trực tiếp

Chưa chạy trên OPPO CPH1931 hoặc thiết bị thật, chưa kiểm thử backend Supabase thật trong lượt này. Widget test và ảnh render không đủ để kết luận chất lượng trải nghiệm thực tế hoặc mức sẵn sàng phát hành.

Cần thử trực tiếp trên OPPO: giọt nước/safe area và font hệ thống; bàn phím ColorOS; cuộn/chọn điểm/zoom/tải tile; GPS và quyền; camera/thư viện và phục hồi ảnh; mạng yếu; tạo đơn/ảnh retry; Realtime khi nền/foreground; đăng nhập/đăng xuất và các editor. Đối chiếu trạng thái, thời gian, liên hệ và chi phí với dữ liệu thật.

Lệnh chạy lại với mã thiết bị người dùng đã cung cấp:

```powershell
$env:TEMP="D:\FlutterTemp"
$env:TMP="D:\FlutterTemp"
flutter run --debug --no-pub -d 86ab44a0 --dart-define-from-file=config/supabase.dev.json
```
