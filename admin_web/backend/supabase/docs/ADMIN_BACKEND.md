# Admin Backend - Cứu Hộ 24/7

## 1. Vị trí và phạm vi

BE Admin nằm tại `admin_web/backend/supabase`. Đây là migration/RLS/view/RPC
trong Supabase PostgreSQL, không phải Node.js server. Bốn tệp giao:

- `migrations/202610040001_admin_backend_foundation.sql`: foundation.
- `seed/admin_seed.sql`: bootstrap mẫu và danh mục dịch vụ.
- `docs/ADMIN_BACKEND.md`: tài liệu này.
- `tests/admin_backend_tests.sql`: kiểm kê và regression có rollback.

Việc đặt migration trong admin_web giúp quản lý mã Admin cùng một thư mục.
Database vẫn dùng chung với customer_app/rescuer_app. Việc chạy migration sẽ thêm
các đối tượng mới vào database chung; vị trí tệp không tạo database riêng.

Không sửa frontend của ba ứng dụng hoặc các migration tại backend/supabase.
Chưa triển khai lên Supabase thật. Không commit.

## 2. Tiền đề và thứ tự áp dụng

Đã đọc và map theo bảy migration hiện có, theo thứ tự:

1. 202609300001_initial_customer_rescue.sql
2. 202610010001_customer_tracking.sql
3. 202610010002_customer_request_photos.sql
4. 202610010003_customer_vehicles.sql
5. 202610010004_customer_saved_addresses.sql
6. 202610010005_customer_request_reviews.sql
7. 202610020001_rescuer_backend_foundation.sql
8. Migration Admin trong thư mục này.

Áp dụng bằng tài khoản migration đáng tin cậy trên Supabase PostgreSQL 15+.
Chủ sở hữu view/function cần quyền đọc các bảng public, auth.users và thực thi
helper private của foundation đối tác. Không đổi owner sang authenticated/anon.
Schema private không được expose qua Data API.

Migration chạy trong một transaction; lock_timeout=5s, statement_timeout=60s.
Nếu schema thiếu hoặc gặp xung đột, toàn bộ transaction thất bại. Preflight kiểm tra
các bảng nền tảng, cột trọng yếu và trigger tracking/cancellation. PostgreSQL kiểm tra
thêm các cột tham chiếu khi tạo view. Preflight không thay thế so sánh schema live.

Các đối tượng Admin hiện hữu khiến migration dừng để review; không dùng
CREATE OR REPLACE hoặc IF NOT EXISTS để âm thầm ghi đè cấu hình Admin cũ.
Migration chạy một lần, seed chạy lại được. Không tự chạy db push.

pgcrypto đã nằm trong migration đầu; gen_random_uuid() có sẵn ở PostgreSQL được
hỗ trợ nên foundation Admin không cần thêm extension.

## 3. Kiến trúc và bảo mật

Admin Web → Supabase Auth → JWT của người dùng → RLS / role gate → View/RPC → PostgreSQL.

Frontend sau này chỉ cấu hình VITE_SUPABASE_URL và VITE_SUPABASE_ANON_KEY.
Anon key không cấp quyền Admin: JWT đăng nhập phải có auth.uid() khớp một
admin_profiles có status=active. Không lấy role từ user_metadata do người dùng tự sửa.

Không đưa service_role vào frontend, mã nguồn browser hoặc APK. Quyền đặc biệt chỉ
thuộc môi trường server đáng tin cậy; bootstrap bằng SQL Editor dùng kết nối quản trị,
không cần copy service_role vào giao diện.

Các function SECURITY DEFINER đặt search_path=public theo hợp đồng yêu cầu; mọi
bảng, view, helper ứng dụng đều có tên schema đầy đủ. EXECUTE mặc định của PUBLIC
bị thu hồi riêng cho các function mới. authenticated chỉ được gọi helper kiểm tra
quyền và sáu RPC công khai. admin_log_action và helper private không có EXECUTE
cho PUBLIC, anon hoặc authenticated.

