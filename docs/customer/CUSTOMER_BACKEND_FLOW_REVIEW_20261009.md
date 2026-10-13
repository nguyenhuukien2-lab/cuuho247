# Review backend customer app — 2026-10-09

## Phạm vi và bằng chứng

Review working tree hiện tại (bao gồm thay đổi UI chưa commit), `frontend/customer_app`, toàn bộ 8 migration trong `backend/supabase`, cùng 2 migration admin ảnh hưởng schema chung. Route thật: `main.dart` → `AppShell` → `New*Screen`; các màn hình legacy không được dùng làm bằng chứng lỗi production. Không commit, không deploy, không đổi business rule.

Báo cáo phần A–E được ghi **trước khi sửa code**. Line dưới đây là vị trí ở working tree trước sửa. Kết quả kiểm thử/sửa sẽ ghi ở cuối. Review tĩnh không xác nhận migration nào đã chạy trên DB thật. Docker daemon local không kết nối được; không chạy SQL mutation vào môi trường thật.

## A. BLOCKER

Chưa xác nhận blocker trên contract migration đầy đủ. Thiếu migration khi triển khai là rủi ro môi trường, chưa có bằng chứng để gọi là lỗi đang xảy ra.

## B. HIGH

### BE-01 — Cache đơn vẫn tồn tại sau khi phát hiện session hết hạn

- Flow: auth → refresh active/history → logout cleanup.
- File/line: `frontend/customer_app/lib/app/app_controller.dart:206`; `new_tracking_screen.dart:223` đọc activeRequest.
- DB/RPC: SELECT `rescue_requests`; PostgREST PGRST301/302/303.
- Nguyên nhân: catch sessionExpired chỉ `UserSession.clear()`, không xóa activeRequest/history/selectedSavedVehicle và không invalidate tác vụ đang chờ.
- Tái hiện: đang có đơn và lịch sử → refresh nhận JWT expired → controller báo chưa đăng nhập nhưng vẫn còn dữ liệu cũ để render.
- Ảnh hưởng: dữ liệu phiên cũ còn trên màn hình, các kết quả đang chờ có thể được áp dụng sau invalidation không đầy đủ.
- Fix đề xuất: cleanup thống nhất cache/phiên và invalidate request revision khi sessionExpired; kiểm tra response thuộc phiên hiện tại.
- Bằng chứng bổ sung từ regression HTTP: SDK `maybeSingle()` có thể chuyển lỗi PGRST301 thành code HTTP `401`; mapper cũ không nhận diện `401`, nên còn không đi vào cleanup. Fix bao gồm mapping HTTP 401 (và 403 là permission denied).

## C. MEDIUM

### BE-02 — Profile lỗi làm bỏ qua tải active/history

- Flow: restore session/login.
- File/line: `frontend/customer_app/lib/app/app_controller.dart:170-176`.
- DB/RPC: `customer_profiles`, `rescue_requests`.
- Nguyên nhân: refreshRequests chỉ chạy sau fetchProfile thành công trong cùng try.
- Tái hiện: auth hợp lệ, SELECT profile timeout/lỗi, SELECT request vẫn hoạt động → active/history không được tải khi restore.
- Ảnh hưởng: app không biết đơn đang xử lý cho đến khi refresh thủ công.
- Fix đề xuất: tách xử lý lỗi profile khỏi refresh request; vẫn dừng nếu phiên đã hết hạn/thay đổi.

### BE-03 — Response refresh cũ tắt loading của refresh mới

- Flow: refresh/realtime/create/cancel.
- File/line: `frontend/customer_app/lib/app/app_controller.dart:207-211`.
- DB/RPC: active/history SELECT.
- Nguyên nhân: nhánh finally kiểm sessionVersion nhưng bỏ requestRevision, trong khi nhánh áp dụng kết quả có cả hai.
- Tái hiện: refresh A đang chờ → refresh B bắt đầu → A hoàn thành trước B → loading=false khi B vẫn pending.
- Ảnh hưởng: trạng thái tải sai, thao tác bị mở sớm; nếu sửa guard đơn thuần thì mutation invalidate refresh có thể để loading mắc kẹt.
- Fix đề xuất: revision guard cho finally và kết thúc loading rõ ràng khi create/cancel/realtime thay thế snapshot.

