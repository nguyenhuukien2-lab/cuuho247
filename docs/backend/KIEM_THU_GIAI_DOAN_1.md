# Cấu hình và kiểm thử giai đoạn đầu — Cứu Hộ 24/7

> Đường dẫn đã cập nhật sau khi tổ chức repository. Các đường dẫn file bên dưới tính từ Git root; lệnh Flutter/Dart chạy trong `frontend/customer_app` (từ root: `cd frontend/customer_app`), lệnh Node/tools chạy từ root. Kết quả kiểm thử cũ được giữ theo thời điểm của báo cáo; xem [CLEANUP_REPORT.md](../CLEANUP_REPORT.md) cho kết quả sau di chuyển.

Ngày kiểm tra: 30/09/2026. Phạm vi: app khách hàng, giữ 5 tab; không thêm app người cứu hộ, quản trị, thanh toán hoặc giả lập nhận đơn.

## Kết quả hiện tại

- **Đạt:** kiểm tra mã Dart không có error; 5/5 test Flutter đạt.
- **Lỗi môi trường Android:** build APK dừng khi cài NDK vì thiếu dung lượng. Chưa có APK để kiểm thử điện thoại.
- **Chưa chạy backend:** chưa xác định project Supabase dev, file cấu hình riêng còn rỗng; chưa áp migration. Không có bằng chứng runtime về Auth/RLS/database.
- Không có database từ xa nào bị thay đổi. Các kết luận về bảo mật SQL dưới đây là rà soát mã, không phải kết quả chạy trên PostgreSQL.

## Migration đã rà soát và chỉnh

File: `backend/supabase/migrations/202609300001_initial_customer_rescue.sql`.

| Bảng | Quyền khách đã đăng nhập | Giới hạn RLS |
|---|---|---|
| `customer_profiles` | SELECT, INSERT, UPDATE | `user_id = auth.uid()` ở USING/WITH CHECK; không DELETE |
| `customer_vehicles` | SELECT, INSERT, UPDATE, DELETE | `customer_id = auth.uid()`; không chuyển chủ sang tài khoản khác |
| `rescue_services` | SELECT | Chỉ dịch vụ `is_active`; khách không sửa danh mục |
| `rescue_requests` | SELECT | Chỉ đơn của khách; không INSERT/UPDATE/DELETE trực tiếp |

Đã revoke quyền bảng từ PUBLIC, anon và authenticated trước khi cấp quyền tối thiểu. Tạo/hủy đơn qua RPC:

- `create_customer_rescue_request`: không nhận owner/status/provider/price từ client; lấy chủ đơn từ `auth.uid()`, từ chối caller rỗng; kiểm tra dịch vụ active và xe thuộc caller nếu có `vehicle_id`; đơn mới luôn `searching`.
- `cancel_own_rescue_request`: kiểm tra caller, owner và chỉ hủy `searching`/`accepted`; UPDATE có điều kiện thực hiện ngay trên DB. Không tìm thấy row phù hợp thì báo lỗi, không giả thành công.
- Hai RPC dùng `SECURITY DEFINER`, `search_path = ''`, tham chiếu bảng theo `public.*` và UID theo `auth.uid()`. PUBLIC/anon không có EXECUTE; chỉ authenticated được cấp. Các built-in của PostgreSQL được phân giải qua `pg_catalog` mặc định.
- Function trigger `cuuho247_handle_new_customer` không được PUBLIC/anon/authenticated gọi trực tiếp. Trigger có tên riêng `cuuho247_customer_profile_created`, không xóa hoặc thay trigger Auth chung của app khác.
- Unique `(customer_id, client_request_id)` giữ một row cho cùng khóa, kể cả khi đơn đã kết thúc. RPC trả lại row đó trước khi kiểm tra danh mục có thể đã đổi; nội dung lần ghi đầu được giữ.
- Partial unique index trên `customer_id` khi trạng thái active bảo đảm DB không có hai đơn active. Nhánh bắt `unique_violation` đọc lại đúng khóa hoặc đơn active khi hai lần gửi cạnh tranh.
- Client đã chuyển từ INSERT trực tiếp sang RPC; yêu cầu response một object bằng `.single()`.

