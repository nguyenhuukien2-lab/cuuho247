# ĐÁNH GIÁ FRONTEND APP KHÁCH HÀNG CỨU HỘ 24/7

> Đường dẫn đã cập nhật sau khi tổ chức repository. Các đường dẫn file bên dưới tính từ Git root; lệnh Flutter/Dart chạy trong `frontend/customer_app` (từ root: `cd frontend/customer_app`), lệnh Node/tools chạy từ root. Kết quả kiểm thử cũ được giữ theo thời điểm của báo cáo; xem [CLEANUP_REPORT.md](../CLEANUP_REPORT.md) cho kết quả sau di chuyển.

**Ngày khảo sát:** 30/09/2026  
**Phạm vi:** mã Flutter trong `flutter_app`, app khách hàng, 5 tab và các màn hình phụ có trong dự án.  
**Hình thức:** chỉ đọc mã, kiểm tra cấu trúc và thử chạy công cụ sẵn có; không sửa mã/cấu hình, không gọi backend và không thay đổi dữ liệu người dùng.

## 1. Tóm tắt hiện trạng

Frontend hiện là một **prototype giao diện có thể mô phỏng luồng** chứ chưa phải app cứu hộ hoạt động thực tế. Route đang chạy dùng nhóm màn hình `new_*`, `AppController` và dữ liệu trong RAM. Người dùng có thể chọn xe/dịch vụ, điền form, tạo yêu cầu demo, tự bấm chuyển các trạng thái, hủy, xem lịch sử và mở màn thanh toán demo. Không bước nào trong luồng này gọi backend.

Điểm tích cực đã xác nhận từ mã:

- Có đủ 5 tab đúng nhãn: Trang chủ – Cứu hộ – Đang xử lý – Lịch sử – Tài khoản.
- Dùng `IndexedStack`, `PageStorageKey` và `AutomaticKeepAliveClientMixin` cho form cứu hộ, nên state tab/form được giữ trong vòng đời của cùng `AppShell`.
- Theme Material 3, bảng màu navy/cam, typography, card, input được tập trung hóa; CTA “Gọi cứu hộ” rõ trong code.
- Form có validation cơ bản; nút submit/auth bị vô hiệu hóa khi đang giả lập xử lý; controller được `dispose` đúng ở các form đang dùng.
- Có empty state cho Đang xử lý/Lịch sử và dialog xác nhận hủy yêu cầu.

Khoảng trống cốt lõi:

- Toàn bộ nghiệp vụ chính đang ở `demoMode = true`; không gửi yêu cầu, không theo dõi vị trí, không báo giá thật, không thanh toán thật.
- Đăng nhập/đăng ký chấp nhận dữ liệu hợp lệ về mặt form mà không xác thực; session chỉ là biến `static` trong RAM.
- Bản đồ, GPS, ảnh, gọi điện, chat, hồ sơ, phương tiện, địa chỉ và cài đặt chưa triển khai.
- Không có quên mật khẩu, màn thông báo, màn chat hay đánh giá trong route hiện hành.
- Chưa có mô hình trạng thái tải/lỗi/mất mạng/hết phiên/quyền thiết bị cho luồng thật.
- Có một bộ màn hình cũ lớn vẫn nằm trong source nhưng không được `main.dart` route tới, gây trùng lặp và dễ sửa nhầm.

> Lưu ý bằng chứng: PowerShell `Get-Content` mặc định từng in chuỗi Unicode sai encoding trong terminal, nhưng đọc UTF-8 và `rg` xác nhận source tiếng Việt đúng dấu. Đây **không** được ghi nhận là lỗi UI.

## 2. Kiến trúc và nguồn dữ liệu thực tế

Luồng route được khai báo tại `frontend/customer_app/lib/main.dart:36-46`. `/`, `/home`, `/request`, `/tracking`, `/history`, `/account` đều tạo `AppShell`; `/login` mở `NewAuthScreen`; `/payment` mở `PaymentScreen`.

| Thành phần | Thực tế |
|---|---|
| State toàn app | Một `AppController` (`ChangeNotifier`) sống trong `RescueApp`; dữ liệu chỉ trong RAM (`frontend/customer_app/lib/app/app_controller.dart`). |
| Backend ở route hiện hành | Không màn hình đang dùng nào import/gọi `SupabaseService`. |
| Backend code có sẵn | `frontend/customer_app/lib/services/supabase_service.dart` có HTTP cho quick-task/provider/history/create request qua biến compile-time, nhưng bị nuốt mọi lỗi thành `null`/`[]` và hiện không nối vào UI đang chạy. |
| Session | Các biến `static` trong `frontend/customer_app/lib/app/user_session.dart`; mất khi app khởi động lại; không token, không refresh, không secure storage. |
| Dữ liệu mẫu | Địa chỉ, helper, giá 170.000đ, ba lịch sử, chi tiết thanh toán và thời gian/mã yêu cầu mẫu được hard-code. |
| Bản đồ | `MapPreview` là `CustomPainter`, không phải bản đồ/GPS thật (`frontend/customer_app/lib/widgets/rescue_widgets.dart:100-166`). |
| Ảnh sự cố | Chỉ bật/tắt một placeholder bằng boolean, không chọn/chụp/upload file. |

