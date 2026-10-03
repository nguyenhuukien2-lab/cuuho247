# Giai đoạn 4 — Báo giá, hoàn tất và lịch sử

Chỉ thay đổi rescuer_app. Dùng session Auth và publishable/anon key trong
`config/supabase.dev.json`; không áp migration hoặc thay đổi customer app.

## Hành vi

- Chuyến `in_progress` chưa có báo giá: nhập phí chính bắt buộc, phụ thu mặc định
  0 và ghi chú tùy chọn. Tiền nguyên VND không âm; tổng tối đa 2.147.483.647,
  ghi chú tối đa 1.000 ký tự. Form hướng dẫn nhập số không có dấu phân cách.
- Sau gửi: snackbar “Đã gửi báo giá”, làm mới chuyến, hiển thị tổng tiền,
  các dòng và ghi chú từ phản hồi RPC đã được kiểm tra quyền lại. Khi chuyến
  đã có `current_quote_id`, không hiện form gửi thêm để tránh tạo revision vô ý.
- Chuyến `in_progress` có báo giá: nút Hoàn tất chuyến mở xác nhận và tổng tiền.
  Chỉ gửi khi ID, version, mã báo giá và tổng tiền khớp dữ liệu đã xác nhận.
- Hoàn tất thành công: snackbar “Đã hoàn tất chuyến”, xóa dữ liệu chuyến/khách
  đang giữ, làm mới chuyến, chuyển sang Lịch sử và tải dữ liệu thật.
- Lịch sử gồm chuyến completed/cancelled, dịch vụ, loại xe, thời gian, chi phí,
  phân trang, chi tiết sự kiện; có loading/empty/error và nút thử lại.
- Khóa thao tác trong khi xử lý. Xung đột version/trạng thái, RPC/RLS và lỗi
  mạng có thông báo. Mất phản hồi được đối chiếu dữ liệu server trước khi cho
  tiếp tục, không tự gửi lại báo giá hoặc tự tăng trạng thái.
- Dữ liệu báo giá/lịch sử bị xóa khi đổi tài khoản; phản hồi của phiên cũ bị bỏ.

## RPC và contract

| RPC | Tham số dùng |
| --- | --- |
| `rescuer_create_quote` | `p_assignment_id`, `p_items`, `p_note`, `p_expected_version`, `p_operation_id` |
| `rescuer_get_active_job` | Không có tham số |
| `rescuer_update_job_status` | `p_assignment_id`, `p_target_state: completed`, `p_reason_code: null`, `p_expected_version`, `p_operation_id` |
| `rescuer_list_job_history` | `p_limit: 20`, `p_cursor`, `p_state_filter: null` |
| `rescuer_get_job_history` | `p_assignment_id` |

Mỗi item báo giá chỉ có `service_code`, `quantity: 1`, `unit_price_vnd`.
Phí chính và phụ thu là hai dòng cùng mã dịch vụ thực tế của đơn, đúng điều
kiện backend. Phụ thu bằng 0 không tạo dòng thứ hai. UUID operation được
service giữ khi lỗi transport, dùng cùng UUID nếu retry cùng payload trong phiên.
Backend yêu cầu báo giá issued trước khi chuyển từ in_progress sang completed.
RPC hoàn tất cập nhật `rescue_requests.status = completed`; báo giá cập nhật
`quoted_price`. Customer nhận thay đổi qua realtime/refresh hiện có; chưa test
luồng giai đoạn 4 giữa hai điện thoại trong lượt triển khai này.

## Giới hạn được thể hiện trên UI

- `rescuer_get_active_job` trả mã báo giá, tổng tiền và tiền tệ, không trả items/
  note; chưa có public RPC đọc lại chi tiết quote. Sau mở lại app hoặc tải lại
  toàn bộ hồ sơ, UI hiện tổng tiền và giải thích chưa tải lại được dòng phí/ghi
  chú. Không đọc trực tiếp bảng quotes/assignments vốn chỉ cấp quyền qua RPC.
- Backend chưa nhận ghi chú hoàn tất. Dialog có trường ghi chú bị khóa kèm
  hướng dẫn; không gửi tham số ngoài contract hoặc giả báo đã lưu.
- RPC lịch sử không trả địa chỉ, liên hệ hoặc ghi chú tự do. UI không hiển thị
  các trường này, chỉ dùng projection backend cho phép.
- Không làm thanh toán, sửa báo giá đã gửi, hủy chuyến hoặc thống kê nâng cao.

## Kiểm tra trên điện thoại

Từ thư mục rescuer_app:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/supabase.dev.json
flutter run -d <android-device-id> --dart-define-from-file=config/supabase.dev.json
```

APK: `build/app/outputs/flutter-apk/app-debug.apk`. Nếu ổ C thiếu dung lượng,
dùng cache/temp riêng như README và thêm
`$env:JAVA_TOOL_OPTIONS = "-Djava.io.tmpdir=$rescuerTemp"` trước build.

1. Tạo đơn trên customer, rescuer nhận và cập nhật tới Đang hỗ trợ khách.
2. Thử gửi phí chính trống, số âm, số thập phân, tổng vượt giới hạn; không có
   RPC ghi dữ liệu. Nhập 100000, phụ thu 20000, ghi chú; gửi một lần.
3. Kiểm tra tổng 120.000 ₫, snackbar, form được thay bằng báo giá đã gửi.
   Mở lại app: tổng tiền vẫn lấy từ server, giới hạn chi tiết được ghi rõ.
4. Bấm Hoàn tất, kiểm tra chi phí; Quay lại không đổi trạng thái. Xác nhận:
   loading, không bấm lặp; chuyến xuất hiện Lịch sử, Đang xử lý không còn PII.
5. Trên customer kiểm tra completed qua realtime hoặc tải lại đơn. Kiểm tra
   quoted_price trong UI customer nếu màn hiện tại có hỗ trợ.
6. Mất mạng, xung đột do phiên khác và lỗi quyền: có thông báo, làm mới để
   đối chiếu trạng thái thật. Lịch sử rỗng/lỗi quyền có hướng dẫn và thử lại.

Test tự động dùng fake/mock, không tạo đơn hoặc hoàn tất chuyến trên Supabase thật.
