# Quản lý xe khách hàng

> Đường dẫn đã cập nhật sau khi tổ chức repository. Các đường dẫn file bên dưới tính từ Git root; lệnh Flutter/Dart chạy trong `frontend/customer_app` (từ root: `cd frontend/customer_app`), lệnh Node/tools chạy từ root. Kết quả kiểm thử cũ được giữ theo thời điểm của báo cáo; xem [CLEANUP_REPORT.md](../CLEANUP_REPORT.md) cho kết quả sau di chuyển.

Tab **Tài khoản → Phương tiện của tôi** cho phép xem, thêm, sửa và xóa xe.
Form cứu hộ có mục **Xe đã lưu (tùy chọn)**; chọn phương tiện thủ công sẽ bỏ ID
xe đã lưu. Các loại phương tiện: xe máy, ô tô, xe tải, khác.

## Migration cần áp dụng

`backend/supabase/migrations/202610010003_customer_vehicles.sql` cần được áp dụng sau
ba migration hiện có, trước khi sử dụng chức năng này trên Supabase thật.
Migration chưa được tự động áp lên server trong phiên làm việc này.

- Giữ `display_name` để lưu hãng/hiệu xe, `license_plate` để lưu biển số.
- Thêm `color`, `notes`, đều có thể để trống; giữ nguyên dữ liệu xe cũ.
- Mở rộng ràng buộc `customer_vehicles.kind` và `rescue_requests.vehicle_kind`.
- Thay nội dung RPC cùng chữ ký `create_customer_rescue_request`: kiểm tra xe
  thuộc `auth.uid()`, lấy loại xe từ DB và khóa row trong khi tạo yêu cầu.
- Giữ kiểm tra dịch vụ, vị trí, thông tin liên hệ, idempotency và một đơn active.
- Không thêm grant/policy, không tắt RLS. CRUD chỉ dùng JWT khách hàng.
- Xóa xe khiến `rescue_requests.vehicle_id` thành null theo FK hiện có; loại xe
  của yêu cầu và lịch sử vẫn giữ nguyên.

## Kiểm thử Chrome

```powershell
flutter run -d chrome --dart-define-from-file=config/supabase.dev.json
```

1. Đăng nhập tài khoản thử A; mở Tài khoản → Phương tiện của tôi.
2. Kiểm tra empty state; thêm đủ bốn loại, nhập hãng/hiệu, biển số, màu, ghi chú.
3. Thử bỏ trống hãng/hiệu; form phải báo lỗi. Các thông tin khác được để trống.
4. Sửa một xe, tải lại trang; dữ liệu phải được giữ trong `customer_vehicles`.
5. Xóa: chọn Giữ lại thì dữ liệu không đổi; xác nhận Xóa xe thì xe biến mất.
6. Tạo cứu hộ: chọn xe đã lưu, điền liên hệ/địa chỉ và xác nhận vị trí.
   Khi chưa có đơn active, request mới phải có đúng `vehicle_id` và `vehicle_kind`.
7. Hủy/hoàn tất đơn thử trước khi thử trường hợp mới. Chọn phương tiện thủ công,
   request mới phải có `vehicle_id = null`; thử cả xe tải/khác, kiểm tra Theo dõi,
   Lịch sử và chi tiết lịch sử hiển thị đúng loại.
8. Mở hai tab: xóa/sửa xe ở tab kia, bấm Tải lại xe đã lưu. Xe đã xóa phải bị
   bỏ chọn; loại xe sửa phải được cập nhật. Nếu xe biến mất ngay trước gửi,
   RPC phải từ chối liên kết xe không còn hợp lệ, không tạo liên kết sai.
9. Ngắt mạng khi tải/lưu/xóa: có lỗi, thử lại; lưu lỗi giữ dữ liệu nhập, xóa lỗi
   giữ xe trong danh sách. Khôi phục mạng rồi thử lại.
10. Đăng xuất khi đang tải/lưu: phản hồi cũ không được hiển thị cho user mới.
11. Đăng nhập B: không thấy xe A. Dùng JWT B kiểm thử Data API đọc/sửa/xóa ID
    xe A: không được đọc row hoặc làm đổi row của A. RPC với ID xe A phải từ chối.
    Kiểm tra lại tài khoản A để xác nhận dữ liệu không đổi. Đây là kiểm thử RLS
    trên backend thật; test mock không thay thế bước này.

## Kiểm thử điện thoại web

```powershell
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080 --dart-define-from-file=config/supabase.dev.json
```

Điện thoại cùng Wi-Fi mở `http://<IP-máy-tính>:8080` (cổng 8080 cần truy cập
được trong mạng). Lặp lại thêm/sửa/xóa, chọn xe và gửi yêu cầu. Kiểm tra màn hình
hẹp, tên xe/ghi chú dài, cuộn khi mở bàn phím và hộp xác nhận xóa.

## File thay đổi

Kiểm tra tự động: `flutter analyze` không có error, còn 50 warning/info có sẵn
(exit code 1). `flutter test` tại workspace bị quyền ghi `build` chặn; toàn bộ
73 test đạt với `flutter test --concurrency=1` trên bản sao cùng mã nguồn trong
thư mục tạm. Chưa kiểm thử migration/RLS trực tiếp trên Supabase thật.

- `frontend/customer_app/lib/app/app_controller.dart`
- `frontend/customer_app/lib/services/supabase_service.dart`
- `frontend/customer_app/lib/services/customer_vehicle_service.dart`
- `frontend/customer_app/lib/screens/customer_vehicles_screen.dart`
- `frontend/customer_app/lib/screens/new_account_screen.dart`
- `frontend/customer_app/lib/screens/new_request_screen.dart`
- `frontend/customer_app/lib/screens/new_home_screen.dart`
- `frontend/customer_app/lib/screens/new_tracking_screen.dart`
- `frontend/customer_app/lib/screens/new_history_screen.dart`
- `frontend/customer_app/lib/screens/history_details_screen.dart`
- `frontend/customer_app/lib/widgets/saved_vehicle_picker.dart`
- `frontend/customer_app/lib/widgets/rescue_widgets.dart`
- `backend/supabase/migrations/202610010003_customer_vehicles.sql`
- `frontend/customer_app/test/customer_vehicle_repository_test.dart`
- `frontend/customer_app/test/customer_vehicles_test.dart`
- `P1_CUSTOMER_VEHICLES.md`