## 3. Kiểm kê màn hình và chức năng

### 3.1. Các màn hình đang reachable

| Màn hình / file | Cách mở | Thành phần, trường và hành động | Nguồn dữ liệu | Mức hoàn thiện |
|---|---|---|---|---|
| **Trang chủ** — `frontend/customer_app/lib/screens/new_home_screen.dart` | Route `/`, `/home` hoặc tab 1 | Header/thông báo; địa chỉ; bản đồ giả; chọn xe máy/ô tô; 4 dịch vụ; CTA Gọi cứu hộ; card “Theo dõi” khi có request | `AppController`, toàn bộ vị trí/helper mẫu | UI + chọn state có xử lý. Thông báo/đổi vị trí/GPS chỉ SnackBar. CTA chỉ chuyển tab Cứu hộ. |
| **Cứu hộ** — `frontend/customer_app/lib/screens/new_request_screen.dart` | Tab 2, `/request`, CTA Trang chủ, “Tạo yêu cầu” | Chọn xe; 5 loại sự cố; địa chỉ bắt buộc; mô tả; thêm/xóa ảnh giả; họ tên và SĐT bắt buộc; giá “Chờ báo giá”; nút Tìm người hỗ trợ | Controller + `UserSession`; địa chỉ mẫu; không backend | Validation và chống double tap khi delay hoạt động. GPS/map/ảnh chưa làm. Submit tạo request RAM sau 500 ms. |
| **Đang xử lý** — `frontend/customer_app/lib/screens/new_tracking_screen.dart` | Tab 3, `/tracking`, card Theo dõi | Empty state; map giả; mã/trạng thái; progress; dịch vụ/xe/vị trí/chi phí; helper giả; gọi/chat; hủy; nút tự chuyển trạng thái; thanh toán | Active request RAM; helper/giá mẫu | Hủy có xác nhận và được lưu lịch sử RAM. Gọi/chat chỉ SnackBar. Không realtime/API/timestamp vị trí. Người dùng tự điều khiển trạng thái demo. |
| **Lịch sử** — `frontend/customer_app/lib/screens/new_history_screen.dart` | Tab 4, `/history`, sau hủy/archive | Bộ lọc Tất cả/Hoàn tất/Đã hủy; card ngày giờ/địa chỉ/xe/giá; bottom sheet chi tiết; Yêu cầu lại | 3 bản ghi hard-code + request phiên hiện tại | Lọc, empty state, mở chi tiết, repeat sang form đã có. Không API, phân trang, refresh, invoice hay đánh giá. |
| **Tài khoản** — `frontend/customer_app/lib/screens/new_account_screen.dart` | Tab 5, `/account` | Profile; đăng nhập/chỉnh sửa; nhóm tài khoản/cài đặt/hỗ trợ; đăng xuất | `UserSession` RAM | Payment và login mở được. Hầu hết mục còn lại báo “chưa triển khai”. Đăng xuất không có dialog. |
| **Đăng nhập / đăng ký** — `frontend/customer_app/lib/screens/new_auth_screen.dart` | `/login`, nút ở Tài khoản | Segmented login/register; họ tên, email, SĐT, mật khẩu; hiện/ẩn mật khẩu; tiếp tục không đăng nhập | Chỉ `UserSession` RAM | Form/loader có. Không xác thực backend; mọi mật khẩu >= 6 ký tự đều “đăng nhập”; không quên mật khẩu/OTP/error server. |
| **Thanh toán** — `frontend/customer_app/lib/screens/payment_screen.dart` | `/payment` từ Tài khoản hoặc request hoàn tất demo | Breakdown chi phí; 4 phương thức; nút xác nhận; back | Toàn bộ hard-code | Chọn radio có state. Nút xác nhận chỉ push `/history`, không thanh toán, không loading/error/idempotency. Nội dung vẫn tuyên bố thành công/PCI-DSS/bảo hành. |

### 3.2. Màn hình/chức năng được yêu cầu nhưng không tồn tại ở route hiện hành