### BE-04 — JSON ngoài contract gây lỗi async không được xử lý

- Flow: restore profile, load requests, realtime.
- File/line: `frontend/customer_app/lib/app/user_session.dart:21-24`; `app_controller.dart:91-111`; `app_controller.dart:176-179,202`.
- DB/RPC: Auth user_metadata; request rows.
- Nguyên nhân: metadata do user kiểm soát bị cast thẳng String; byName/singleWhere/DateTime.parse/type casts có thể throw trong khi controller chỉ catch AppFailure.
- Tái hiện: Auth metadata full_name là object/phone là number; hoặc mock/DB lệch migration trả unknown status/service, null field bắt buộc, sai kiểu giá.
- Ảnh hưởng: restore/request Future lỗi không được bắt, app không hiển thị lỗi backend rõ ràng.
- Phân biệt: 6 status hiện tại và integer quoted_price **đã khớp DB**; không coi null quoted_price hay status `in_progress` là mismatch. `assisting` đã được migrate, không tự map unknown thành searching/completed.
- Fix đề xuất: đọc metadata kiểm kiểu; chuyển lỗi decode request thành AppFailure rõ ràng, giữ fail-closed đối với status không hỗ trợ.

### BE-05 — History cắt mất đơn từ dòng 101

- Flow: completed/cancelled → History.
- File/line: `frontend/customer_app/lib/services/supabase_service.dart:194-205`.
- DB/RPC: `rescue_requests`, `customer_request_display_codes` (batch tối đa 100 UUID).
- Nguyên nhân: limit(100), không page tiếp và order không có tie-breaker id.
- Tái hiện: customer có 101+ đơn terminal → đơn cũ không thể truy cập từ danh sách; created_at bằng nhau không có thứ tự ổn định.
- Ảnh hưởng: thiếu lịch sử/đếm thống kê, không có đường xem đơn cũ.
- Fix đề xuất: đọc theo trang với cursor (created_at,id), enrich từng batch <=100, chống trùng; giữ giao diện hiện có. Đây là thiếu sót có sẵn, chưa chứng minh do đợt UI.

### BE-06 — Retry hủy sau mất response báo lỗi mặc dù DB đã hủy

- Flow: cancel/double tap/network retry.
- File/line: `frontend/customer_app/lib/services/supabase_service.dart:297-313`; `backend/supabase/migrations/202609300001_initial_customer_rescue.sql:163` (function cancel).
- DB/RPC: `cancel_own_rescue_request(request_id uuid)`; event trigger.
- Nguyên nhân: RPC chỉ update searching/accepted; lần gọi lại khi cancelled trả REQUEST_NOT_CANCELLABLE; client không đối soát trạng thái.
- Tái hiện: server commit cancel, response mất và realtime gián đoạn → retry → UI báo không thể hủy.
- Ảnh hưởng: kết quả thao tác gây hiểu nhầm, active state chậm được xóa.
- Fix đề xuất: giữ nguyên RPC/rule, khi nhận đúng REQUEST_NOT_CANCELLABLE thì đọc lại đúng id+owner; chỉ coi cancelled là thành công. Completed/arriving/in_progress vẫn báo lỗi. Không sinh thêm event.

### BE-07 — Timeline gán thời gian báo giá cho thời điểm chuyển trạng thái

