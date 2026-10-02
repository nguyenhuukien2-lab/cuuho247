# CLEANUP REPORT — tổ chức repository Cứu Hộ 24/7

Ngày: 02/10/2026. Git root: `D:\DAndroidStudioProjects\flutter_app`.
Flutter root: `D:\DAndroidStudioProjects\flutter_app\frontend\customer_app`.

## Kết quả

App khách hàng đã được di chuyển, resolve dependency, analyze, chạy đủ 165 test, build APK debug và khởi động thực tế trên Chrome headless từ vị trí mới. Không có file nguồn bị khóa hoặc di chuyển thất bại. Chưa chạy trên OPPO hoặc kiểm thử nghiệp vụ với Supabase thật trong lượt này.

Thư mục ban đầu chưa có .git. Đã khởi tạo Git tại root, chưa stage/commit. Vì không có file được theo dõi từ trước, các lần di chuyển dùng Move-Item; không có lịch sử Git để dùng git mv. Giữ nguyên toàn bộ source và thay đổi hiện có của người dùng.

## Cây thư mục nguồn

```text
flutter_app/
├── .git/
├── .gitignore
├── README.md
├── frontend/
│   └── customer_app/
│       ├── lib/
│       ├── test/
│       ├── android/
│       ├── web/
│       ├── config/
│       ├── tool/
│       │   ├── verify_backend.dart
│       │   └── preview_web_server.dart
│       ├── pubspec.yaml
│       ├── pubspec.lock
│       └── vercel.json
├── backend/
│   └── supabase/
│       ├── migrations/     # Sáu migration gốc
│       ├── functions/      # .gitkeep, chưa có Edge Functions
│       ├── tests/
│       │   ├── inspect_dev.sql
│       │   └── dev_advance_request.sql
│       └── seed/           # .gitkeep, chưa có seed độc lập
├── docs/
│   ├── customer/
│   ├── backend/
│   ├── CLEANUP_REPORT.md
│   ├── REORGANIZATION_FILES.csv
│   ├── SQL_INTEGRITY.csv
│   ├── LARGE_FILES_BEFORE.csv
│   └── LARGE_FILES_AFTER.csv
└── tools/
    ├── audit-repository.ps1
    ├── use-local-cache.ps1
    └── check_photo_policies.mjs
```

Build, .dart_tool, .idea, browser profile và tools/.work là dữ liệu local được ignore, không nằm trong cây nguồn ở trên. IDE đang mở có thể tái tạo thư mục build/.idea tại root; giữ nguyên phần đó, không xóa cấu hình đang phát sinh của người dùng.

Bản ban đầu không có ios, assets riêng, analysis_options.yaml của app hoặc config.toml Supabase; không tạo platform/cấu hình giả. Chưa tạo frontend/rescuer_app, admin hoặc app thanh toán.

## Danh sách di chuyển

[REORGANIZATION_FILES.csv](REORGANIZATION_FILES.csv) chứa **138 file** nguồn/cấu hình/tài liệu và đường dẫn trước/sau. File sinh tự động và hồ sơ trình duyệt lớn được ghi theo nhóm dưới đây, không liệt kê hàng nghìn file cache trong manifest nguồn.

| Trước | Sau |
|---|---|
| lib, test, android, web, config | frontend/customer_app, giữ nguyên cây con |
| pubspec.yaml, pubspec.lock, vercel.json | frontend/customer_app |
| .idea | frontend/customer_app/.idea |
| tool/verify_backend.dart | frontend/customer_app/tool/verify_backend.dart |
| .tmp_web_server.dart | frontend/customer_app/tool/preview_web_server.dart |
| tool/check_photo_policies.mjs | tools/check_photo_policies.mjs |
| supabase/migrations | backend/supabase/migrations |
| supabase/inspect_dev.sql | backend/supabase/tests/inspect_dev.sql |
| supabase/dev_advance_request.sql | backend/supabase/tests/dev_advance_request.sql |
| P0/P1 customer, đánh giá FE, UI mobile | docs/customer |
| docs/customer-ui-redesign.md | docs/customer/customer-ui-redesign.md |
| SUPABASE_SETUP.md, KIEM_THU_GIAI_DOAN_1.md | docs/backend |
| build | frontend/customer_app/build |
| widget_preview_capture.png, widget_preview_capture_2.png, widget_preview_chrome.png | frontend/customer_app/build/legacy-preview |
| .chrome-preview-test, .chrome-web-test, .edge-preview-test, .tooling_appdata | tools/.work/legacy-local |
| .widget_preview | tools/.work/legacy-local/.widget_preview |

Scaffold Widget Preview được giữ dưới vùng archive ignore vì pubspec sinh tự động của nó trỏ tới đường dẫn C: cũ khác workspace hiện tại. Không dùng scaffold đó làm app hiện hành; lib/previews vẫn nguyên vẹn. Flutter có thể sinh scaffold mới khi chạy Widget Preview từ app root mới.

Các thư mục tool và supabase rỗng sau di chuyển đã được bỏ bằng thao tác xóa thư mục rỗng, không dùng xóa đệ quy root.

## File/thư mục đã xóa và lý do