| Chức năng | Kết quả |
|---|---|
| Quên mật khẩu | Không có UI/route. |
| Trung tâm thông báo | Không có màn; chuông Trang chủ chỉ hiện “chưa có thông báo mới”. |
| Nhắn tin | Không có màn; nút chỉ báo chưa cấu hình. |
| Đánh giá | Không có trong nhóm màn hình hiện hành. UI đánh giá chỉ xuất hiện trong `history_screen.dart` legacy, không reachable. |
| Chỉnh sửa hồ sơ/phương tiện | Có menu nhưng chỉ SnackBar “chưa triển khai”. |
| Chi tiết phương tiện/xóa phương tiện | Không có, do đó cũng không có dialog xác nhận xóa. |
| Danh sách nhà cung cấp | `provider_list_screen.dart` tồn tại nhưng route `/providers` không được đăng ký và luồng hiện hành không mở màn này. |

### 3.3. Mã màn hình legacy, hiện không reachable

`home_screen.dart`, `request_form_screen.dart`, `provider_list_screen.dart`, `tracking_screen.dart`, `history_screen.dart`, `account_screen.dart`, `login_screen.dart` là bộ UI cũ. `main.dart` không import/route tới các class này. `payment_screen.dart` là ngoại lệ: file kiểu cũ nhưng vẫn được route hiện hành dùng.

Nhóm legacy có nhiều handler rỗng (`onPressed: () {}`), URL ảnh internet hard-code và một số kết nối Supabase rời rạc (đăng ký/provider). Không được tính là chức năng đã có. Đặc biệt, `request_form_screen.dart` còn gọi `/providers`, nhưng route này không tồn tại trong `main.dart`; nếu code legacy được nối lại sẽ gây lỗi route.

## 4. Đánh giá thiết kế giao diện (từ mã nguồn)

### Đã xác nhận từ mã

- **Material 3/tối giản:** `useMaterial3: true`; nền `#F6F8FB`, navy `#12304A`, cam `#E85D04`, surface trắng. Theme tập trung tại `frontend/customer_app/lib/app/app_theme.dart`.
- **Phân cấp:** headline 24, title 20/16, body 16/14/12; card 18 px, input 14 px; phần lớn màn hình dùng khoảng lề ngang 18–20 px, section gap 10–24 px.
- **CTA cứu hộ:** `PrimaryButton` cao 52 px, nền cam, full width (`frontend/customer_app/lib/widgets/rescue_widgets.dart:6-28`) và đặt sau lựa chọn dịch vụ.
- **Nhất quán nhóm `new_*`:** dùng chung `AppColors`, `SectionTitle`, `ChoiceTile`, `StatusPill`, `MapPreview`, `PrimaryButton`.
- **Không nhất quán còn lại:** `payment_screen.dart` hard-code palette xanh `#1565C0` và đỏ `#C1121F`, radius 16/20/100, không dùng `AppTheme`/`PrimaryButton`. Nhóm legacy dùng một hệ màu/spacing khác.
- **Tiếng Việt:** source UTF-8 có dấu đầy đủ ở route hiện hành. Tên package description trong `frontend/customer_app/pubspec.yaml` hiển thị mojibake khi đọc, nhưng không phải text UI runtime.
- **Mật độ:** bottom nav dùng font 10.5 px; badge/metadata payment xuống tới 9–11 px, nhỏ đối với điện thoại và tăng cỡ chữ.
- **Icon:** dùng Material Icons nhất quán trong nhóm mới, nhưng một số icon-only control không có tooltip/nhãn semantic rõ (chuông, back, định vị, xóa ảnh).

### Chưa xác minh bằng chạy app

Không có quan sát runtime hợp lệ về rendering, màu thực tế, overflow, camera cutout, bàn phím, cỡ chữ lớn hay touch target. Ba ảnh PNG có sẵn (`widget_preview_capture*.png`) đều chỉ là khung trắng 1280×900, không chứng minh được UI. Vì vậy không kết luận giao diện “hiển thị tốt”.

## 5. Đánh giá từng tab

### Trang chủ

- Bản đồ chiếm 245 px, có địa chỉ một dòng và chip “3 người hỗ trợ”; bố cục dễ nhận biết từ mã, nhưng bản đồ chỉ là hình vẽ và địa chỉ cố định.
- Chọn xe/dịch vụ → CTA có trình tự ngắn, CTA kiểm tra đã chọn dịch vụ trước khi chuyển tab.
- Khi có request, card “Yêu cầu đang xử lý / Theo dõi” xuất hiện và mở tab 3.
- Không đổi vị trí thật, không trạng thái quyền/location/loading/error, không dữ liệu helper thật.

### Cứu hộ

