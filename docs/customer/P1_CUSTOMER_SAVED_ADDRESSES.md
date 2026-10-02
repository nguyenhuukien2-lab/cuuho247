# P1 — Địa chỉ đã lưu cho khách hàng

> Đường dẫn đã cập nhật sau khi tổ chức repository. Các đường dẫn file bên dưới tính từ Git root; lệnh Flutter/Dart chạy trong `frontend/customer_app` (từ root: `cd frontend/customer_app`), lệnh Node/tools chạy từ root. Kết quả kiểm thử cũ được giữ theo thời điểm của báo cáo; xem [CLEANUP_REPORT.md](../CLEANUP_REPORT.md) cho kết quả sau di chuyển.

## File
- `frontend/customer_app/lib/services/customer_saved_address_service.dart`: model/repository, CRUD theo JWT và customer_id, kiểm tra dữ liệu và phiên đăng nhập.
- `frontend/customer_app/lib/screens/customer_saved_addresses_screen.dart`: danh sách, empty state, thêm/sửa, tọa độ và ghi chú tùy chọn, công tắc mặc định, xác nhận xóa, lỗi/retry.
- `frontend/customer_app/lib/widgets/saved_address_picker.dart`: danh sách địa chỉ trong form cứu hộ; tải lại khi quay về tab Cứu hộ, mặc định đứng đầu.
- `frontend/customer_app/lib/screens/new_account_screen.dart`: mở màn hình Địa chỉ đã lưu, yêu cầu đăng nhập.
- `frontend/customer_app/lib/screens/new_request_screen.dart`: chọn địa chỉ điền text và cặp tọa độ; bỏ kết quả GPS đang chờ, yêu cầu xác nhận lại; sửa text của địa chỉ đã chọn sẽ bỏ tọa độ đã lưu. Lấy GPS vẫn hoạt động theo thao tác của khách.
- `frontend/customer_app/test/customer_saved_address_repository_test.dart`: owner/JWT, insert/update/delete, nullable fields, validation.
- `frontend/customer_app/test/customer_saved_addresses_test.dart`: empty state/CRUD/xác nhận xóa, chọn địa chỉ có/không tọa độ, bỏ GPS trả muộn.
- `backend/supabase/migrations/202610010004_customer_saved_addresses.sql`: bảng mới, owner-only RLS cho cả bốn thao tác, constraint cặp tọa độ, unique index tối đa một mặc định/khách, trigger chuyển mặc định trong cùng transaction.

## Backend
Áp dụng migration mới sau các migration hiện có trên Supabase môi trường test trước khi chạy app. Chưa áp dụng lên backend trong phiên triển khai này; test Flutter dùng mock/fake, không chứng minh RLS trên server đang chạy.
Không cần sửa RPC tạo cứu hộ: địa chỉ/tọa độ được chụp vào request bằng RPC hiện có. Sửa/xóa địa chỉ đã lưu không thay đổi request cũ. Địa chỉ mặc định được ưu tiên trong danh sách, không tự thay vị trí cứu hộ; khách phải chọn và xác nhận. Có thể không có địa chỉ mặc định sau khi bỏ mặc định hoặc xóa địa chỉ đó.

## Chrome
```powershell
flutter run -d chrome --dart-define-from-file=config/supabase.dev.json
```
1. Đăng nhập tài khoản A, Tài khoản → Địa chỉ đã lưu: kiểm tra empty state; thêm Nhà không tọa độ, Công ty với latitude 10.7769/longitude 106.7009 và ghi chú.
2. Bật mặc định cho Nhà, rồi bật cho Công ty. Tải lại: chỉ Công ty còn mặc định. Sửa địa chỉ, kiểm tra dữ liệu được giữ khi rời màn hình rồi vào lại.
3. Bấm xóa, chọn Giữ lại: dữ liệu còn. Xác nhận Xóa địa chỉ: dữ liệu mất. Kiểm tra empty state sau khi xóa hết.
4. Tab Cứu hộ: chọn địa chỉ đã lưu. Text/tọa độ đúng; xác nhận và gửi; kiểm tra vị trí trong chi tiết yêu cầu. Chọn địa chỉ không tọa độ sau khi đã lấy GPS: tọa độ cũ phải bị bỏ.
5. Chọn địa chỉ có tọa độ rồi sửa text: tọa độ đã lưu bị bỏ, cần xác nhận lại. Bấm Lấy vị trí hiện tại: GPS vẫn lấy và gửi được; Chỉ dùng địa chỉ nhập tay bỏ tọa độ. Từ chối quyền vẫn gửi được địa chỉ nhập tay.
6. Đang lấy GPS, chọn địa chỉ đã lưu: GPS trả muộn không được ghi đè tọa độ địa chỉ đã chọn.
7. Đăng xuất A, đăng nhập B: không thấy địa chỉ A. Dùng JWT B gọi REST bảng customer_saved_addresses với id/customer_id của A: SELECT không trả địa chỉ A, UPDATE/DELETE không sửa/xóa A, INSERT customer_id=A bị RLS từ chối. Thử đổi customer_id khi update: bị từ chối.

## Điện thoại web
Chạy để kiểm tra giao diện/thao tác trên cùng Wi-Fi:
```powershell
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080 --dart-define-from-file=config/supabase.dev.json
```
Mở `http://<IP-LAN-máy-tính>:8080` trong Chrome điện thoại, thực hiện các bước CRUD/chọn địa chỉ ở trên. Kiểm tra màn hình nhỏ, bàn phím, cuộn tới nút lưu, xác nhận xóa và quay lại form. Để kiểm tra GPS thật trên điện thoại, dùng bản web phục vụ qua HTTPS; HTTP qua IP LAN thường không cho geolocation. Chrome máy tính dùng localhost có thể kiểm tra GPS.

## Kiểm tra tự động
```powershell
flutter analyze
flutter test
```
Kết quả cuối cùng được báo trong phần trả lời triển khai. Mã cũ có các warning unused trong login_screen.dart và các thông báo deprecated; không mở rộng thay đổi sang các màn hình ngoài tính năng này.

Kết quả chạy cuối:
- `flutter test`: 81 test passed, exit code 0; bao gồm các test GPS/ảnh/xe/tracking hiện có và 8 test địa chỉ mới. Test chọn địa chỉ cũng kiểm tra sửa text sẽ bỏ tọa độ và yêu cầu xác nhận lại.
- `flutter analyze`: exit code 1, không có error; còn 4 warning unused trong login_screen.dart và 46 info deprecated trong mã cũ. Không có diagnostic trong các file địa chỉ mới.
- Chưa thử tương tác trực tiếp trên Chrome/điện thoại và chưa áp dụng migration/xác minh RLS trên Supabase thật.
