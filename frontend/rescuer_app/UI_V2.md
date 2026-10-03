# Giao diện đối tác — UI V2

## Tham chiếu

Thư mục được yêu cầu `frontend/rescuer_app/design_refs/ui_v2` hiện trống.
Đã đọc cả 5 ảnh có trong `design_refs/rescuer_app`: home_ref.png,
orders_ref.png, active_job.png, history_ref.png, account_ref.png.
Hai ảnh orders_ref/active_job có nội dung màn đảo nhau; thiết kế bám nội dung ảnh.
Không sửa hoặc sao chép ảnh tham chiếu vào luồng app.

## Màn hình

- Đăng nhập: header navy, khối thương hiệu, form/Auth và lỗi hiện có.
- Trang chủ: hồ sơ navy, xét duyệt thật, trạng thái phát tín hiệu, radar/GPS,
  checklist 6 điều kiện, CTA bật online/hoàn thiện/xem đơn hoặc mở chuyến.
- Đơn mới: GPS đồng bộ, bộ lọc dịch vụ local, mã đơn, xe, vị trí coarse,
  khoảng cách thật và nút nhận đơn. Bỏ qua chỉ ẩn trên thiết bị trong phiên;
  có nút hiện lại, không gọi RPC từ chối/hủy hoặc xóa danh sách server.
- Đang xử lý: status navy, timeline 5 bước (in_progress có hướng dẫn hỗ trợ),
  thông tin backend cho phép, card điểm cứu hộ, gọi điện/Google Maps bên ngoài,
  báo giá với tổng tiền dự kiến từ số người dùng nhập, nút tiến độ ở cuối màn.
- Lịch sử: summary các chuyến đã tải, tổng chi phí báo giá chuyến completed,
  bộ lọc completed/cancelled local, cards thật, phân trang/chi tiết/empty/error.
  Summary ghi rõ còn dữ liệu chưa tải nếu có cursor; không xem báo giá như tiền
  đã thanh toán hoặc thống kê toàn hệ thống.
- Tài khoản: hồ sơ, phương tiện, capability, giấy tờ, xét duyệt, GPS và các lối
  mở form hiện có. Các nút chỉnh sửa cuộn tới form. Đăng xuất dùng xác nhận và
  controller cũ. Mục bảo mật/hỗ trợ giải thích chức năng/kênh chưa cấu hình;
  không tạo hotline hoặc thao tác đổi mật khẩu giả.

Bottom navigation giữ đúng index: 0 Trang chủ, 1 Đơn mới, 2 Đang xử lý,
3 Lịch sử, 4 Tài khoản. Nhận đơn mở index 2; hoàn tất mở index 3.

## Component và phạm vi

Theme: navy #0B2540, cam #FF5A1F, nền #F5F7FA, text phụ tăng tương phản.
AppCard/PreparationCard, AppButton (56px), StatusBadge, empty states và
NavigationBar dùng lại và được polish. Component mới: PartnerHeader,
NavyPanel, PartnerHero, GpsSignalCard, LocalFilterBar, MetricCard,
AccountOverview; timeline có TimelineStep dùng chung.

Không thay đổi controller, model dữ liệu, service hoặc tên/payload RPC;
không sửa customer app/backend/migration; không service_role, không commit.
`url_launcher` được khai báo trực tiếp ở phiên bản 6.3.3 vốn đã có trong lock
để mở ứng dụng gọi điện/bản đồ; lỗi không mở được có snackbar và vẫn giữ chuyến.

Trước nhận đơn chỉ dùng AvailableRequest projection. Không hiển thị tên,
phone, địa chỉ chính xác, mô tả hoặc ảnh khách. Sau nhận, các nút gọi/bản đồ
chỉ dựng từ ActiveJob đã được backend xác nhận quyền; lịch sử không thêm PII.

Ẩn rating, ETA, ping, độ chính xác GPS cụ thể, địa chỉ lịch sử, doanh thu đã
thanh toán và hiệu suất ca khi chưa có nguồn dữ liệu thật. Không giả số liệu
tham chiếu. Bản đồ trong app là card vị trí ghi rõ chưa tích hợp; Google Maps
mở bằng tọa độ thật nếu backend trả. Giới hạn quote/ghi chú hoàn tất của PHASE4
vẫn giữ nguyên; không giả khách đã xác nhận báo giá.

## File thay đổi (tính từ rescuer_app)

- lib/app/app_theme.dart
- lib/widgets/app_components.dart
- lib/screens/preparation/preparation_screen.dart
- lib/screens/preparation/preparation_forms.dart
- lib/screens/preparation/active_job_panel.dart
- lib/screens/preparation/job_progress_timeline.dart
- lib/screens/preparation/job_finance_section.dart
- lib/screens/preparation/history_panel.dart
- lib/screens/preparation/account_overview.dart (mới)
- lib/screens/preparation/ui_v2_components.dart (mới)
- pubspec.yaml, pubspec.lock
- test/claim_request_test.dart (scroll đúng viewport sau thay đổi layout)
- test/connected_app_test.dart (nhãn nút nhận đơn mới)
- test/job_status_test.dart (chờ snackbar đóng trước khi bấm CTA cuối màn)
- test/ui_v2_test.dart (mới: navigation 5 tab, lọc/bỏ qua local, viewport 320px)
- README.md, UI_V2.md (mới)

## Kiểm tra nhanh

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/supabase.dev.json
flutter run -d <android-device-id> --dart-define-from-file=config/supabase.dev.json
```

Nếu cần cache/temp trên D, xem README. APK:
`build/app/outputs/flutter-apk/app-debug.apk`.

1. Đăng nhập; kiểm tra 5 tab và các trạng thái hồ sơ nháp/chờ duyệt/approved.
2. Tài khoản: mở chỉnh sửa hồ sơ, xe, dịch vụ, upload giấy tờ; thao tác giữ RPC
   hiện có, thay đổi đã duyệt vẫn có cảnh báo cần duyệt lại.
3. Trang chủ: xin quyền GPS, online/offline, thử từ chối quyền/mất mạng.
4. Đơn mới: lọc dịch vụ, Bỏ qua, hiện lại. Trước nhận không có PII. Nhận đơn
   thật phải chuyển Đang xử lý, sau đó mới hiển thị liên hệ/điểm cứu hộ.
5. Tiến độ: accepted → en_route → arrived → in_progress; thử Google Maps/gọi
   điện nếu có dữ liệu. Form báo giá hiện tổng dự kiến và validate như trước.
6. Gửi quote → xác nhận hoàn tất → Lịch sử; kiểm tra trạng thái bên customer.
   Thử lọc lịch sử, xem chi tiết, mất mạng/empty/RLS và refresh.

Test tự động dùng fake/mock, không ghi Supabase thật. Có thể tạo ảnh render
fixture bằng `RESCUER_UI_PREVIEWS=1` và đặt `RESCUER_FONT_DIR` tới thư mục
`bin/cache/artifacts/material_fonts` của Flutter SDK, rồi chạy ui_v2_test.dart.
Ảnh lưu ở `build/ui_v2_previews/`, được Git bỏ qua. Đây là dữ liệu test dùng để
review bố cục, không phải số liệu đối tác thật hoặc asset của production.