- Trình tự xe → sự cố → vị trí → mô tả → ảnh → liên hệ → gửi là hợp lý.
- Field bắt buộc chỉ thể hiện qua validator sau submit; label không có dấu `*` hay chú giải “bắt buộc”. Số điện thoại chỉ kiểm tra rỗng, không kiểm tra định dạng.
- Mô tả multiline và toàn màn cuộn được; keyboard dismiss khi kéo. GPS/map và thêm ảnh là mô phỏng.
- `submitting` khóa nút qua `PrimaryButton`, giảm double submit.
- Form được keep-alive khi đổi tab trong cùng shell; dữ liệu sẽ mất khi app restart hoặc khi tạo `AppShell` mới qua named route. Không có draft persistence.
- Không có nhánh submit lỗi thật; vì delay luôn thành công nên chưa thể kiểm tra “giữ dữ liệu khi lỗi”.

### Đang xử lý

- Có status pill, linear progress khi tìm và 4 bước khi đã nhận; trạng thái hiện tại dễ suy ra từ mã.
- “Chi phí” hiển thị 170.000đ ngay từ request demo dù form nói “Chờ báo giá”; không có quy trình nhận/xác nhận báo giá.
- Helper xuất hiện sau searching nhưng luôn “Chưa có dữ liệu”; gọi/chat không hoạt động.
- Hủy chỉ có ở searching/accepted và có dialog rõ. Không hủy khi arriving/assisting; chưa có giải thích chính sách.
- Không có timestamp/độ mới của vị trí, last updated, kết nối realtime hoặc stale indicator.
- Nút “Chuyển trạng thái tiếp theo (demo)” đặt quyền điều khiển backend vào tay khách hàng, chỉ phù hợp prototype.

### Lịch sử

- Card gọn, có status/ngày giờ/địa chỉ/xe/giá; bộ lọc và empty state đã có.
- Mở bottom sheet chi tiết và repeat request hoạt động trên state RAM.
- Không search/date filter/pagination/lazy backend. Với list lớn, `SliverList.list(children: [...items.map])` dựng toàn bộ item cùng lúc — nguy cơ hiệu năng từ mã, chưa đo.
- Giá null hiển thị “Chưa có”; formatting tiền dùng hàm tự viết, chưa locale-aware.

### Tài khoản

- Menu được nhóm thành Tài khoản/Cài đặt/Hỗ trợ; profile khách và người đăng nhập phân biệt rõ.
- Chỉnh hồ sơ, phương tiện, địa chỉ, thông báo, hotline, điều khoản đều chỉ phản hồi “chưa triển khai”; phản hồi rõ nhưng chức năng chưa có.
- Đăng xuất xóa RAM và chuyển root, không xác nhận, không revoke token (vì không có token).
- Mục “Thanh toán” mở hóa đơn hard-code đã thành công dù không gắn với request — gây hiểu nhầm nghiêm trọng.

## 6. Điều hướng và bảo toàn state

| Nội dung | Kết quả từ mã |
|---|---|
| 5 tab/nhãn/selected | Đủ và selected theo `controller.tabIndex`; `IndexedStack` giữ cây widget. |
| Chuyển tab | Gọi `selectTab`, không chất thêm route. Tốt trong cùng `AppShell`. |
| Back màn phụ | Auth/payment có nút back; Android/system back chưa chạy xác minh. |
| Form khi đổi tab | Controller text + keep-alive; giữ trong cùng shell. |
| Scroll khi đổi tab | Home/tracking có `PageStorageKey`; request vừa key vừa keep-alive. History/account không có explicit key nhưng các widget trong `IndexedStack` không bị dispose. Chưa chạy xác minh vị trí scroll thực tế. |
| Route named tới tab | Mỗi route tạo một `AppShell` mới nhưng dùng chung controller; có thể tạo nhiều shell trên navigator stack và làm back quay qua các shell/tab cũ. Đây là nguy cơ vòng điều hướng/state UI, chưa tái hiện runtime. |
| Luồng Home → Request → Tracking → History | Có thể mô phỏng hoàn chỉnh trong RAM. Hoàn tất phải tự bấm tiến trạng thái nhiều lần; thanh toán archive trước rồi push payment; payment lại push `/history`, tạo thêm shell. |
| Deep link notification | Không triển khai. |
| Màn cụt | Các menu chưa triển khai chỉ SnackBar; payment xác nhận không có kết quả thanh toán mà chuyển lịch sử. |
| Confirm destructive | Hủy request có dialog. Đăng xuất không có dialog. Xóa phương tiện chưa tồn tại. |

## 7. Trạng thái và phản hồi UI

