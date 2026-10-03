# Giai đoạn 3: Cập nhật tiến độ chuyến

Chỉ thay đổi rescuer_app. Không sửa customer_app/backend/migration, không dùng
service_role, không push database và không commit tự động.

## Trạng thái và UI

| Assignment RPC | UI người cứu hộ | Nút tiếp theo | rescue_requests.status phía khách |
| --- | --- | --- | --- |
| accepted | Đã nhận đơn | Đang đến điểm cứu hộ | accepted |
| en_route | Đang đến điểm cứu hộ | Đã đến nơi | arriving |
| arrived | Đã đến nơi | Bắt đầu hỗ trợ | arriving |
| in_progress | Đang hỗ trợ khách | Không có thao tác bước sau | in_progress |

Backend hiện hỗ trợ `arrived` riêng trong assignment. Không gửi `arriving` làm
target assignment; đây là trạng thái đơn khách được RPC map từ en_route/arrived.
Customer hiện có subscription theo đơn; không cần viết status từ frontend khách.

Màn Đang xử lý có badge trạng thái, timeline bốn bước với bước hiện tại màu cam,
bước đã qua có check xanh, các bước sau màu nhạt. Mốc giờ lấy từ accepted_at,
en_route_at, arrived_at, in_progress_at do backend trả; không tự tạo giờ sự kiện.
Có hướng dẫn “Cập nhật trạng thái để khách hàng theo dõi tiến độ”. Nút thao tác
lớn, loading và disable trong lúc RPC chạy. Thành công/lỗi đều có snackbar.

## RPC và xử lý lỗi

`rescuer_update_job_status` gửi đúng contract:

```text
p_assignment_id: assignment hiện đang xem
p_target_state: bước liền kề en_route / arrived / in_progress
p_reason_code: null
p_expected_version: version vừa đọc từ server
p_operation_id: UUID do service quản lý
```

- Chỉ cho tiến từng bước; controller tự chọn bước tiếp theo theo state hiện tại.
  Service chặn target completed/cancelled và reason khác null trong giai đoạn này.
- Không yêu cầu online discovery để quản lý chuyến đã nhận; RPC kiểm tra quyền
  theo Auth/assignment/profile. Không ghi trực tiếp bảng đơn hoặc assignment.
- Sau ACK, đọc `rescuer_get_active_job()` và dùng trạng thái/version mới. Không
  giữ PII cache khi kiểm tra lại quyền. Nếu chi tiết lỗi, giữ metadata trạng thái
  đã được xác nhận và hiện lỗi tải lại; khóa nút cho đến khi đọc chuyến thành công.
- VERSION_CONFLICT: tải lại chuyến và thông báo có phiên khác cập nhật, không tự
  retry hoặc nhảy sang bước sau. INVALID_STATUS_TRANSITION/RLS/RPC thiếu: thông
  báo dễ hiểu, không crash. REQUEST_UNAVAILABLE: kiểm tra lại chuyến và bỏ PII
  nếu backend trả null/lỗi quyền.
- Mất phản hồi transport: kiểm tra cùng assignment và version mới để đồng bộ
  cập nhật đã commit. Nếu trạng thái chưa đổi, retry cùng payload trong phiên app
  giữ cùng operation UUID. Không bảo đảm operation cache qua restart; chuyến
  được đọc lại từ backend khi mở app.
- Đổi Auth/logout trong lúc RPC chạy không khôi phục dữ liệu hoặc thông báo từ
  phản hồi cũ. Discovery vẫn chỉ chứa projection coarse, không thêm PII trước nhận.

Không gọi RPC báo giá, hoàn tất hoặc hủy chuyến, không thêm lịch sử nâng cao.

## Test trên điện thoại

APK: `build/app/outputs/flutter-apk/app-debug.apk`. Hoặc chạy từ rescuer_app:

```powershell
flutter run -d <android-device-id> --dart-define-from-file=config/supabase.dev.json
```

1. Với chuyến thật đã nhận, mở Đang xử lý. Kiểm tra Đã nhận đơn và bốn bước timeline.
2. Bấm Đang đến điểm cứu hộ. Kiểm tra loading/khóa bấm lặp, snackbar, bước Đang
   di chuyển màu cam; phía khách nhận status arriving qua realtime hoặc tải lại.
3. Bấm Đã đến nơi. Rescuer thấy arrived và mốc giờ; phía khách vẫn là arriving
   theo contract backend hiện có.
4. Bấm Bắt đầu hỗ trợ. Kiểm tra in_progress / Đang hỗ trợ khách và phía khách
   chuyển in_progress. Không có nút báo giá/hoàn tất trong giai đoạn này.
5. Đăng xuất/đăng nhập hoặc mở lại app, kiểm tra trạng thái và timeline phục hồi.
6. Thử mất mạng khi cập nhật rồi kết nối lại/tải lại. Với hai phiên cùng rescuer,
   thử cập nhật từ dữ liệu cũ: app phải báo version conflict và tải lại state,
   không tự tiến thêm một bước.

Giai đoạn 2 nhận đơn trên điện thoại đã được người dùng xác nhận OK. Giai đoạn 3
chưa được kiểm tra end-to-end trên điện thoại với hai tài khoản thật trong phiên
này; các tests dưới đây không mutate Supabase thật.

## Kiểm tra

- flutter pub get: thành công với cache/temp riêng ổ D (xem README).
- flutter analyze --no-pub: không issue.
- flutter test --no-pub --concurrency=1: 39 test đạt; thêm 10 test về chuyển ba
  bước, version conflict, invalid transition, lost response, ACK rồi lỗi chi tiết,
  quyền/PII/logout, khóa nút, timeline/snackbar và RPC retry cùng UUID.
- flutter build apk --debug --dart-define-from-file=config/supabase.dev.json:
  thành công. Còn warning KGP từ file_picker/package_info_plus và Java native access.
- git status --short / git diff --check: đã kiểm tra. Customer/backend không có
  diff; SHA256 migration giữ nguyên
  `9381B39D448662F8A034D962E17BED320478DDA617B308B5497F388C521BC015`.

## File thay đổi

- lib/models/backend_models.dart: trạng thái tiếp theo, label, timestamps timeline.
- lib/services/rescuer_service.dart: allowlist RPC và error mapping.
- lib/app/rescuer_controller.dart: version, mutation/reconciliation, thông báo.
- lib/screens/preparation/preparation_screen.dart: listener snackbar trạng thái.
- lib/screens/preparation/active_job_panel.dart: action/loading/hướng dẫn.
- lib/screens/preparation/job_progress_timeline.dart: timeline.
- test/job_status_test.dart: controller/UI/HTTP tests.
- README.md và PHASE3.md: hướng dẫn và kết quả kiểm tra.