- Flow: tracking → quote update.
- File/line: `frontend/customer_app/lib/widgets/tracking_ui.dart:691-708`; `backend/supabase/migrations/202610010001_customer_tracking.sql:55`; rescuer foundation:977.
- DB/RPC: `rescue_requests.updated_at`, `request_status_events.occurred_at`, `rescuer_create_quote`.
- Nguyên nhân: timeline dùng updated_at cho mốc status hiện tại. Trigger thay updated_at trên mọi UPDATE; quote update không sinh status event.
- Tái hiện: accepted lúc T1 → quote lúc T2 → timeline gắn T2 vào “Đối tác tiếp nhận đơn”.
- Ảnh hưởng: lịch sử thời gian hiển thị sai.
- Fix đề xuất: không suy diễn thời gian chuyển trạng thái từ updated_at; chỉ giữ timestamp tạo đơn có bằng chứng, history detail tiếp tục dùng event thật. Không cần mở thêm quyền hay đổi thiết kế timeline.

## D. LOW

### BE-08 — Duplicate fetch khi Auth initialSession và initialize cùng restore

- Flow: startup/auth listener.
- File/line: `frontend/customer_app/lib/app/app_controller.dart:135-145`; `new_auth_screen.dart:61`.
- DB/RPC: profile/active/history.
- Nguyên nhân: vừa subscribe stream (SDK có initialSession) vừa gọi restore trực tiếp; auth screen gọi refresh thêm sau login. Revisions ngăn response cũ nhưng không ngăn request trùng.
- Tái hiện: khởi động với stored session hoặc login → profile/request fetch có thể bị lặp; token refresh cũng restore profile từ metadata trước khi đọc DB.
- Ảnh hưởng: request thừa, nhấp nháy loading/profile; không phải listener leak khi dispose bình thường.
- Fix đề xuất: initialize idempotent, chỉ xử lý một initialSession; auth listener là nguồn refresh sau login. Giữ refresh khi reconnect/token refresh để phục hồi snapshot.

## E. Không phải lỗi / expected behavior / giới hạn đã xác nhận