| Trạng thái | Hiện trạng |
|---|---|
| Đang tải | Có spinner/disable cho auth và gửi form demo; tracking searching có progress vô hạn. Không có loading backend/list. |
| Trống | Có Đang xử lý và Lịch sử theo filter. Không có empty notification/provider vì màn tương ứng không hoạt động. |
| Mất mạng/server lỗi | Không có trong route hiện hành. `SupabaseService` nuốt lỗi nhưng không được dùng. |
| Thử lại | Không có. |
| Hết phiên | Không có khái niệm token/expiry. |
| Từ chối quyền | Không request quyền location/camera/notification; chỉ báo chưa cấu hình. |
| Thành công/thất bại | Auth và request demo luôn báo thành công sau delay. Payment chuyển lịch sử không xác nhận giao dịch. Không có failure path. |
| Bấm nhiều lần | Auth/request được disable khi loading. Payment, demo advance và các action khác không có pending guard/idempotency. |
| Giữ input khi lỗi | Chưa thể đánh giá vì không có nhánh lỗi submit thật. |

## 8. Chất lượng mã frontend

### Điểm tốt

- `app/`, `screens/`, `widgets/`, `services/` đã tách lớp cơ bản; theme và widget dùng chung giúp nhóm màn hình mới nhất quán.
- UI và state demo tách qua `AppController`; các mutation có `notifyListeners` rõ ràng.
- `TextEditingController` ở màn auth/request đều được dispose; `AppController` cũng được dispose ở root.
- Không thấy subscription/timer sống lâu cần hủy trong route hiện hành.

### Nguy cơ/vấn đề từ mã (chưa phải lỗi hiệu năng đã đo)

- `AppController` trộn navigation index, domain state, mock data và nghiệp vụ; không có repository/interface cho trạng thái thật.
- Hai bộ màn hình song song (~nhiều nghìn dòng) và nav/widget bị lặp; dễ divergence, tăng chi phí bảo trì.
- `payment_screen.dart` là widget lớn, hard-code dữ liệu/màu và không nhận request/payment model.
- `new_history_screen.dart` nén nhiều widget vào dòng rất dài, khó review/test.
- `SupabaseService` bắt mọi exception và trả `null`/`[]`, làm UI không thể phân biệt empty với lỗi/mất mạng/401; không timeout, typed result hay auth token user.
- `fetchUserRequests` ghép `customerId` trực tiếp vào query string thay vì queryParameters.
- Không có dependency cho secure storage, location, image picker, notification hoặc map; session RAM không đáp ứng đăng nhập thật.
- History dựng eager toàn bộ danh sách; chưa có pagination. Chưa có phép đo để kết luận chậm.
- `AppShell.build` tạo danh sách page/widget mới mỗi lần controller notify; state thường được Element giữ theo vị trí, nhưng vẫn tạo object/rebuild cả stack. Chưa profile nên chỉ ghi nhận nguy cơ.
- Không thấy test directory/test widget/unit trong phạm vi dự án.

## 9. Bảng vấn đề cần xử lý