Mutation RPC khóa bản ghi membership Admin FOR SHARE, để cập nhật role/status
đồng thời không dùng quyền cũ giữa chừng. User đang blocked bị từ chối dù JWT còn hạn.
Cấu hình hạ tầng phải giữ public/private không cho người dùng API tạo function/bảng.

## 4. Bảng và tương thích schema cũ

| Bảng | Vai trò |
|---|---|
| admin_profiles | Auth UUID, họ tên, role, status, điện thoại, avatar, timestamps |
| admin_audit_logs | Actor, action, đối tượng, metadata, timestamps; client chỉ đọc |
| admin_notifications | Ý định gửi thông báo, đối tượng nhận, priority, creator |
| admin_service_catalog | UUID và metadata dịch vụ bổ sung cho danh mục đã có |
| rescue_services (đã có) | Danh mục chung, khóa chính code TEXT; không tạo trùng |

Khác biệt đã xử lý:

| Ý trong yêu cầu | Schema thật / cách map |
|---|---|
| customer_profiles.id | customer_profiles.user_id |
| vehicles / saved_addresses | customer_vehicles / customer_saved_addresses |
| reviews | customer_request_reviews |
| rescuer_profiles.status / approval_status | verification_status: draft, submitted, approved, rejected, suspended |
| pending đối tác | submitted; không đếm draft chưa nộp hồ sơ |
| blocked đối tác | suspended; không thêm giá trị CHECK mới |
| phone đối tác | contact_phone |
| rescue_quotes.amount / created_at | total_vnd / issued_at |
| trạng thái báo giá | issued / superseded; không có paid/accepted |
| request_code | UUID request thật dạng text; không bịa mã CH |
| pickup_address / lat / lng | location_text / latitude / longitude |
| accepted_at / completed_at | assignment, hoặc status event thực không phải initial snapshot |
| destination_address | NULL::text vì schema chưa lưu |
| customer avatar/status | NULL::text vì schema chưa lưu |
| total_spent | 0::numeric, chưa có ledger thanh toán |
| UUID service_id | admin_service_catalog.id, map sang rescue_services.code |

Không thêm id, giá, mô tả hoặc trạng thái mới vào bảng dịch vụ dùng chung.
admin_service_catalog lưu service_code FK, admin_code (SRV-*), description, icon,
base_price, price_unit, is_featured, timestamps. Tên, sort_order và is_active vẫn lấy
từ bảng gốc; không có hai nguồn trạng thái khác nhau.

admin_notifications thêm target_user_id để single_customer/single_rescuer có người
nhận thật. CHECK buộc target_user_id chỉ có ở hai loại single; trigger xác minh đối
tượng tồn tại. Creator và thời gian luôn do backend gán. Ghi notification chỉ lưu
ý định gửi và audit; chưa có FCM worker, delivery receipt hay broadcast thực.

Audit hỗ trợ các action được yêu cầu. Thay đổi metadata dịch vụ ghi
update_system_setting với scope=service_metadata; chưa tạo bảng cài đặt hệ thống chung.
ip_address/user_agent để NULL vì chưa có gateway xác minh; không coi header tùy ý là
dữ liệu đáng tin. Không lưu mật khẩu/token vào audit.

## 5. Role và quyền

| Quyền | super_admin | operator | support | partner_reviewer | finance |
|---|---|---|---|---|---|
| Danh sách Admin, audit, notification, catalog | Có | Có | Có | Có | Có |
| Dashboard tổng hợp | Có | Có | Có | Có | Có |
| Doanh thu trong dashboard | Có | Ẩn | Ẩn | Ẩn | Có |
| View khách hàng, đơn, đánh giá | Có | Có | Có | Không | Không |
| View đối tác | Có | Có | Không | Có | Không |
| View metadata giấy tờ | Có | Không | Không | Có | Không |
| View báo giá | Có | Không | Không | Không | Có |
| Duyệt / từ chối đối tác | Có | Không | Không | Có | Không |
| Khóa đối tác | Có | Có | Không | Không | Không |
| Hủy đơn, bật/tắt dịch vụ | Có | Có | Không | Không | Không |
| Sửa metadata / giá dịch vụ | Có | Có | Không | Không | Không |
| Tạo notification | Có | Có | Có | Không | Không |
| Tạo / sửa Admin | Có | Không | Không | Không | Không |