Trước khi dọn đã chạy git status --short, rg --files và git clean -ndX. Mỗi target được xác minh đường dẫn tuyệt đối trong repository, trạng thái ignore, không chứa file tracked và không có reparse point. Không chạy git clean ở chế độ xóa.

| Target cụ thể | Bytes dữ liệu file đã bỏ | Lý do |
|---|---:|---|
| .dart_tool | 191791523 | Cache/package metadata gắn Flutter root cũ; tạo lại bằng pub get |
| .flutter-plugins-dependencies | 12205 | Metadata plugin chứa đường dẫn cũ; Flutter sinh lại |
| .android_scaffold_tmp | 3927 | Chỉ còn pubspec scaffold sinh từ SDK, không phải source app |
| frontend/customer_app/android/.gradle | 7696931 | Cache build trước di chuyển; Gradle sinh lại |
| frontend/customer_app/android/.kotlin | 0 | Thư mục trạng thái Kotlin sinh tự động |

Tổng dữ liệu file đã xóa: **199504586 bytes, khoảng 190,26 MiB**. Đây là tổng tại lúc xóa, không phải dung lượng ròng giảm sau pub get/build. Cache/package/build được tạo lại làm dung lượng repository local tăng trở lại.

Không xóa build hoặc APK chỉ để lấy chỗ. APK debug được lệnh build tạo lại theo yêu cầu. Ảnh/log render cũ và hồ sơ trình duyệt được giữ. Không xóa cache Flutter/Android SDK/Gradle toàn máy hoặc dữ liệu ngoài repository.

## File lớn và mục cần xem xét

- Trước: 4749 file kiểm kê, **27 file lớn hơn 10 MB**; danh sách đầy đủ trong [LARGE_FILES_BEFORE.csv](LARGE_FILES_BEFORE.csv).
- Sau các bước build/khởi động: **34 file lớn hơn 10 MB** tại lần kiểm kê; [LARGE_FILES_AFTER.csv](LARGE_FILES_AFTER.csv).
- File lớn thuộc build, native library, APK, cache Dart/package hoặc profile trình duyệt. Không tìm thấy asset sản phẩm >10 MB cần xóa. Giữ các file lớn có thể tạo lại khi chưa cần dọn.
- Không có tài liệu trùng hoàn toàn cần gộp. Các báo cáo UI/kiểm thử khác thời điểm được giữ để bảo toàn bằng chứng, kể cả kết quả cũ khác kết quả mới.
- P0/P1 có cả nội dung frontend và contract backend: giữ bản đầy đủ trong docs/customer, dẫn tới các section migration/RLS/RPC qua docs/backend/README.md để tránh nhân bản nội dung.

Đã tìm import/export, class, named route, callback, test và tham chiếu tài liệu của nhóm màn hình cũ. Giữ lại để xem xét:

```text
frontend/customer_app/lib/screens/account_screen.dart
frontend/customer_app/lib/screens/home_screen.dart
frontend/customer_app/lib/screens/history_screen.dart
frontend/customer_app/lib/screens/login_screen.dart
frontend/customer_app/lib/screens/payment_screen.dart
frontend/customer_app/lib/screens/provider_list_screen.dart
frontend/customer_app/lib/screens/request_form_screen.dart
frontend/customer_app/lib/screens/tracking_screen.dart
```

Các màn này không được main.dart route hiện tại trỏ tới, nhưng có tham chiếu nội bộ/tài liệu lịch sử và bản source chưa có commit làm mốc. Không xóa dựa vào tên hoặc warning unused; không sửa nghiệp vụ khi tổ chức repository. Không bỏ test hay làm yếu assertion.

## Đường dẫn/tham chiếu đã cập nhật

- Root README mới: cấu trúc, lệnh chạy/test/build trong frontend/customer_app, migration và cách áp thủ công, tài liệu, vị trí app người cứu hộ trong tương lai.
- 12 Markdown đã di chuyển: paths source/config/backend, link tài liệu giữa customer/backend, quy ước cwd cho lệnh Flutter/Dart và Node. Kết quả lịch sử giữ nguyên theo ngày báo cáo.
- tools/check_photo_policies.mjs: URL migration tương đối tới ../backend/supabase/migrations; hướng dẫn chạy từ root. Node --check đạt; chưa chạy test PostgreSQL nhúng hoặc test API từ xa.
- frontend/customer_app/.idea/vcs.xml: Git mapping tới root cách hai cấp; đây là cấu hình IDE local được ignore.
- frontend/customer_app/android/.gitignore: giữ Gradle wrapper jar/gradlew/gradlew.bat ở trạng thái có thể version để checkout mới có đủ bootstrap Android; tiếp tục ignore local.properties và signing.
- .gitignore root: ignore config riêng tại frontend/customer_app/config, cache/build, IDE, profile local, keystore, .env; hai JSON example vẫn có thể version.
- tools/use-local-cache.ps1: TEMP/TMP/PUB_CACHE riêng trong tools/.work, không thay cấu hình máy; không làm rò ErrorActionPreference khi dot-source.
- tools/audit-repository.ps1: kiểm kê chỉ đọc, xem preview ignore, file lớn và kiểm tra dấu hiệu credential trong file tracked/versionable.