| Mã | Màn hình | Mô tả và bằng chứng | Cách tái hiện | Ảnh hưởng | Ưu tiên | Đề xuất | Xác minh |
|---|---|---|---|---|---|---|---|
| FE-001 | Toàn luồng | Core flow chỉ dùng `demoMode=true`, delay và RAM; active UI không gọi service. `app_controller.dart:46-137`, `new_request_screen.dart:47-63` | Chọn dịch vụ → gửi → tự bấm chuyển trạng thái | Không thể gọi cứu hộ thật | **P0** | Nối repository/API thật; state machine do server điều khiển; tách demo build flag rõ ràng | Đã xác nhận từ mã |
| FE-002 | Auth | Mọi SĐT + mật khẩu >=6 ký tự đều tạo session; không backend/token. `new_auth_screen.dart:32-46` | Nhập dữ liệu bất kỳ hợp lệ → Đăng nhập | Giả đăng nhập, không bảo mật/không định danh | **P0** | Auth API, token lifecycle, secure storage, lỗi 401/timeout, logout revoke | Đã xác nhận từ mã |
| FE-003 | Payment | Toàn bộ hóa đơn hard-code; nút “Xác nhận thanh toán” chỉ push history. `payment_screen.dart:56-106,197-208` | Mở Payment từ Tài khoản → xác nhận | Có thể khiến người dùng tin đã thanh toán; thông tin sai | **P0** | Ràng buộc request/payment thật; trạng thái pending/success/fail; idempotency; chỉ tuyên bố sau server confirm | Đã xác nhận từ mã |
| FE-004 | Request/Home | Map/GPS/address là mẫu; chỉnh vị trí và định vị chỉ SnackBar. `new_home_screen.dart:59-86`, `new_request_screen.dart:139-156` | Bấm Thay đổi/định vị/chỉnh vị trí | Sai điểm cứu hộ, chặn mục đích chính | **P0** | Permission flow, map picker, geocoding, độ chính xác/timestamp, fallback nhập tay | Đã xác nhận từ mã |
| FE-005 | Tracking | Theo dõi không realtime; map minh họa; không timestamp/stale state. `new_tracking_screen.dart:55-59` | Tạo request demo → Tracking | Không biết helper ở đâu/dữ liệu còn mới không | **P0** | Realtime/polling có lifecycle, last updated, stale/offline/retry UI | Đã xác nhận từ mã |
| FE-006 | Request | Thêm ảnh chỉ đổi boolean và placeholder. `new_request_screen.dart:171-204` | Bấm Thêm ảnh | Không gửi được bằng chứng sự cố | **P1** | Camera/gallery, permission denial, preview/compress/upload/remove/retry | Đã xác nhận từ mã |
| FE-007 | Tracking | Gọi điện/nhắn tin chỉ SnackBar; helper không có dữ liệu. `new_tracking_screen.dart:124-150,309-332` | Sau searching, bấm Gọi/Nhắn | Không liên hệ được khi khẩn cấp | **P1** | Dialer/chat thật, chỉ hiện khi có provider/contact và đúng trạng thái | Đã xác nhận từ mã |
| FE-008 | Request | Giá form “Chờ báo giá” nhưng request demo gán 170.000đ; không bước xác nhận quote. `new_request_screen.dart:232-253`, `app_controller.dart:101-115` | Tạo request → Tracking | Giá không đáng tin, thiếu consent | **P1** | Quote model/version/expiry; accept/reject; hiển thị breakdown | Đã xác nhận từ mã |
| FE-009 | State/error | Không có network/server/session/permission error và retry trong active flow | Không thể tái hiện vì không gọi backend | App không hướng dẫn phục hồi khi lỗi thật | **P1** | Chuẩn hóa AsyncState + thông báo hành động được; retry; auth expiry redirect | Đã xác nhận thiếu từ mã |
| FE-010 | Navigation | Named route tạo thêm `AppShell`; payment push `/history`; nguy cơ stack nhiều shell/back khó hiểu. `main.dart:36-43`, `payment_screen.dart:197` | Hoàn tất → payment → history → system back (chưa chạy) | Có thể quay về trạng thái/tab cũ bất ngờ | **P1** | Một shell duy nhất; nested router hoặc replace/popUntil; route typed | Nguy cơ từ mã, chưa tái hiện |
| FE-011 | Account | Hầu hết menu chỉ “chưa triển khai”; payment mở hóa đơn không liên quan. `new_account_screen.dart:88-129` | Bấm từng mục | Luồng cụt, tạo kỳ vọng sai | **P1** | Ẩn/disable có giải thích đến khi làm; triển khai profile/vehicle/settings theo ưu tiên | Đã xác nhận từ mã |
| FE-012 | Auth | Không có quên mật khẩu/OTP; validation SĐT/email yếu | Mở login | Người dùng không khôi phục tài khoản; dữ liệu sai | **P1** | Forgot-password/OTP; validator theo backend/locale | Đã xác nhận từ mã |
| FE-013 | Accessibility | Font nav 10.5, payment 9–11; thiếu explicit semantics/tooltip cho icon action | Tăng text scale/screen reader (chưa chạy) | Nguy cơ khó đọc/khó dùng trợ năng | **P1** | Test 200% text; semantic labels/tooltips; min 48×48; không chỉ dựa màu | Nguy cơ từ mã, chưa chạy |
| FE-014 | Responsive | Payment có nhiều `Row` với text dài/Spacer cố định; nguy cơ overflow ở màn nhỏ/text lớn | Thiết bị nhỏ/text 200% (chưa chạy) | Nội dung/nút có thể vỡ hoặc bị che | **P1** | `Wrap`/Flexible; golden/widget tests nhiều constraints; keyboard tests | Nguy cơ từ mã, chưa chạy |
| FE-015 | Persistence | Request/history/form/session chỉ RAM; restart mất hết | Restart app (chưa chạy) | Mất phiên, draft và theo dõi request | **P1** | Backend source of truth + local cache/draft; resume active request | Đã xác nhận kiến trúc; runtime chưa chạy |
| FE-016 | Request | Field bắt buộc không đánh dấu trước submit; phone chỉ non-empty | Mở form/gửi phone bất kỳ | Tăng lỗi nhập liệu | **P2** | Dấu *, helper text, format/normalize SĐT, focus field lỗi đầu tiên | Đã xác nhận từ mã |
| FE-017 | History | Không pagination; eager children; dữ liệu mẫu, thiếu refresh | Tạo danh sách lớn (chưa có backend) | Nguy cơ chậm và khó tìm bản ghi | **P2** | Paged SliverList, pull-to-refresh, filter ngày/search | Nguy cơ từ mã |
| FE-018 | Codebase | Hai thế hệ màn hình và nav/widget trùng lặp; legacy có handler rỗng/route thiếu | Tìm `class *Screen`, handler rỗng | Sửa nhầm, divergence, tăng bug | **P2** | Xác nhận bộ chuẩn rồi loại/di chuyển legacy; dùng router/nav/component chung | Đã xác nhận từ mã |
| FE-019 | Service | HTTP nuốt lỗi thành empty/null, không timeout/typed error/401 handling. `supabase_service.dart:11-118` | Cấu hình server lỗi (chưa gọi từ UI) | Không phân biệt trống và lỗi, khó retry | **P1** | Typed Result/Error, timeout, auth header user, logging an toàn | Đã xác nhận từ mã |
| FE-020 | Logout/destructive | Logout không confirm; xóa phương tiện chưa tồn tại | Bấm Đăng xuất | Dễ logout nhầm; yêu cầu confirm xóa chưa đáp ứng | **P2** | Dialog/undo phù hợp; confirm delete vehicle khi triển khai | Đã xác nhận từ mã |
| FE-021 | Notifications/chat/rating | Không có màn/route active | Tìm route và action | Thiếu các luồng hậu cứu hộ/giao tiếp | **P2** | Thiết kế route + empty/loading/error/deep link trước khi bật entry point | Đã xác nhận từ mã |
| FE-022 | Visual consistency | Payment/legacy dùng palette/radius riêng, không theo AppTheme | So sánh source | Trải nghiệm thiếu đồng bộ | **P2** | Refactor payment dùng token/widget chung | Đã xác nhận từ mã |
| FE-023 | Testability | Không có thư mục/test frontend | `Test-Path test` | Regression nav/state/responsive khó phát hiện | **P2** | Unit controller, widget flow/error/a11y, golden nhiều size/text scale | Đã xác nhận |