1. **Create:** RPC mới nhất ở migration vehicles có đúng 10 named args, trả composite rescue_requests, `.single()` phù hợp. Ownership lấy auth.uid(); unique(customer_id,client_request_id) + partial unique active đảm bảo 1 đơn active. Retry cùng key trả đơn cũ kể cả terminal. Key khác khi đã có active trả đơn active hiện tại theo rule có sẵn; form chặn gắn ảnh draft sang đơn khác. Không đổi rule thành exception.
2. **Request code:** CH/KH/BG nằm trong `admin_web/backend/supabase/migrations/202610050001_display_codes.sql`, không nằm ở folder shared. Hàm `customer_request_display_codes(p_request_ids uuid[])` trả request_id,quote_code, owner-filter, giới hạn 100. Request_code được đọc từ request row. Không phải stale RPC; deployment phải gồm migration admin foundation trước display codes. Không biết DB thật đã áp hay chưa.
3. **Photos:** 0..3 ảnh (ảnh tùy chọn), JPEG/PNG/WebP, 1..5242880 bytes. Create request trước reserve/upload/complete; trước submit chỉ giữ bytes local, create fail/hủy draft chưa có storage object để cleanup. Partial failure giữ request/key/photo id và retry ảnh thiếu; object immutable, finalize kiểm size/MIME/existence. Không tự delete ảnh completed. Đóng app/mất draft sau reservation có thể để slot chưa complete, chưa có cơ chế GC/resume bền vững: hạn chế đã có, cần chính sách retention trước khi đổi schema.
4. **Signed URLs:** 600 giây; nút tải lại và đổi tab/resume tracking cấp URL mới. Không có auto timer renew trong màn hình luôn mở; ảnh lỗi có fallback, không crash. Không hứa URL private không thể chia sẻ trong TTL.
5. **Realtime:** kênh theo request đang biết, chỉ khi tab tracking/route hiện/foreground. Rejoin fetch snapshot, version guard chống snapshot đè event, owner/session guard, removeChannel khi cancel/logout/đổi user. Home/history không subscribe toàn customer; cross-device create khi active=null cần refresh thủ công. Đây là phạm vi realtime hiện có (không tự mở rộng kiến trúc).
6. **Status/cancel:** searching,accepted,arriving,in_progress,completed,cancelled. Customer chỉ hủy searching/accepted; server tin cậy có thể hủy các active state khác. Request row lock/UPDATE và triggers bảo vệ race với rescuer, sync assignment cancel, timeline sinh một event khi status đổi. Không cấp UPDATE trực tiếp cho customer.
7. **Tracking/partner:** chưa có customer RPC đọc profile/GPS rescuer; widget chỉ nhận data tùy chọn và production truyền stage, tọa độ request. Không đọc PII hoặc giả vị trí/ETA. History detail đọc event thật, empty/unknown status có fallback. Không tự mở RLS partner.
8. **Quotes:** customer chỉ đọc quoted_price integer nullable trên request và quote_code qua RPC. Bảng rescue_quotes không grant SELECT customer, không có policy customer. Current quote liên kết qua assignment.current_quote_id; unique issued/assignment, revision cũ superseded, quote transaction đồng bộ total về request và realtime request UPDATE. Không có surcharge column; items/note/status không được expose cho customer theo contract. Không tự thêm business capability này.
9. **Vehicles:** table thật customer_vehicles, CRUD owner filter+RLS; manual vehicle_id=null; saved kind được RPC đọc/lock. Delete ON DELETE SET NULL, kind snapshot còn nguyên. Model mapping display_name/license_plate/color/notes null-safe. is_default có ở schema nhưng chưa có flow default vehicle trong app; không tự thêm feature/unique index. Xe sửa/xóa làm invalidate selected vehicle.
10. **Addresses:** table customer_saved_addresses; text bắt buộc, cặp coords cùng null hoặc hợp lệ; owner CRUD RLS; default unique và trigger chuyển default. Saved address text-only hợp lệ; sửa địa chỉ đã lưu trong draft bỏ GPS cũ, manual path không ép GPS. GPS denied/deniedForever/timeout/web có fallback. Create RPC không cần address_id, lưu snapshot địa chỉ.
11. **Review:** unique request_id, completed+owner được RLS và trigger kiểm; rating 1..5/comment<=2000; RPC invoker upsert cho retry/update cùng request, không phải duplicate row. UI chống double submit, chỉ render khi completed, update card theo RPC response; History không có review summary cần refresh. Không đổi rule thành review immutable.
12. **Profile:** trigger auth insert đồng bộ tạo profile trong transaction, không có race “auth commit trước trigger”. Existing users thiếu profile có load/upsert DO NOTHING rồi select ở profile repository. Email lấy Auth, không có customer_profiles.email. Profile phone nullable; cache được apply sau save.
13. **Security:** customer_profiles/customer_vehicles/customer_saved_addresses owner CRUD; rescue_requests/status_events/photos read owner; writes request/photo qua RPC owner validation; review invoker + trigger. Storage restrictive policies chặn overwrite/delete/anon kể cả permissive policy khác. No customer SELECT rescuer PII/quotes. Admin views kiểm role; không mở policy customer chung. `SUPABASE_SERVICE_ROLE_KEY` chỉ xuất hiện trong bộ lọc log, không dùng khởi tạo client; không in hay kiểm nội dung secret config.
14. **Errors:** AppFailure/PostgREST/network timeout có UI lỗi; photo finalize có đối soát object nên không nuốt upload fail thành success. CRUD dùng generic message làm mất phân loại lỗi nhưng vẫn báo thất bại. Optional display-code fetch fail trả row chưa enrich (fallback có chủ đích), không coi request create thành công nếu RPC fail.
15. **Legacy:** `get_nearby_providers` không có migration trong repo, nhưng chỉ dùng màn provider legacy ngoài router hiện tại. Ghi nhận code cũ, không sửa UI/architecture để nối lại.

## Ma trận Flutter ↔ DB/RPC