Mục mô tả role đầu yêu cầu có ghi partner_reviewer được khóa; phần RPC
admin_block_rescuer cụ thể chỉ cho super_admin/operator. Bản này tuân theo quy tắc
RPC cụ thể đó, và có test từ chối partner_reviewer gọi block.

Admin không được tự đổi role/status của chính mình; không cấp DELETE admin_profiles.
Có thể dùng super_admin khác hoặc kết nối SQL quản trị để thay quyền tài khoản đó.
Bootstrap SQL có auth.uid() NULL được ghi audit source=trusted_sql, actor=NULL.
admin_audit_logs dùng ON DELETE SET NULL cho actor để bảo toàn lịch sử nếu Auth user
bị xóa. Việc giữ/xóa Auth user với các FK khác cần chính sách vòng đời riêng.

## 6. RLS và audit

- admin_profiles: active admin SELECT; super_admin INSERT/UPDATE; không DELETE.
  Chỉ grant các cột được phép, id/created_at không được cập nhật.
- admin_audit_logs: active admin SELECT; không grant ghi/xóa và không policy ghi.
- admin_notifications: active admin SELECT; super_admin/operator/support INSERT.
  Client không được chỉ định created_by hoặc created_at.
- admin_service_catalog: active admin SELECT; super_admin/operator UPDATE các cột
  metadata được liệt kê. Mã, UUID và FK bất biến với client.
- rescue_services: giữ nguyên policy active-service cho khách; thêm admin SELECT
  tất cả và UPDATE policy có role gate. Không cấp direct UPDATE cho authenticated:
  bật/tắt phải qua RPC có audit. Không cấp INSERT/DELETE catalog gốc từ client.

Trigger chỉ gắn vào các bảng Admin mới: profile validation/audit, notification
validation/audit, metadata validation/audit. Không thay trigger nghiệp vụ cũ.
Nếu ghi audit thất bại thì mutation cũng rollback.

Đọc view dùng security_barrier=true và security_invoker=false có chủ đích:
view owner đọc xuyên các hàng owner-only, nhưng WHERE của TỪNG view luôn gọi role
gate theo auth.uid() của request. Chỉ grant SELECT cho authenticated, không cho anon.
Do đó user thường/blocked nhận 0 hàng, RPC nhận lỗi 42501. Không bỏ WHERE, không
chuyển view thành security_invoker=true mà chưa thiết kế lại quyền nền. Cách dùng
owner view có thể được Supabase advisor cảnh báo cần review; role gate được test
bằng SET ROLE authenticated và nhiều JWT subject giả lập.

## 7. View đọc dữ liệu

Năm view bắt buộc:

- admin_rescue_requests_view: đơn, khách, phương tiện, phân công và báo giá hiện hành.
  quote_amount=NULL với operator/support; super_admin thấy giá. finance dùng quotes view.
- admin_customers_view: thống kê xe, địa chỉ, đơn; không nhân bản count do join.
- admin_rescuers_view: approval_status, online_status raw, is_available có freshness,
  số xe/dịch vụ, ca hoàn tất và điểm đánh giá.
- admin_quotes_view: tất cả revision; is_current / is_completion_quote giúp phân biệt.
- admin_reviews_view: review thật, khách và đối tác của đơn.

Hai view bổ sung:

- admin_services_view: UUID dùng cho toggle RPC, mã SRV và code thật của app.
- admin_rescuer_documents_view: metadata giấy tờ cho người duyệt.

View không tự phân trang; frontend phải select cột cần thiết, order ổn định rồi range.
Không expose email/token Auth ngoài các cột email đã chọn.

## 8. Function và RPC