## Bảo toàn nội dung và bảo mật

Đối chiếu **108 file** trước/sau di chuyển: nội dung ban đầu không đổi. Sau cập nhật cấu trúc, trong nhóm đó chỉ android/.gitignore được sửa như mô tả trên. lib, test, pubspec.yaml, pubspec.lock, Android Application ID và config riêng giữ nguyên bytes.

Tám SQL gồm sáu migration và hai SQL dev được đối chiếu SHA-256, giữ nguyên nội dung: [SQL_INTEGRITY.csv](SQL_INTEGRITY.csv). Không chạy migration, thay schema/RPC/RLS, đổi Supabase project hoặc tạo Edge Function/seed mới.

config/supabase.dev.json vẫn có ở app root mới, được Git ignore. Kiểm tra nội bộ không phát hiện service_role/secret key trong cấu hình Flutter; không in giá trị key. Audit kiểm tra file tracked và file có thể version không phát hiện credential-like value hoặc đường dẫn cấu hình riêng lọt qua ignore. Git hiện chưa có tracked file hoặc commit; không tuyên bố đã làm sạch lịch sử Git vì không có lịch sử từ đầu.

## Kết quả kiểm tra từ vị trí mới

| Lệnh/kiểm tra | Kết quả |
|---|---|
| flutter pub get | Exit 0, resolve thành công, pubspec và lockfile không đổi |
| flutter analyze --no-fatal-infos --no-fatal-warnings | Exit 0, 0 error; còn 4 warning và 40 info có sẵn trong các màn cũ |
| flutter test | Exit 0, **165/165 test qua** |
| flutter build apk --debug --dart-define-from-file=config/supabase.dev.json | Exit 0, APK tạo thành công |
| flutter run --debug --no-pub -d web-server --web-hostname=127.0.0.1 --web-port=8766 --dart-define-from-file=config/supabase.dev.json | Khởi động server từ frontend/customer_app |
| Chrome headless qua localhost | App mounted, title Cứu Hộ 24/7, đủ năm tab, 0 runtime exception trong lượt startup cuối |
| node --check tools/check_photo_policies.mjs | Exit 0 |
| Audit Git/ignore/credential cuối | Exit 0; 18250 file kiểm kê, 0 file tracked; cấu hình riêng được ignore, không phát hiện dấu hiệu credential trong file có thể version |
| File khóa/chưa di chuyển | **Không có** |

APK: frontend/customer_app/build/app/outputs/flutter-apk/app-debug.apk, **166200374 bytes** tại lần build này. Cảnh báo JVM/native access và Java source/target của plugin không làm build thất bại.

Log, result JSON và ảnh startup nằm trong tools/.work (ignore): pub-get.log, analyze.log, test.log, build-apk.log, build-apk-result.json, runtime-result.json, runtime-home.png, audit.log.

Lượt startup với giả lập mobile CDP ban đầu phát sinh assertion viewInsets không âm trong Flutter web engine. Chạy lại với viewport Chrome bình thường đạt 0 exception; đây là xác minh startup, không phải kiểm thử bàn phím/GPS/camera trên mobile. Trong probe đã chặn tile OSM công khai, không đăng nhập hoặc gửi đơn. Ảnh startup được xem trực tiếp. Không suy ra Supabase nghiệp vụ hoặc map tile thật đã được kiểm thử.

Bước build đầu bị server restart ngắt; lần khác bị PowerShell xử lý warning stderr như lỗi dừng. Đã sửa helper và lấy kết quả build cuối exit 0, không dùng APK cũ để tuyên bố build thành công.

D:\FlutterTemp và D:\FlutterCache\Pub bị chặn quyền ghi trên môi trường này. Các lệnh cuối dùng TEMP/TMP và PUB_CACHE trong tools/.work, không thay permission/cache toàn máy.

## Git status cuối và chạy lại

```text
?? .gitignore
?? README.md
?? backend/
?? docs/
?? frontend/
?? tools/
```

Root repo có ownership khác tài khoản Windows chạy công cụ. Dùng safe.directory theo từng lệnh cho đúng workspace, không sửa global exception:

```powershell
git -c safe.directory=D:/DAndroidStudioProjects/flutter_app status --short
```

Chạy lại app với cache local nếu cần:

```powershell
cd D:\DAndroidStudioProjects\flutter_app
.\tools\use-local-cache.ps1
cd frontend/customer_app
flutter run --debug -d 86ab44a0 --dart-define-from-file=config/supabase.dev.json
```

ADB không có thiết bị kết nối ở lúc kiểm tra; chưa cài/chạy APK trên OPPO CPH1931 và chưa kiểm thử Supabase thật. Cần xác minh hai phần đó trực tiếp trước khi kết luận về trải nghiệm thiết bị hoặc backend.

Kiểm tra tài liệu cuối: không có link Markdown nội bộ bị hỏng hoặc tài liệu trùng hoàn toàn. Hash source/SQL/config không có thay đổi ngoài android/.gitignore đã chủ động cập nhật; không mất dữ liệu hay thay đổi người dùng.