| Flutter call | RPC/table | Args/filter | Return | Migration định nghĩa cuối | Kết luận |
|---|---|---|---|---|---|
| signUp/signIn/signOut/authStateChanges | Supabase Auth | email,password; metadata full_name,phone | User/Session/AuthState | Auth + initial trigger | Khớp; BE-01/02/04/08 |
| fetchProfile/profile load/save | customer_profiles | user_id; full_name,phone,updated_at | row nullable/load recovery | initial; display_codes thêm customer_code | Khớp; email từ Auth |
| createRescueRequest | create_customer_rescue_request | p_client_request_id uuid, p_vehicle_kind text, p_service_code text, p_location_text text, p_description text, p_contact_name text, p_contact_phone text, p_vehicle_id uuid?, p_latitude float8?, p_longitude float8? | rescue_requests composite | 202610010003_customer_vehicles | Khớp |
| fetchActiveRequest | rescue_requests | customer_id + 4 active statuses, created_at desc, limit 1 | row? | initial + tracking + vehicles | Khớp |
| fetchHistory | rescue_requests | customer_id + completed/cancelled | rows | initial + tracking | BE-05 |
| withDisplayCodes | customer_request_display_codes | p_request_ids uuid[] <=100 | [{request_id,quote_code}] | admin 202610050001_display_codes | Khớp |
| cancelRequest | cancel_own_rescue_request | request_id uuid | rescue_requests composite | initial | Khớp signature; BE-06 retry |
| watchRequest | rescue_requests realtime | UPDATE id; snapshot id+customer_id | row/event | tracking publication | Khớp; tab scoped |
| details.load | rescue_requests + request_status_events | id+customer_id; request_id, order occurred_at,id | request+events | tracking | Khớp |
| photos.upload reserve | reserve_customer_request_photo | p_request_id,p_photo_id uuid; p_content_type text; p_byte_size integer | photo composite | photos | Khớp |
| photos.uploadBinary | storage bucket rescue-request-photos | owner/request/photo; upsert=false | object path | photos/storage policies | Khớp |
| photos.upload complete | complete_customer_request_photo | p_photo_id uuid | photo composite | photos | Khớp |
| photos.list/createSignedUrl | rescue_request_photos + storage | request_id, uploaded_at not null, slot; expires=600 | rows + URL | photos | Khớp |
| vehicles list/save/delete | customer_vehicles | customer_id + id; kind,display_name,license_plate,color,notes | rows/row/deleted ids | initial + vehicles | Khớp |
| addresses list/save/delete | customer_saved_addresses | owner+id; label,address,latitude,longitude,notes,is_default | rows/row/deleted ids | saved_addresses | Khớp |
| reviews.load | customer_request_reviews | request_id+customer_id | row? | request_reviews | Khớp |
| reviews.submit | submit_customer_request_review | p_request_id uuid,p_rating integer,p_comment text? | composite JSON object | request_reviews | Khớp |
| fetchNearbyProviders (legacy) | get_nearby_providers | customer_lat,customer_lng,max_distance_km | list | Không có | Không được route hiện tại |

## Kiểm thử và xử lý sau báo cáo

Chưa sửa ở thời điểm ghi phần trên. Test sẵn có bao phủ controller/model, create/error/idempotency UI, ảnh HTTP+widget, tracking lifecycle, xe/địa chỉ/profile/review repository+widget, history/details, quote UI, GPS. Thiếu integration Auth/realtime socket/SQL thực; cần test regression tập trung các lỗi trên. Không thay test để che lỗi, không thay UI ngoài sửa thông tin BE sai.

## Kết quả sửa và kiểm thử

### Các lỗi đã sửa