## 10. Kiểm tra thực tế đã thực hiện

| Lệnh/thao tác | Kết quả |
|---|---|
| `rg --files`, đọc toàn bộ file `lib`, tìm route/handler/API/controller/lifecycle | Thành công; dùng làm bằng chứng kiểm kê và đánh giá tĩnh. |
| `git status --short` | Thành công. Worktree đã có rất nhiều thay đổi/untracked trước khảo sát; không can thiệp. Chỉ file báo cáo này được thêm bởi lần đánh giá. |
| `flutter --version; flutter analyze; flutter test; flutter devices` | **Không hoàn tất**: lệnh không trả bất kỳ output nào sau >90 giây và phải ngắt. Không ghi nhận pass/fail analyzer/test/device. |
| `dart analyze lib` | **Không hoàn tất**: không trả output sau 30 giây; cùng dấu hiệu toolchain/Dart process bị treo/khóa. |
| Kiểm tra test directory | Không có thư mục `test`; không có test frontend để chạy. |
| Xem `frontend/customer_app/build/legacy-preview/widget_preview_capture.png`, `_2`, `_chrome` | File mở được nhưng chỉ là ảnh trắng 1280×900; không dùng làm bằng chứng UI. |
| Chạy app trên thiết bị/kích thước khác nhau | **Chưa xác minh** vì toolchain không phản hồi; không có thiết bị/emulator được xác nhận. |

### Ma trận hiển thị điện thoại

| Hạng mục | Trạng thái |
|---|---|
| Màn nhỏ/overflow | Chưa xác minh; có nguy cơ tại Payment và row action dài. |
| Status bar/camera cutout/system nav | Chưa xác minh. Mã dùng `SafeArea` quanh shell và bottom nav; payment/auth cũng dùng `SafeArea`. |
| Bàn phím che field/nút | Chưa xác minh. Shell bật `resizeToAvoidBottomInset`; request cuộn được và dismiss on drag; auth `SingleChildScrollView`. |
| Nội dung dài/cuộn | Có scroll container trong các màn chính từ mã; chưa xác minh runtime. |
| Text scale lớn | Chưa xác minh; nguy cơ font nhỏ/fixed row. |
| Touch target/screen reader | Chưa xác minh; một số nút đặt min height 48/52, nhưng chưa audit semantics runtime. |

Không có ảnh minh chứng UI hợp lệ để đính kèm. Không dùng tài khoản thật và không phát sinh thay đổi dữ liệu.