Helper công khai: is_admin(), has_admin_role(required_roles text[]).
Helper nội bộ: admin_log_action(p_action,p_target_table,p_target_id,p_metadata);
private.admin_require_role và private.admin_change_rescuer; các trigger helper.

| RPC | Input | Quy tắc |
|---|---|---|
| admin_get_dashboard_stats | Không | Active Admin; JSON thống kê |
| admin_approve_rescuer | rescuer_id UUID | super_admin/reviewer; submitted → approved |
| admin_reject_rescuer | rescuer_id UUID, reason TEXT | super_admin/reviewer; submitted → rejected |
| admin_block_rescuer | rescuer_id UUID, reason TEXT | super_admin/operator; → suspended |
| admin_cancel_request | request_id UUID, reason TEXT | super_admin/operator; chỉ searching/accepted/arriving |
| admin_toggle_service | service_id UUID, is_active BOOLEAN | super_admin/operator; UUID từ admin_services_view |

Lý do bắt buộc không trắng, tối đa 2000 ký tự. ID không tồn tại trả P0002.
Thiếu quyền trả 42501; input/chuyển trạng thái không hợp lệ trả 22023.
Đối tác còn ca active trả P0001 / ADMIN_RESCUER_BUSY.

Duyệt/từ chối chỉ nhận hồ sơ submitted. Gọi lại đúng trạng thái đích trả success=true,
changed=false và không thêm audit/version. Sửa thật tăng version và ghi verified_by,
verified_at. Khóa/từ chối đưa online=false. Dùng cùng advisory lock rescuer:<UUID>
và profile lock với các RPC đối tác, tránh race với sửa hồ sơ/nhận ca.

Không khóa đối tác đang có ca accepted/en_route/arrived/in_progress: foundation cũ
yêu cầu approved để truy cập ca, khóa ngay sẽ khiến ca đang cứu hộ bị mất thao tác.
Hủy ca đủ điều kiện trước; ca in_progress cần hoàn tất hoặc quy trình riêng.
Không dùng approve để tự mở khóa suspended.

Hủy đơn khóa request trước, kiểm tra trạng thái và cập nhật status. Trigger hiện có
tự ghi một request_status_event và đồng bộ assignment/version/event. Không chèn
event trùng. Schema event chưa có reason/created_by, nên lý do và Admin actor lưu ở
admin_audit_logs. Trigger phân loại actor=customer nếu auth.uid() đúng customer_id,
ngược lại system/system_cancelled; audit luôn lưu Admin actor đã gọi RPC.
Gọi lại đơn cancelled bị từ chối theo yêu cầu.

Duyệt profile chưa tự duyệt xe, capability hoặc giấy tờ. Đây là các đối tượng kiểm
chứng độc lập của backend đối tác. Một profile approved vẫn chưa chắc được online.

Dashboard trả đủ 10 chỉ số và thêm revenue_visible, revenue_basis, timezone:

- Ngày tính theo Asia/Ho_Chi_Minh, khoảng [đầu ngày, đầu ngày tiếp theo).
- today_revenue cộng issued trong ngày, bỏ superseded và đơn cancelled; là giá trị
  báo giá tạm tính, không phải doanh thu đã thu.
- Ngoài super_admin/finance: today_revenue=0 và revenue_visible=false.
- pending_rescuers đếm submitted.
- online_rescuers chỉ đếm approved, is_online và last_seen_at trong 120 giây.
- Tổng completed/cancelled/active là toàn kỳ, today_requests là trong ngày.
- customer_profiles được Auth trigger tạo cho mọi user; total_customers hiện đếm
  đúng bảng này, có thể gồm tài khoản đối tác/Admin. Cần danh tính nghiệp vụ riêng
  nếu muốn loại nhóm này khỏi chỉ số khách hàng.

## 9. Tạo Admin đầu tiên