| Issue | Xử lý thực tế | Bằng chứng regression |
|---|---|---|
| BE-01 | Mapper nhận HTTP 401/403; sessionExpired xóa identity/active/history/selected vehicle, invalidate pending refresh; optional code lookup không nuốt JWT expiry | JWT expired khi đọc request/profile; logout khi response pending; optional RPC fail vs JWT fail |
| BE-02 | Profile error không chặn request load; profile sessionExpired vẫn dừng để cleanup | Mock profile lỗi, active/history trả dữ liệu đúng |
| BE-03 | finally kiểm revision; create/cancel/realtime chủ động kết thúc loading khi thay snapshot | 2 refresh hoàn thành lệch thứ tự; terminal event trong lúc snapshot pending |
| BE-04 | Auth metadata kiểm kiểu; model decode chuyển lỗi thành AppFailure; reads bắt JSON shape lỗi | Object/number metadata; unknown/old status, unknown service, null vehicle, sai date/money; history response sai cấu trúc |
| BE-05 | Keyset pagination created_at DESC,id DESC, mỗi trang 100; code RPC theo từng batch, dedup theo id | 0/100/101/205 rows, timestamps bằng nhau, cursor+owner+status+JWT đúng, không thiếu/trùng |
| BE-06 | REQUEST_NOT_CANCELLABLE được đối soát owner-filter; chỉ cancelled là thành công | cancelled/completed/arriving/in_progress; permission denied; invisible request |
| BE-07 | Không dùng updated_at cho mốc status; timestamp tạo đơn vẫn giữ, update timestamp ở header vẫn giữ; detail tiếp tục dùng status_events | Quote update ở accepted/in_progress/completed/cancelled không tạo thời điểm giả |
| BE-08 | initialize idempotent, bỏ initialSession trùng, bỏ refresh trùng từ auth screen, chống submit auth lặp; cùng identity giữ profile khi chờ reload | Init lặp chỉ 1 lần đọc profile/active/history; lifecycle tests sẵn có |

Không còn lỗi nào trong BE-01..BE-08 cố tình để lại. Chưa kết luận tất cả đều do UI mới: BE-07 liên quan timeline UI; các lỗi controller/service còn lại phần lớn đã tồn tại trước lượt chỉnh UI đang chưa commit.

`AppController` và các service đọc/hủy có thêm optional `SupabaseClient` để test HTTP thật qua SDK với transport mock, cùng pattern client injection đã có ở các repository. Production vẫn dùng Supabase singleton và kiến trúc hiện có. Không thay routing/layout; auth screen chỉ bỏ fetch thừa/thêm submit guard, timeline chỉ bỏ timestamp không có bằng chứng.

### Test coverage hiện có được rà soát

| Flow | Test files chính |
|---|---|
| Auth/controller/profile | app_controller_test.dart, app_shell_test.dart, customer_profile_repository_test.dart, customer_profile_card_test.dart, backend_flow_regression_test.dart |
| Create/error/location | request_failure_test.dart, request_address_validation_test.dart, request_location_test.dart, request_debug_log_test.dart, location_service_test.dart |
| Photos | request_photo_repository_test.dart, request_photos_test.dart |
| Cancel/realtime/tracking | tracking_test.dart, tracking_ui_test.dart, tracking_states_test.dart, backend_flow_regression_test.dart |
| Vehicles | customer_vehicle_repository_test.dart, customer_vehicles_test.dart |
| Addresses | customer_saved_address_repository_test.dart, customer_saved_addresses_test.dart |
| Reviews | customer_request_review_repository_test.dart, customer_request_reviews_test.dart |
| History/details/quote | request_details_repository_test.dart, history_details_test.dart, history_ui_test.dart, display_code_test.dart, tracking_ui_test.dart |

Thêm **27 regression tests** trong `test/backend_flow_regression_test.dart`. Hai điều chỉnh test sẵn có không giảm coverage:

- `compact_customer_ui_test.dart`: thay expectation sai “updated_at là timestamp status” bằng assertion không có mốc giả, giữ kiểm tra thời gian tạo đơn và các phần giao diện.
- `request_photo_repository_test.dart`: baseline pass nhưng log có TestFailure bị nhánh upload-recovery nuốt. Di chuyển assertion ra ngoài MockClient callback, kiểm JWT/RPC args/multipart boundary/file MIME/exact bytes/upsert/complete args. Đây là sửa lỗ hổng kiểm thử, không tính thêm thành lỗi backend thứ 9.

### Analyzer và giới hạn runtime

Baseline: `flutter analyze` exit 1, 4 warning; `flutter test --no-pub --reporter expanded` **411 pass**. Lượt targeted cuối: **36 pass** (27 regression + compact UI + photo repository).