## 11. Chấm điểm có căn cứ

Do không chạy được app trên thiết bị, mục **Hiển thị và khả năng tiếp cận (15 điểm)** được ghi **Chưa đánh giá**. Không quy đổi kết quả dưới đây thành điểm hoàn thiện toàn app.

| Hạng mục | Điểm | Căn cứ |
|---|---:|---|
| Thiết kế và tính nhất quán | **15/20** | Theme M3/navy-cam/component dùng chung tốt ở nhóm mới; CTA rõ. Trừ vì payment/legacy lệch hệ và font metadata nhỏ. Đánh giá từ mã, chưa quan sát runtime. |
| Điều hướng và trải nghiệm | **13/20** | 5 tab, IndexedStack, flow demo, detail/repeat/confirm cancel có; trừ route chồng AppShell, nhiều màn cụt và thiếu deep link/secondary flows. |
| Mức hoàn thiện tương tác | **6/20** | Form/chọn/filter/dialog/demo state có; hầu hết nghiệp vụ chính, GPS/ảnh/call/chat/payment/auth chưa thật. |
| Hiển thị và khả năng tiếp cận | **Chưa đánh giá (0/15 không tính)** | Không chạy được thiết bị; chỉ xác định nguy cơ tĩnh, không đủ bằng chứng chấm. |
| Xử lý tải, lỗi và trạng thái trống | **5/15** | Có loader demo và 2 empty state; gần như thiếu toàn bộ network/error/retry/session/permission/failure. |
| Chất lượng mã FE | **6/10** | Theme/widget/controller/lifecycle cơ bản ổn; trừ legacy duplicate, mock hard-code, service nuốt lỗi, thiếu repository/test/persistence. |
| **Tổng phần đã đánh giá** | **45/85** | Chỉ phản ánh kiểm tra tĩnh trên 85 điểm có đủ bằng chứng; **không phải 53/100 và không phải điểm toàn app**. |

## 12. Danh sách việc ưu tiên làm tiếp

### Cần sửa trước

1. Chốt API contract và thay toàn bộ luồng demo bằng request/auth/tracking/payment thật; server là nguồn trạng thái duy nhất.
2. Làm vị trí thật: permission, GPS, map picker, địa chỉ thủ công và độ mới/độ chính xác.
3. Không hiển thị “đã cứu hộ/đã thanh toán/PCI-DSS/bảo hành” từ dữ liệu hard-code; xây state pending/success/failure/idempotency.
4. Bổ sung failure/retry/offline/401/session-expired cho mọi lời gọi; không nuốt lỗi thành danh sách trống.
5. Làm provider/contact/call/chat và quote acceptance theo đúng trạng thái nghiệp vụ.
6. Sửa kiến trúc navigation về một shell, kiểm thử back stack của luồng Home → Request → Tracking → Payment → History.

### Nên cải thiện

1. Camera/gallery/upload ảnh với permission denial và retry.
2. Persistence/resume active request, session bảo mật và draft form.
3. Profile/phương tiện/cài đặt; ẩn hoặc disable entry chưa có để tránh màn cụt.
4. Forgot password/OTP, validation SĐT/email và đánh dấu field bắt buộc.
5. Chuẩn hóa Payment theo theme/component mới; responsive với màn nhỏ và text scale 200%.
6. Thêm Semantics/tooltip, kiểm touch target, contrast và screen reader.
7. Unit/widget/golden tests cho state machine, validation, tab state, back stack, empty/error/loading và nhiều viewport.

### Có thể làm sau

1. Search/filter ngày/pagination/pull-to-refresh lịch sử; invoice và rating.
2. Notification center và deep link đúng request.
3. Dọn/di chuyển bộ màn hình legacy sau khi xác nhận không còn tham chiếu.
4. Profile hiệu năng bằng DevTools trước khi tối ưu rebuild/list; không tối ưu chỉ dựa trên suy đoán.

## 13. Kết luận

App đã có nền giao diện demo tương đối gọn, nhất quán và mô tả được hành trình người dùng. Tuy nhiên mức hoàn thiện chức năng frontend phục vụ sử dụng thực tế còn thấp vì các điểm sống còn — xác thực, vị trí, gửi yêu cầu, điều phối, theo dõi, liên hệ, báo giá và thanh toán — đều chưa nối nghiệp vụ thật. Ưu tiên tiếp theo nên là biến luồng demo thành state machine dựa trên backend, bổ sung đầy đủ trạng thái lỗi/phục hồi, rồi mới xác minh responsive/accessibility trên thiết bị thật và hoàn thiện các màn phụ.