1. Trên Supabase Auth của môi trường dự kiến, tạo tài khoản/email hợp lệ.
2. Lấy UUID từ auth.users. Không dùng ID frontend tự đặt.
3. Áp bảy migration nền tảng rồi migration Admin bằng quy trình migration được review.
4. Mở seed/admin_seed.sql, copy phần INSERT admin_profiles đang comment vào SQL Editor.
5. Thay AUTH_USER_ID_HERE bằng UUID vừa lấy, chỉnh họ tên/điện thoại, chạy bằng kết
   nối quản trị không mang user JWT. Không commit UUID thật vào seed.
6. Đăng nhập bằng tài khoản đó qua Supabase Auth, dùng anon key + session access token.
7. Kiểm tra is_admin()=true và dashboard trả JSON. Tài khoản Auth khác không tự có quyền.

Mẫu seed không tạo auth.users, không tạo mật khẩu và không sử dụng service_role key.

## 10. Seed và catalog

Sáu mã SRV được map:

| Mã Admin | Code app | Giá gợi ý VND |
|---|---|---|
| SRV-TOW-01 | towing | 500000 |
| SRV-BAT-02 | battery | 200000 |
| SRV-TYR-03 | tire | 250000 |
| SRV-FUL-04 | fuel | 180000 |
| SRV-LCK-05 | locksmith | 300000 |
| SRV-MEC-06 | mechanic | 350000 |

Giữ nguyên code/name/status đã có; các code cũ khác (ví dụ other) được map LEGACY:code.
Hai code mới locksmith/mechanic mặc định inactive để app hiện tại không nhận dịch vụ
chưa hỗ trợ. Chỉ bật sau khi app/capability đã hỗ trợ.

Migration điền dữ liệu còn thiếu. Seed chạy lại giữ UUID, giá đã chỉnh, feature flag và
trạng thái. ON CONFLICT chỉ bổ sung các trường metadata NULL. Giá gợi ý không tự áp
vào báo giá/đơn cứu hộ cũ.

## 11. Cách kiểm thử quyền

Dùng database local dành riêng, đã áp đầy đủ migration. Test tạo dữ liệu tổng hợp
và ROLLBACK; vẫn không chạy trên production. Các UUID test cố định phải chưa tồn tại.

Ví dụ trong psql (kết nối LOCAL_ADMIN_DB_URL phải là local đã kiểm tra):
```powershell
psql "$env:LOCAL_ADMIN_DB_URL" -X -v ON_ERROR_STOP=1 -c "select set_config('admin.test_mode','local_disposable',false)" -f admin_web/backend/supabase/tests/admin_backend_tests.sql
```

Trong SQL Editor local: chạy SET admin.test_mode='local_disposable' trước script
trên cùng connection. Nếu tool dùng transaction/connection khác giữa hai lần gọi,
đưa SET vào cùng lần thực thi. Nếu test lỗi, ROLLBACK trước thao tác khác.

Bộ test bao gồm:

- Kiểm kê bảng/function/view, RLS, ACL helper/audit, catalog mặc định.
- Anonymous, thiếu JWT, user thường, rescuer thường, blocked Admin không đọc Admin.
- Cả năm role, quyền xem báo giá/doanh thu, quyền gọi từng mutation.
- Chặn tự tạo Admin, tự nâng role, giả audit, giả created_by.
- Duyệt/từ chối/khóa; lý do rỗng; ID sai; retry; bảo vệ đối tác còn ca active.
- Toggle dịch vụ; user không thấy dịch vụ inactive; metadata thay đổi được audit.
- Hủy searching/accepted/arriving; từ chối in_progress/completed/cancelled.
- Đồng bộ assignment/version/event; đúng một tracking event; reason/actor trong audit.
- Notification đích đơn lẻ; thêm Admin rồi block thì mất quyền ngay.
- Kiểm tra deferred constraints và owner RLS bảng khách sau khi có Admin.

Kiểm thử tích hợp tiếp theo: Auth JWT/PostgREST/Storage thật local và nhiều connection
cạnh tranh (claim/cancel/update/role revoke), tải lớn/index/EXPLAIN. Một phiên SQL
không chứng minh đầy đủ khả năng xử lý đồng thời.