Migration chạy trong transaction; chặn khi một trong bốn bảng đã tồn tại bằng `EXISTING_SCHEMA_REQUIRES_REVIEW`. Đây là migration khởi tạo chưa áp dụng. Nếu phiên bản trước đã được ai đó chạy ngoài phiên làm việc này, cần xác minh rồi tạo migration nâng cấp riêng, không chạy lại file đã sửa.

Tác động cần duyệt trước khi chạy từ xa: tạo 4 bảng, seed 5 dịch vụ, 4 index, policy/grants, 3 function và 1 trigger Auth. Không xóa dữ liệu hiện hữu. Cần kiểm kê schema trước vì tên/function/table hiện có chưa được biết.

## Xác định môi trường Supabase

Chưa có `frontend/customer_app/config/supabase.dev.json` chứa cấu hình thực, Supabase CLI chưa được phát hiện. Đã tạo file riêng với hai giá trị rỗng để người dùng nhập trực tiếp. Không in key/token/mật khẩu.

- `frontend/customer_app/config/supabase.dev.json`: điền `SUPABASE_URL` và `SUPABASE_PUBLISHABLE_KEY` lấy từ **Connect** của đúng project dev.
- `backend/supabase/tests/inspect_dev.sql`: SQL chỉ đọc để kiểm kê bảng, số row ước lượng, RLS/grants/policy và function/trigger liên quan; không trả bản ghi khách hàng.
- `git check-ignore frontend/customer_app/config/supabase.dev.json frontend/customer_app/config/backend-tests.dev.json frontend/customer_app/android/local.properties` trả đủ ba đường dẫn: cấu hình riêng không được Git đưa vào mặc định.
- Chưa xác định project name/ref, dữ liệu/schema hiện hữu hoặc quyền chạy migration; chưa xin duyệt một thao tác DDL tới project cụ thể.
- Docker client tồn tại nhưng Docker Desktop Linux engine không chạy; không có PostgreSQL/Supabase local để thay thế kiểm thử từ xa trong phiên này.

## Android và toolchain

Quét repository xác nhận Flutter root là `frontend/customer_app/`, không có Android platform khác để tái sử dụng. Các file Gradle ở thư mục cha thuộc Android app cũ (`include(":app")`), trong khi module `app/` đã bị xóa khỏi working tree từ trước.

Đã sinh project Flutter tạm và chỉ chép `frontend/customer_app/android/` vào Flutter root, không chép `frontend/customer_app/lib/`, test mẫu hoặc pubspec của template. Đã thêm INTERNET permission và tên app tiếng Việt. Application ID dev: `vn.cuuho247.cuu_ho_247`. Không có signing phát hành.

`flutter doctor -v`:

- Flutter 3.47.5 / Dart 3.13.4.
- Android SDK/build-tools 36.0.0, platform android-37.0; Android licenses đã chấp nhận.
- Flutter dùng JDK Android Studio 25.0.3; Java trên PATH là Oracle 21.0.12.1.
- Có Windows/Chrome/Edge; không có Android device.
- `adb devices -l`: danh sách rỗng. `emulator -list-avds`: không có AVD.
- Thiếu Visual Studio chỉ ảnh hưởng Windows desktop, không giải thích lỗi Android.

Build APK đã qua tải Gradle 9.3.1 nhưng dừng tại SDK/NDK:

```text
Warning: An error occurred while preparing SDK package
NDK (Side by side) 28.2.13676358: There is not enough space on the disk.
BUILD FAILED in 6m 38s
Gradle task assembleDebug failed with exit code 1
```

Chưa biết chính xác dung lượng trống qua môi trường tool; không dùng giá trị 0/0 từ Get-PSDrive để suy ra dung lượng thực. Chưa xóa SDK/cache/người dùng để lấy chỗ. Đã dọn phần lớn scaffold tạm; `.android_scaffold_tmp/pubspec.yaml` còn bị tiến trình khác giữ và đã được ignore, không kết thúc tiến trình đó.

Hướng dẫn kết nối USB/emulator và chạy đã bổ sung vào `SUPABASE_SETUP.md`.

## Ma trận kiểm thử theo yêu cầu

