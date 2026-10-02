# P1 — Upload ảnh sự cố của app khách hàng

> Đường dẫn đã cập nhật sau khi tổ chức repository. Các đường dẫn file bên dưới tính từ Git root; lệnh Flutter/Dart chạy trong `frontend/customer_app` (từ root: `cd frontend/customer_app`), lệnh Node/tools chạy từ root. Kết quả kiểm thử cũ được giữ theo thời điểm của báo cáo; xem [CLEANUP_REPORT.md](../CLEANUP_REPORT.md) cho kết quả sau di chuyển.

## Migration và triển khai backend

Migration mới: `backend/supabase/migrations/202610010002_customer_request_photos.sql`.
Áp dụng sau hai migration `202609300001_initial_customer_rescue.sql` và
`202610010001_customer_tracking.sql` trên Supabase dev bằng SQL Editor hoặc
quy trình migration hiện tại. Không chạy lại migration khởi tạo trên database
đã có schema.

**SQL tự tạo bucket `rescue-request-photos`; không cần tạo bucket thủ công.**
Bucket private, tối đa 5 MB mỗi object, chỉ nhận `image/jpeg`, `image/png`,
`image/webp`. Nếu bucket cùng ID đã tồn tại, migration đặt lại private và các
giới hạn này.

Bảng `rescue_request_photos` lưu `id`, `request_id`, `customer_id`, `slot`,
`storage_path`, `content_type`, `byte_size`, `created_at`, `uploaded_at`.
Slot chỉ từ 1 đến 3 và unique theo request, nên giới hạn ảnh được thực thi ở DB.
Khách chỉ SELECT ảnh thuộc đơn của chính mình; không được ghi trực tiếp bảng.

RPC `reserve_customer_request_photo` kiểm tra chủ đơn, khóa hàng request để
giữ chỗ ảnh an toàn khi có nhiều thao tác đồng thời. Mỗi ảnh có UUID ổn định;
retry cùng UUID và thông tin trả về cùng reservation. Object path là
`customer_id/request_id/photo_id`, do backend tạo.

Storage chỉ cho INSERT object đã giữ chỗ của chủ đơn, không cho overwrite/delete.
RPC `complete_customer_request_photo` xác nhận object thật có đúng MIME và size
rồi ghi `uploaded_at`. Tracking chỉ đọc ảnh đã hoàn tất. Policy restrictive bảo
vệ bucket kể cả khi project đã có policy Storage permissive rộng cho khách/anon.
Chủ đơn được đọc object; người khác và anon bị chặn.