Toàn bộ suite cuối: `flutter test --no-pub --reporter expanded` **438/438 pass**, exit 0 (75 giây). Log cuối không có `TestFailure` bị nuốt. Còn warning flutter_map/tap của các UI test có sẵn; không tắt hay làm yếu các kiểm tra này.

Log lưu tại customer_app:

- [Baseline tests](../../frontend/customer_app/customer_backend_baseline_test.log)
- [Final tests](../../frontend/customer_app/customer_backend_final_test.log)
- [Final analyzer](../../frontend/customer_app/customer_backend_final_analyze.log)

Analyzer cuối (`flutter analyze --no-pub`): exit 1, **0 error, 4 warning có sẵn**, không thêm warning:

- `lib/screens/login_screen.dart:73`: unused local `password`.
- `lib/screens/login_screen.dart:86`: unused local `response`.
- `lib/screens/login_screen.dart:507`: unused `_NetworkChip`.
- `lib/screens/login_screen.dart:524`: unused `_SocialBtn`.

Không dọn code UI legacy ngoài scope chỉ để analyzer xanh. `git diff --check` không có lỗi whitespace; Git có thông báo chuyển LF/CRLF theo cấu hình Windows.

RLS/Storage/RPC được kiểm tĩnh theo migration; **chưa chạy SQL integration hoặc E2E trên DB thật** vì Docker daemon local không hoạt động và chưa có môi trường DB test được xác nhận. Test HTTP/mock không chứng minh policy deployed, WebSocket reconnect thật, permission thiết bị thật, hoặc hai transaction DB đồng thời. Không chạy tool/verify_backend.dart vì công cụ đó có mutation dữ liệu DB. Cần xác nhận migration đang áp trước kiểm thử triển khai, đặc biệt display codes thuộc folder admin.

Không tạo/sửa/chạy migration; không đổi signature/business rule RPC. Không sửa code rescuer/admin trong lượt review này. Giữ nguyên các thay đổi chưa commit của người dùng. **KHÔNG COMMIT.**

Nguồn kiểm chứng return shape bổ sung: [PostgREST changelog chính thức](https://github.com/PostgREST/postgrest/blob/main/CHANGELOG.md) phân biệt `returns composite_type` với `returns setof composite_type`; RPC review composite trả object theo contract hiện tại, không tự sửa thành list vì các bảng SELECT thường trả list.

## Bàn giao theo 10 mục yêu cầu

1. **8 lỗi xác nhận:** 0 blocker, 1 high, 6 medium, 1 low. Phân loại ở A–D; các thiếu tính năng/giới hạn contract ở E không được tự biến thành lỗi business rule.
2. **Đã sửa cả 8:** BE-01..BE-08, có regression và bảng bằng chứng phía trên.
3. **Chưa sửa:** không còn issue xác nhận trong nhóm 8 để lại. 4 analyzer warning UI legacy giữ nguyên ngoài scope. RLS/realtime/storage integration trên DB thật chưa kiểm chứng; Docker local không hoạt động. Giới hạn partner API/quote detail/GC ảnh/cross-device realtime ở E được giữ theo contract.
4. **Migration:** không có migration mới cần chạy cho bản sửa này; chưa xác nhận trạng thái deploy migration cũ, đặc biệt admin display_codes. Không chạy migration trong lượt này.
5. **RPC:** không đổi tên, tham số, return shape, quyền hoặc implementation SQL.
6. **Rescuer app:** không sửa code hoặc contract dùng chung; không dự kiến tác động từ các sửa frontend customer này. Chưa chạy E2E rescuer trên DB thật.
7. **Admin web:** không sửa code hoặc contract dùng chung; không dự kiến tác động. Đã đọc migration admin liên quan mã hiển thị/quyền.
8. **flutter analyze:** 0 error, 4 warning baseline; exit 1, không báo là clean/pass.
9. **flutter test:** 438/438 pass; tăng từ baseline 411. Không skip/remove test; sửa assertion sai contract và tăng độ chặt test upload.
10. **KHÔNG COMMIT.** Giữ nguyên các thay đổi UI/rescuer đang có của người dùng.
