# Cứu Hộ 24/7 — app khách hàng

Git root là thư mục `flutter_app`. Flutter root là `frontend/customer_app`.
Lượt tổ chức này chỉ chứa app khách hàng hiện có; chưa tạo app người cứu hộ, admin hoặc thanh toán.

## Cấu trúc

```text
flutter_app/
├── frontend/
│   └── customer_app/       # lib, test, android, web, config, tool, pubspec
├── backend/
│   └── supabase/
│       ├── migrations/    # Sáu migration SQL hiện có, giữ nguyên nội dung
│       ├── functions/     # Chưa có Edge Functions
│       ├── tests/         # SQL kiểm kê và SQL dev hiện có
│       └── seed/          # Chưa có seed SQL riêng
├── docs/
│   ├── customer/          # UI, tracking, GPS, map, ảnh, xe, địa chỉ, review
│   ├── backend/           # Setup Supabase, migration/RLS/RPC và bằng chứng
│   ├── CLEANUP_REPORT.md
│   └── REORGANIZATION_FILES.csv
├── tools/                 # Công cụ dùng từ repository root
├── README.md
└── .gitignore
```

Sau này app người cứu hộ có thể được thêm tại `frontend/rescuer_app`; thư mục đó chưa được tạo trong lượt này.
Không có iOS hoặc thư mục assets riêng trong bản app ban đầu; không sinh thêm platform hoặc asset.

## Chạy app khách hàng

Từ repository root:

```powershell
cd frontend/customer_app
flutter pub get
flutter run --debug --dart-define-from-file=config/supabase.dev.json
```

Cấu hình riêng hiện có được giữ tại `frontend/customer_app/config/supabase.dev.json` và được Git ignore.
Với checkout mới, tạo file này theo `config/supabase.example.json`, nhập URL và publishable/anon key của đúng project. Không dùng service_role, database password hoặc secret key trong app. Không đổi tên package `cuu_ho_247` hay Application ID `vn.cuuho247.cuu_ho_247`.

Chạy OPPO với mã thiết bị đã cung cấp (khi thiết bị đang kết nối):

```powershell
flutter run --debug -d 86ab44a0 --dart-define-from-file=config/supabase.dev.json
```

## Kiểm tra và build APK

Chạy trong `frontend/customer_app`:

```powershell
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build apk --debug --dart-define-from-file=config/supabase.dev.json
```

APK: `frontend/customer_app/build/app/outputs/flutter-apk/app-debug.apk` tính từ root.
Build và cache là file sinh tự động, được Git ignore. Không đưa APK chứa cấu hình môi trường vào Git.

Nếu cần thư mục tạm trên ổ D:

```powershell
$env:TEMP="D:\FlutterTemp"
$env:TMP="D:\FlutterTemp"
```

Nếu thư mục trên hoặc cache Pub hiện tại bị lỗi quyền ghi, từ repository root chạy:

```powershell
.\tools\use-local-cache.ps1
cd frontend/customer_app
flutter pub get
```

Helper chỉ đặt TEMP/TMP/PUB_CACHE trong phiên PowerShell vào `tools/.work`, không xóa hay đổi cấu hình cache toàn máy. Thư mục này được Git ignore.

## Backend và áp migration

Migration nằm ở [backend/supabase/migrations](backend/supabase/migrations).
Hướng dẫn hiện tại: [docs/backend/README.md](docs/backend/README.md) và [SUPABASE_SETUP.md](docs/backend/SUPABASE_SETUP.md).

Áp thủ công qua SQL Editor của đúng Supabase project theo thứ tự tên file tăng dần: khởi tạo, tracking, ảnh, xe, địa chỉ, review. Chạy SQL kiểm kê `backend/supabase/tests/inspect_dev.sql` trước/sau; đối chiếu schema, RLS, RPC và migration đã áp để tránh chạy lại migration khởi tạo trên database đang có dữ liệu. Chỉ thực hiện sau khi xác nhận môi trường và quyền áp dụng.

Lượt tổ chức repository không thực thi SQL hoặc thay đổi project. Bản ban đầu chưa có `supabase/config.toml` hoặc project link cho CLI; không tạo cấu hình giả và không tự chạy `db push`. Nếu dùng CLI sau này, chuẩn bị cấu hình/local project và đối chiếu lịch sử migration theo quy trình của đội dự án.

`backend/supabase/tests/dev_advance_request.sql` là công cụ dev làm thay đổi trạng thái đơn, không phải SQL để app chạy tự động. Không chạy trên production.

## Script và tài liệu

- `frontend/customer_app/tool/verify_backend.dart`: chạy từ Flutter root; kiểm thử API dev có thao tác tạo/hủy dữ liệu, chỉ dùng khi môi trường được xác nhận.
- `frontend/customer_app/tool/preview_web_server.dart`: phục vụ bản build web cục bộ; chạy từ Flutter root sau build web.
- `tools/check_photo_policies.mjs`: kiểm tra policy/RPC ảnh bằng PostgreSQL nhúng, dùng từ root trong bản sao thử nghiệm có dependency riêng; không thêm npm dependency vào app Flutter.
- `tools/audit-repository.ps1`: kiểm kê Git, file lớn, ignore và dấu hiệu key; không xóa hoặc sửa source.
- Cấu hình web `frontend/customer_app/vercel.json` dùng Root Directory `frontend/customer_app` và output `build/web` nếu triển khai qua Vercel.
- [Tài liệu khách hàng](docs/customer/README.md), [tài liệu backend](docs/backend/README.md).
- [Báo cáo dọn dẹp](docs/CLEANUP_REPORT.md), [danh sách file di chuyển](docs/REORGANIZATION_FILES.csv).

Git root được khởi tạo vì thư mục ban đầu chưa có `.git`. Chưa stage hoặc commit file. Trong môi trường chạy công cụ có hai tài khoản Windows khác nhau, có thể cần tham số tin cậy cho đúng thư mục đã kiểm kê:
`git -c safe.directory=D:/DAndroidStudioProjects/flutter_app status --short`.
Không đặt ngoại lệ toàn máy cho mọi repository.