App dùng publishable/anon key cùng JWT đăng nhập của khách, **không có service_role**.
URL xem ảnh được ký trong 600 giây; bấm **Tải lại ảnh** để lấy URL mới khi hết hạn.
URL đã ký là quyền truy cập tạm thời: người được chia sẻ URL có thể xem tới khi
hết hạn. Quyền Storage theo RLS và yêu cầu SELECT khi tạo signed URL theo
[tài liệu Supabase Storage](https://supabase.com/docs/guides/storage/security/access-control).

Phiên này chưa áp migration lên Supabase đang triển khai, chưa chạy upload qua
Storage HTTP thật. Cần áp SQL trước khi dùng chức năng ảnh trên backend dev.

## Flutter và xử lý lỗi

Thêm package **`image_picker: ^1.2.3`**, lockfile chốt **1.2.3** cùng implementation
nền tảng. Form có **Chọn ảnh**, **Chụp ảnh**, preview và **Bỏ ảnh**. Ảnh là tùy chọn;
nếu đính kèm thì chọn 1–3 ảnh. Chọn một ảnh mỗi lần. Picker yêu cầu resize tối đa
1600 px, JPEG quality 85 khi nền tảng hỗ trợ. App kiểm tra giới hạn 5 MB, định dạng
theo bytes và giải mã ảnh để từ chối file hỏng hoặc giả tên/MIME.

Luồng gửi:

1. Tạo request qua RPC P0, giữ idempotency key nếu tạo đơn lỗi.
2. Nếu có ảnh, giữ form ở tab Cứu hộ; upload tuần tự rồi gắn từng ảnh vào request.
3. Sau khi hoàn tất, chuyển sang tracking và bỏ draft ảnh đã gửi.

Lỗi upload báo **đơn đã tạo**, số ảnh đã gửi và cách thử lại. Text, GPS đã chọn,
preview và UUID ảnh vẫn được giữ trong form. Form khóa chỉnh sửa khi đơn đã tạo
để lần retry tiếp tục đúng draft. Bấm **Thử lại** hoặc **Gửi lại ảnh còn thiếu**
chỉ gửi ảnh chưa hoàn tất, không tạo đơn mới. Có thể mở tab Đang xử lý để xem đơn
và các ảnh đã gửi được, rồi trở lại form để thử lại ảnh còn thiếu.

Nếu upload đã thành công nhưng mất response, retry không overwrite object:
backend xác nhận object tồn tại rồi hoàn tất metadata. Ảnh đã hoàn tất được bỏ qua.
Nếu RPC tạo đơn trả về một đơn active khác theo contract P0, form không gắn ảnh
của draft mới vào đơn đó và hiển thị thông báo để khách kiểm tra.

Tracking có danh sách ảnh, trạng thái rỗng/lỗi và nút tải lại. Phản hồi cũ bị bỏ qua
khi đổi request/tài khoản. Draft reset theo danh tính đăng nhập qua AppShell.

Draft và ảnh chưa gửi hiện ở bộ nhớ của phiên app, không có hàng đợi offline bền
vững. Reload/đóng app sẽ mất draft; ảnh đã hoàn tất vẫn còn trên server. Android
có `retrieveLostData` để khôi phục ảnh picker khi Activity bị hệ điều hành hủy;
khách được nhắc kiểm tra ảnh và nhập lại thông tin. Reservation chưa hoàn tất vẫn
chiếm slot; nếu bỏ phiên giữa upload, backend tin cậy cần dọn reservation/object
chưa hoàn tất theo quy trình vận hành. Không tự xóa bằng quyền khách trong P1.

## File thêm/sửa

| File | Nội dung |
|---|---|
| `backend/supabase/migrations/202610010002_customer_request_photos.sql` | Bucket, metadata, RPC, RLS/Storage policy |
| `frontend/customer_app/pubspec.yaml`, `frontend/customer_app/pubspec.lock` | image_picker và phiên bản khóa |
| `frontend/customer_app/lib/services/request_photo_service.dart` | Chọn ảnh, kiểm tra bytes, Storage upload/retry, signed URL |
| `frontend/customer_app/lib/widgets/request_photos_card.dart` | Danh sách ảnh tracking, reload và xử lý lỗi |
| `frontend/customer_app/lib/screens/new_request_screen.dart` | Preview, giới hạn ảnh, gửi sau tạo đơn, giữ draft khi lỗi |
| `frontend/customer_app/lib/screens/new_tracking_screen.dart` | Tích hợp card ảnh |
| `frontend/customer_app/lib/app/app_controller.dart` | Trả request đã tạo, đọc client_request_id, tùy chọn hoãn chuyển tab |
| `frontend/customer_app/test/request_photos_test.dart` | Form ảnh, giới hạn, lỗi, retry và tracking |
| `frontend/customer_app/test/request_photo_repository_test.dart` | HTTP mock: JWT khách, upload/complete, duplicate retry, signed URL |
| `frontend/customer_app/test/request_failure_test.dart`, `frontend/customer_app/test/request_location_test.dart` | Cập nhật controller giả theo contract trả request |
| `tools/check_photo_policies.mjs` | Kiểm tra migration/RPC/RLS trên PostgreSQL nhúng |
| `P1_CUSTOMER_PHOTOS.md` | Báo cáo và hướng dẫn test |

Metadata package tự sinh `frontend/customer_app/.dart_tool/package_config.json`,
`frontend/customer_app/.dart_tool/package_graph.json`, `frontend/customer_app/.flutter-plugins-dependencies` cũng đã đồng bộ,
đã được bỏ qua trong `.gitignore`.

## Kết quả kiểm tra

- `flutter pub get`: **đạt**, image_picker 1.2.3.
- `flutter test`: **39/39 đạt**.
- `flutter build web --no-pub`: **đạt**, gồm Wasm dry run.
- `flutter analyze`: **0 error, 4 warning + 46 info có sẵn, exit code 1**.
  Không có warning/info mới trong phần ảnh. Các warning unused ở login cũ và
  info withOpacity deprecated đã có từ P0/P1 GPS; không gọi analyzer là sạch.
- `tools/check_photo_policies.mjs`: **31/31 kiểm tra đạt**. Chạy nguyên migration
  mới trên PostgreSQL nhúng PGlite với fixture tối thiểu auth/storage/request;
  kiểm tra owner, chặn B/anon, giới hạn 3, retry, file chưa có, size/MIME,
  không overwrite/delete, kể cả khi có Storage policy rộng.

Docker Desktop hiện không chạy nên test SQL dùng PostgreSQL nhúng, không thay thế
kiểm tra Supabase Storage HTTP, xác minh JWT thật hay nhiều connection đồng thời.
Package PGlite chỉ cài trong thư mục kiểm thử tạm, không thêm dependency vào app.
Muốn chạy lại công cụ, dùng bản sao tạm, `npm install --no-save --ignore-scripts
@electric-sql/pglite`, rồi `node tools/check_photo_policies.mjs`.

Các lệnh Flutter dùng SDK 3.47.5/Dart 3.13.4 trên bản sao mã nguồn trong thư mục
tạm có quyền ghi do lỗi quyền Windows đã gặp từ P1 GPS. Lockfile và metadata
package đã đồng bộ về workspace. Chưa thử trên Chrome tương tác hoặc Android thật.

## Test thủ công Chrome

1. Áp migration mới trên Supabase dev. Kiểm tra bucket ở Storage là **private**,
   giới hạn 5 MB và MIME đúng. Giữ config chỉ có URL và publishable/anon key.

   ```powershell
   flutter pub get
   flutter run -d chrome --web-port=7357 --dart-define-from-file=config/supabase.dev.json
   ```

2. Đăng nhập khách A không có request active. Nhập form, chọn 1–3 ảnh và kiểm tra
   preview. Thử bỏ ảnh, chọn lại, hủy file picker. Nút chọn/chụp bị khóa khi đủ 3.
   Thử ảnh >5 MB và file giả đuôi ảnh: báo lỗi, text form còn nguyên.
3. Gửi đơn. DevTools Network phải thấy create request trước, sau đó reserve RPC,
   Storage upload và complete RPC. Tracking hiển thị ảnh. Reload trang và mở lại
   tracking vẫn xem được ảnh đã gửi.
4. Kiểm tra lỗi upload bằng DevTools → Network request blocking: chặn pattern
   `*storage/v1/object/rescue-request-photos/*` trước khi gửi, giữ RPC không bị chặn.
   Đơn vẫn tạo, form báo upload lỗi và giữ text/preview. Bỏ block, bấm Thử lại:
   không thêm đơn mới, không thêm ảnh trùng. Kiểm tra `rescue_request_photos` chỉ
   có tối đa 3 hàng/đơn, `uploaded_at` có giá trị với ảnh đã hoàn tất.
5. Thử ngắt mạng giữa các ảnh để kiểm tra upload một phần. Sau khi bật lại mạng,
   retry tiếp tục ảnh thiếu. Nếu đã có đơn active khác, draft ảnh không được gửi
   vào đơn đó. Kết thúc/hủy đơn hiện tại trước khi thử một draft mới.
6. Đăng xuất A, đăng nhập B. Dùng JWT của B qua Data API đọc metadata của A phải
   nhận mảng rỗng; gọi reserve/complete của ảnh/đơn A và tạo signed URL cho object
   A phải bị từ chối. Upload vào path chưa reserve và anonymous upload cũng bị
   từ chối. SQL Editor quyền postgres không phải phép kiểm tra RLS của khách.
   Không dùng URL đã ký của A để đánh giá RLS vì URL đó có quyền tạm tới hết hạn.
7. Sau 10 phút, bấm **Tải lại ảnh** để lấy signed URL mới. Thử mất mạng trên tracking:
   báo lỗi, tải lại khi có mạng.
8. Nút **Chụp ảnh** trên Web là yêu cầu capture của browser/file input; Chrome
   desktop có thể mở file picker, không có giao diện camera trực tiếp của app.
   Khả năng mở camera phụ thuộc trình duyệt/thiết bị; thử Chrome Android để kiểm
   tra capture. Dùng HTTPS hoặc localhost cho bản web.

## Test Android sau này

`image_picker` dùng picker/camera của hệ thống, không cần thêm CAMERA hay quyền
đọc bộ nhớ rộng vào AndroidManifest cho luồng này theo
[tài liệu image_picker](https://pub.dev/packages/image_picker).
Manifest hiện giữ INTERNET và hai quyền GPS đã thêm ở P1 vị trí. Không thêm
`requestLegacyExternalStorage`; launchMode hiện tại singleTop phù hợp.

1. Kết nối điện thoại/emulator, bật mạng và chạy:

   ```powershell
   flutter devices
   flutter run -d <ANDROID_DEVICE_ID> --dart-define-from-file=config/supabase.dev.json
   ```

2. Chọn ảnh bằng Photo Picker (Android 13+) hoặc picker hệ thống phiên bản thấp
   hơn. Chụp ảnh mới, kiểm tra preview, xoay màn hình, hủy camera/picker; thử đủ 3.
3. Nếu camera/picker bị chặn bởi thiết bị, kiểm tra thông báo lỗi và chọn ảnh từ
   thư viện. Test JPEG/PNG/WebP, ảnh lớn và file hỏng.
4. Tạo đơn và kiểm tra ảnh trên tracking; tắt/bật mạng giữa upload để kiểm tra
   giữ draft và retry đúng đơn. Thử đổi tab rồi quay lại form khi có ảnh chưa gửi.
5. Bật Developer options → Don't keep activities khi thử picker/camera để kiểm
   tra `retrieveLostData`; ảnh được khôi phục cần khách kiểm tra lại. Đây không
   phải cam kết giữ toàn bộ text draft khi hệ điều hành hủy process.
6. Đăng xuất/đổi khách và thử quyền chéo như trên Chrome. Kiểm tra signed URL tải
   lại được sau hết hạn. Sau thử nghiệm tắt Don't keep activities.