| Kiểm tra | Kết quả | Bằng chứng / giới hạn |
|---|---|---|
| Đăng ký | **Chưa chạy** | Chưa project dev và cấu hình Auth/email confirmation |
| Đăng nhập đúng | **Chưa chạy** | Chưa tài khoản test A/B |
| Đăng nhập sai | **Chưa chạy** | Chưa gọi Auth API |
| Đăng xuất | **Chưa chạy** | Chưa có phiên Auth thật |
| Khôi phục phiên sau khởi động lại app | **Chưa chạy** | SDK persistence có trong mã; chưa đủ bằng chứng runtime |
| Tạo yêu cầu rồi đọc lại DB | **Chưa chạy** | Migration chưa áp dụng |
| Retry cùng khóa không tạo row thứ hai | **Chưa chạy trên DB** | RPC và unique index đã rà soát; test widget xác nhận client dùng lại cùng khóa |
| Hai lần gửi đồng thời không tạo hai đơn active | **Chưa chạy** | Cần kiểm tra unique index/RPC qua hai request HTTP thật |
| B không đọc đơn A qua API | **Chưa chạy** | SELECT RLS đã rà soát; chưa kiểm chứng DB |
| B không sửa đơn A qua API | **Chưa chạy** | Không cấp UPDATE; chưa kiểm chứng DB |
| B không hủy đơn A qua RPC | **Chưa chạy** | Predicate owner/caller đã rà soát; chưa kiểm chứng DB |
| Khách không tự chuyển hoàn tất/đổi owner/provider | **Chưa chạy** | Không có grant UPDATE hoặc tham số RPC cho các trường đó |
| Hủy đúng điều kiện rồi tạo mới | **Chưa chạy** | Cần DB và hai trạng thái hợp lệ/không hợp lệ |
| Form giữ dữ liệu khi gửi thất bại | **Đạt trong widget test** | `frontend/customer_app/test/request_failure_test.dart`: controller giả trả lỗi; cả 4 trường còn nguyên, tab vẫn 1, không có activeRequest giả |
| Thử lại giữ cùng khóa | **Đạt trong widget test** | Hai lần submit dùng cùng `clientRequestId` và cùng địa chỉ |
| Chống bấm khi đang gửi | **Đạt trong widget test** | Nút bị disable trong thời gian Future đang pending; submit cũng có guard |
| Mất mạng thật trên điện thoại và gửi lại | **Chưa chạy** | Chưa thiết bị/APK/backend; widget test không mô phỏng toàn bộ mạng và SDK |

## Lệnh kiểm tra và bằng chứng

Các lệnh Flutter được chạy bằng SDK snapshot trong phiên do quyền cache/lock của wrapper trong sandbox; không kết thúc tiến trình Dart/IDE có sẵn.

| Lệnh tương đương | Kết quả |
|---|---|
| `flutter doctor -v` | Android toolchain đạt; không có Android device; Windows thiếu Visual Studio |
| `flutter build apk --debug --no-pub` | **Lỗi**: thiếu dung lượng khi cài NDK |
| `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings` | **Đạt về error**: 0 error, 4 warning + 46 info có sẵn; exit 0 vì dùng no-fatal flags. Không gọi là analyzer sạch |
| `flutter test --no-pub` | **Đạt**: `00:03 +5: All tests passed!` ở lần cuối |
| `git check-ignore ...` | **Đạt**: file config riêng và local.properties bị ignore |
| `docker info` (đã thử ngoài sandbox) | **Lỗi môi trường**: pipe dockerDesktopLinuxEngine không tồn tại |

`frontend/customer_app/tool/verify_backend.dart` đã qua analyzer, chuẩn bị cho kiểm thử API thực sau khi được phép; chưa chạy ở chế độ ghi. Script yêu cầu project ref đúng host và hai tài khoản riêng chưa có đơn, không log body/token, giữ lại lịch sử test thay vì xóa dữ liệu. Hai tài khoản phải được xác nhận email nếu cấu hình Auth yêu cầu.

## Việc cần để tiếp tục

1. Điền hai trường trong `frontend/customer_app/config/supabase.dev.json`, xác nhận tên/project ref là môi trường dev và kiểm kê bằng `backend/supabase/tests/inspect_dev.sql`.
2. Sau khi biết schema/dữ liệu hiện có, duyệt thay đổi migration rồi mới cho phép chạy trên project cụ thể, đúng yêu cầu của người dùng.
3. Giải quyết dung lượng SDK/NDK và kết nối điện thoại hoặc tạo emulator.
4. Chạy bộ API A/B và kiểm tra UI/session restart/offline trên app; cập nhật từng dòng “Chưa chạy” bằng kết quả và bằng chứng thực tế.