## 12. Kết quả kiểm tra trong lần triển khai này

Đã chạy PostgreSQL 18.3 qua PGlite 0.5.8 trong RAM với pgcrypto, role
anon/authenticated, Auth/Storage schema giả lập tối thiểu. Đã áp nguyên văn cả bảy
migration dùng chung, sau đó migration Admin. Kết quả:

- PASS áp migration Admin.
- PASS chạy seed hai lần và giữ nguyên giá/trạng thái dịch vụ đã tùy chỉnh.
- PASS admin_backend_tests.sql (SQL, RLS, ACL, role, RPC, audit, rollback).
- PASS bộ rescuer_local_regression.sql có sẵn sau khi thêm Admin.
- PASS chạy lại migration bị từ chối có chủ đích, không ghi đè.

Đây là kiểm thử thực thi PostgreSQL, không chỉ kiểm tra cú pháp. Auth JWT validation,
PostgREST và Storage API không được chạy bởi PGlite; auth.uid() được mô phỏng bằng
request.jwt.claim.sub, không phải xác thực token. Không có network tới Supabase thật.
Docker daemon hiện không chạy; kiểm thử end-to-end Supabase local vẫn là bước trước
triển khai. Công cụ test tạm không thêm dependency vào package.json của giao diện.

## 13. Tích hợp frontend và giới hạn còn lại

Giao diện chưa được sửa/kết nối. Sau này src/lib/supabase.ts dùng session Auth để:

```typescript
await supabase.rpc('admin_get_dashboard_stats')
await supabase.from('admin_rescue_requests_view')
  .select('request_id,customer_name,status,created_at')
  .order('created_at', { ascending: false }).order('request_id')
  .range(0, 49)
await supabase.rpc('admin_cancel_request', {
  request_id: requestId, reason: 'Khách yêu cầu hủy trước khi cứu hộ'
})
await supabase.rpc('admin_toggle_service', { service_id: serviceId, is_active: false })
await supabase.from('admin_notifications').insert({
  title: 'Cảnh báo thời tiết', body: 'Nội dung', target_type: 'rescuers', priority: 'high'
})
```

Ẩn nút theo role chỉ giúp UX; backend vẫn kiểm tra mọi lệnh. Phải xử lý lỗi 42501,
P0002, 22023 và P0001. Các giao dịch lỗi/deadlock/lock timeout phải rollback trước
retry. Chưa có operation_id cho Admin mutation; retry trạng thái giống nhau ở
approve/reject/block/toggle là no-op, còn cancel đã hủy sẽ báo lỗi.

Các giới hạn có chủ đích:

- Chưa có payment/settlement ledger → không suy diễn paid revenue hoặc total_spent.
- Chưa có customer status/avatar/destination → trả NULL có comment.
- Metadata giấy tờ đọc được theo role, object Storage vẫn owner-only. Chưa triển khai
  gateway URL ký, chưa thay restrictive policy cũ.
- Chưa có workflow Admin riêng duyệt từng xe/capability/giấy tờ và hết hạn giấy tờ.
- Notification chưa gửi FCM; chưa có delivery queue/idempotency hay bảng system setting.
- Chưa tạo RPC phản hồi review hoặc điều phối lại đơn: ngoài foundation được liệt kê.
- Chưa có CRUD xóa/tạo danh mục mới từ client; thay đổi cấu trúc danh mục cần migration.
- Chưa chạy concurrency nhiều session hoặc tích hợp Auth/PostgREST thật.

## 14. Tài liệu thiết kế tham khảo

- PostgreSQL CREATE VIEW: https://www.postgresql.org/docs/current/sql-createview.html
- Supabase Database Functions: https://supabase.com/docs/guides/database/functions
- Supabase RLS: https://supabase.com/docs/guides/database/postgres/row-level-security
- PGlite API và extensions: https://pglite.dev/docs/api và https://pglite.dev/extensions/
