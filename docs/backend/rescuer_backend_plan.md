# Thiết kế backend/API/RLS — Cứu Hộ 24/7 Đối tác

**Trạng thái: đã có migration local để review; chưa áp migration, chưa kiểm thử DB/API/Storage.**
Ngày tiếp tục: 2026-10-03. Xem [báo cáo triển khai local](rescuer_backend_implementation.md)
để phân biệt phần SQL đã viết, lựa chọn bản nháp và blocker trước rollout.
Ngày lập: 2026-10-02. Phạm vi: backend dùng chung trong `backend/supabase`.
Không gọi Supabase, SQL Editor, CLI database, Auth hay Storage của môi trường thật.
Không sửa mã khách hàng/người cứu hộ, không triển khai UI, admin hoặc thanh toán.
Các tên RPC, bảng, giới hạn và luồng dưới đây là hợp đồng thiết kế. Migration local
`202610020001_rescuer_backend_foundation.sql` đã hiện thực các endpoint ở mục 5;
điều đó không xác nhận chúng tồn tại trên bất kỳ database nào. Fixture trong file
kiểm thử local là dữ liệu tổng hợp, chưa chạy; không có kết quả kiểm thử DB thực.

## 1. Cơ sở rà soát và quyết định về migration

### File đã đọc

Đường dẫn tính từ Git root `flutter_app`:

- `backend/supabase/migrations/202609300001_initial_customer_rescue.sql`
- `backend/supabase/migrations/202610010001_customer_tracking.sql`
- `backend/supabase/migrations/202610010002_customer_request_photos.sql`
- `backend/supabase/migrations/202610010003_customer_vehicles.sql`
- `backend/supabase/migrations/202610010004_customer_saved_addresses.sql`
- `backend/supabase/migrations/202610010005_customer_request_reviews.sql`
- `backend/supabase/tests/inspect_dev.sql` — chỉ đọc nội dung, không chạy.
- `backend/supabase/tests/dev_advance_request.sql` — chỉ đọc nội dung, không chạy.
- `docs/backend/README.md`
- `docs/backend/SUPABASE_SETUP.md`
- `docs/backend/KIEM_THU_GIAI_DOAN_1.md`
- `frontend/customer_app/lib/app/app_controller.dart` — enum, DTO và các điểm dùng trạng thái.
- `frontend/customer_app/lib/services/supabase_service.dart` — các query/RPC và subscription liên quan.
- `frontend/customer_app/lib/services/request_details_service.dart`
- `frontend/customer_app/lib/services/request_photo_service.dart` — upload và đọc ảnh.
- `frontend/customer_app/lib/screens/new_tracking_screen.dart` — nhãn trạng thái và điều kiện hủy.
- `frontend/rescuer_app/RESCUER_APP_STRUCTURE.md`

Rà soát repository không xác nhận những migration này đã được áp trên project nào.
Tài liệu kiểm thử cũ ghi chưa áp tại thời điểm viết; không suy ra môi trường thật
vẫn giống thời điểm đó. `backend/supabase` chưa có `config.toml` hoặc Edge Function
thực thi; `functions/` và `seed/` đang giữ thư mục bằng `.gitkeep`.

### Hợp đồng hiện có cần giữ

| Thành phần | Phát hiện trong SQL/client | Tác động đến thiết kế |
|---|---|---|
| `rescue_requests` | Có ownership, contact, địa chỉ, tọa độ tùy chọn, `provider_id uuid`, `quoted_price integer` | Dùng lại bảng này, không tạo bảng đơn thay thế |
| Trạng thái mới nhất trong repository | `searching`, `accepted`, `arriving`, `in_progress`, `completed`, `cancelled` | Không ghi `pending`, `en_route`, `arrived`, `expired` vào cột cũ |
| `provider_id` | Chưa có FK hay quy tắc claim | Định nghĩa rõ mapping mới, kiểm kê dữ liệu cũ trước khi bổ sung FK |
| Một đơn active/khách | Unique partial index trên `searching/accepted/arriving/in_progress` | Giữ index và semantics |
| Tạo/hủy đơn | `create_customer_rescue_request(...)`, `cancel_own_rescue_request(request_id)` là đường ghi có kiểm soát | Giữ chữ ký, quyền và kết quả hiện tại |
| Hủy phía khách | Chỉ `searching` hoặc `accepted` | Đồng bộ assignment nếu khách hủy sau claim |
| Tracking | Trigger kiểm tra transition, tự ghi `request_status_events`; Realtime trên đơn, RLS owner | Giữ các trạng thái coarse và event khách đang đọc |
| Ảnh | Bucket private `rescue-request-photos`, tối đa 3 ảnh, ảnh hoàn tất bất biến | Không mở bucket hoặc cho người cứu hộ upload/ghi đè ảnh khách |
| Storage | Có cả policy permissive và restrictive chỉ cho owner đọc | Thêm permissive cho rescuer thôi chưa đủ; phải rà cả restrictive khi triển khai |
| Xe/địa chỉ/review khách | Owner-only, xe đã mở rộng `motorbike/car/truck/other` | Không grant đọc thêm cho rescuer |
| Auth trigger | Mọi user mới được tạo `customer_profiles`, không phân loại app | Cho phép một UID có hai hồ sơ; không đổi trigger Auth trong thiết kế này |
| RPC nearby | Client có chỗ gọi `get_nearby_providers`, không có định nghĩa trong 6 migration | Cần xác minh endpoint/schema ngoài repository; không dùng nó cho luồng mới |

**Migration local để review:** `backend/supabase/migrations/202610020001_rescuer_backend_foundation.sql`.
File đã hoàn thiện transaction nhưng chưa chạy trên DB. Không chạy tự động hoặc
`db push`; phải kiểm kê schema thực, kiểm thử local và chốt mục 12 trước rollout.
Không sửa migration lịch sử hoặc chạy lại migration khởi tạo để ép khớp database.

## 2. Mô hình quyền và kiến trúc API

Hai app dùng cùng Supabase Auth; mọi quyền lấy từ JWT đã xác minh và `auth.uid()`.
Không tin `user_id`, `rescuer_id`, role trong body hoặc `raw_user_meta_data`.
Package name, màn hình đăng nhập hoặc app đang chạy không chứng minh quyền.
Một người cứu hộ vẫn có thể đọc dữ liệu khách hàng của chính UID đó theo RLS cũ;
không được đọc dữ liệu của UID khác vì có hồ sơ rescuer.

Flutter chỉ dùng publishable/anon key và access token của user. Không có
`service_role`, database password hoặc credential quản trị trong Flutter.
Không thiết kế endpoint admin hay cơ chế tự duyệt hồ sơ.

Hai mức quyền chính:

1. **Tự quản lý hồ sơ**: authenticated, UID đúng owner; có thể tạo hồ sơ và gửi
   hồ sơ/xe/tài liệu để xem xét, đọc dữ liệu riêng của mình.
2. **Thực hiện cứu hộ**: hồ sơ đã được duyệt, chưa suspended; xe/capability hợp lệ.
   Online và vị trí còn mới mới được xem discovery và claim. Offline không tự
   giải phóng công việc đã nhận. Chi tiết PII chỉ mở cho assignment đang active
   của chính rescuer còn đủ quyền; kết thúc/hủy/suspended thì đóng quyền đọc mới.

Hồ sơ mặc định chưa được duyệt. Nguồn xác minh/phê duyệt là blocker triển khai:
không có nguồn tin cậy thì không user nào được tự nâng quyền để claim.
Không suy ra quyền approved chỉ từ việc đã tải một giấy tờ lên.

RPC là bề mặt chính cho nghiệp vụ; `POST /rest/v1/rpc/<tên_rpc>` bằng JWT user.
Không xây thêm REST server trùng lặp. Chỉ đọc trực tiếp các bảng hồ sơ riêng
được nêu ở mục 7; không thêm quyền đọc bảng đơn cho rescuer.

## 3. Schema đề xuất

Mọi cột owner là `NOT NULL`, derive từ Auth. ID nghiệp vụ là UUID sinh phía server
trừ khóa thao tác phía client. Timestamp do server ghi, dùng `timestamptz`/UTC.
Các CHECK/FK/unique sau đây là hợp đồng thiết kế được hiện thực trong migration
local, chưa phải DDL đã áp. Chọn `text` + CHECK thay vì sửa enum dùng chung.

### 3.1 `public.rescuer_profiles`

- `user_id uuid PK FK auth.users(id)`; một hồ sơ/UID.
- `full_name text NOT NULL`, trim dài 1–150; `contact_phone text NOT NULL`,
  chuẩn hóa và kiểm tra định dạng theo quy tắc cần chốt, không tự coi là đã xác minh.
- `verification_status text NOT NULL DEFAULT 'draft'`, trong
  `draft/submitted/approved/rejected/suspended`.
- `submitted_at`, `verified_at`, `verified_by` nullable; các trường xác minh
  chỉ writer tin cậy được thay đổi. Không trả lý do nội bộ nhạy cảm cho người khác.
- `version bigint NOT NULL DEFAULT 1 CHECK > 0`, `created_at`, `updated_at`.

Owner chỉ chỉnh allowlist tên/liên hệ. Thay dữ liệu định danh đã duyệt làm hồ sơ
cần duyệt lại theo quy tắc chốt trước rollout; không làm khi có job active để
tránh bỏ công việc giữa chừng. Không lưu bản chụp tài liệu định danh trong bảng.
FK/delete policy cho tài khoản có lịch sử phải chốt với retention; đề xuất
`ON DELETE RESTRICT` ở hồ sơ nghiệp vụ, không tự cascade xóa chứng cứ công việc.

### 3.2 `public.rescuer_documents`

- `id uuid PK`, `rescuer_id uuid FK rescuer_profiles(user_id)`.
- `document_type text` trong allowlist ban đầu: `identity/license/vehicle_registration`;
  loại nào bắt buộc theo dịch vụ phải xác minh, không mặc định tất cả đều đủ.
- `vehicle_id uuid NULL` chỉ cho giấy tờ xe; composite FK
  `(vehicle_id, rescuer_id)` đến xe cùng owner.
- `storage_path text UNIQUE NOT NULL`, bucket private riêng `rescuer-documents`;
  đường dẫn server tạo `<rescuer_id>/<document_id>`.
- `content_type text`, `byte_size integer > 0`, `uploaded_at NULL` đến khi kiểm
  tra object thực; limit/MIME xác lập ở bucket và RPC, không chỉ tin client.
- `verification_status` trong `submitted/approved/rejected/expired`; mặc định
  submitted nhưng `uploaded_at IS NULL` thì chưa đủ điều kiện xem xét.
- `expires_at`, `created_at`; metadata approval do trusted writer quản lý.

Tài liệu đã hoàn tất upload là bất biến; nộp mới tạo row/object mới, không upsert
ghi đè giấy tờ đã duyệt. Không grant cho khách hoặc rescuer khác. Không lưu raw
số căn cước nếu nghiệp vụ chưa chứng minh cần. Cơ chế scan/verification và retention
tài liệu chưa triển khai.

### 3.3 `public.rescuer_vehicles`

- `id uuid PK`, `rescuer_id uuid FK rescuer_profiles`, `UNIQUE(id, rescuer_id)`.
- `kind text` là loại phương tiện **cứu hộ**, dự kiến
  `service_motorbike/service_car/tow_truck/recovery_truck/other`;
  không nhầm với `rescue_requests.vehicle_kind` là xe khách cần trợ giúp.
- `display_name text`, `license_plate text` theo giới hạn/chuẩn hóa cần chốt.
- `verification_status draft/submitted/approved/rejected/suspended`,
  `is_active boolean DEFAULT true`, `version`, `created_at`, `updated_at`.
- Biển số normalized unique theo owner; quy tắc trùng giữa owner cần kiểm chứng,
  không thêm unique toàn quốc nếu chưa xác minh dữ liệu/quy tắc.

Không hard-delete xe đã gắn job. RPC khóa profile trước khi sửa; không đổi xe
đang phục vụ hoặc approval/capability bằng body tùy ý.

### 3.4 `public.rescuer_service_capabilities`

- `rescuer_id uuid`, `vehicle_id uuid`, `service_code text FK rescue_services(code)`.
- `customer_vehicle_kind text CHECK IN ('motorbike','car','truck','other')`.
- PK `(vehicle_id, service_code, customer_vehicle_kind)`; composite FK
  `(vehicle_id, rescuer_id)` đến xe cùng owner.
- `verification_status submitted/approved/rejected/suspended`, `is_enabled boolean`,
  `created_at`, `updated_at`. Approval do trusted writer, owner chỉ gửi đề nghị
  hoặc tắt capability đã có qua RPC.

Claim cần capability approved + enabled, xe approved + active và dịch vụ active.
Không suy ra năng lực kéo xe tải từ việc có phương tiện loại `other`.

### 3.5 `public.rescuer_online_status`

- `rescuer_id uuid PK FK rescuer_profiles`, `is_online boolean DEFAULT false`.
- `session_id uuid NULL`, `vehicle_id uuid NULL` composite FK cùng owner.
- `last_seen_at timestamptz`, `updated_at`; session/vehicle bắt buộc khi online.
- Không lưu `busy` như một sự thật thứ hai: tính busy từ assignment active.

Một session online hiện hành/UID. Bật online sinh session server; heartbeat cùng
session giữ nguyên. Muốn chuyển thiết bị thì cần một thao tác thay session rõ ràng,
không dùng heartbeat đến trễ làm sống lại session cũ. Tắt online không hủy assignment.

### 3.6 `public.rescuer_locations`

- `rescuer_id uuid PK FK rescuer_profiles`, `session_id uuid NOT NULL`.
- `latitude double precision [-90,90]`, `longitude double precision [-180,180]`,
  cả hai NOT NULL/finite; `accuracy_m double precision >= 0` và finite.
- `sequence bigint > 0`, `captured_at timestamptz`, `received_at timestamptz`
  do server ghi.

Chỉ lưu vị trí mới nhất, không tạo bảng hành trình vô hạn. Sequence tăng trong
session; retry cùng sequence chỉ được chấp nhận nếu payload giống; sequence cũ
hoặc session cũ không ghi đè. Timestamp tương lai/quá cũ bị từ chối.
Retry cùng sequence không làm mới received_at hoặc heartbeat: gửi lại một mẫu
GPS cũ không được biến mẫu đó thành vị trí mới. Online/location phải có cùng
session; offline có job active thì giữ session/xe job để tiếp tục cập nhật vị trí,
offline không có job active thì không cho location heartbeat kéo dài quyền.
Vị trí của rescuer không được trả cho mọi khách hoặc rescuer khác. Chia sẻ tracking
cho khách là yêu cầu tương lai riêng, không cấp quyền trong thiết kế này.

Ngưỡng đề xuất cần xác nhận: heartbeat và vị trí <= 120 giây, accuracy <= 100 m,
captured_at không quá 5 phút cũ hoặc hơn 30 giây tương lai. Kiểm tra độ mới theo
`received_at` kết hợp captured_at; không tin timestamp hoặc GPS client tuyệt đối.

### 3.7 `public.rescue_request_assignments`

- `id uuid PK`, `request_id uuid UNIQUE NOT NULL FK rescue_requests(id)`.
- `rescuer_id uuid FK rescuer_profiles`, `vehicle_id uuid` composite FK cùng owner.
- `state text` trong `accepted/en_route/arrived/in_progress/completed/cancelled`;
  assignment chỉ được tạo khi claim thành công, không có assignment pending.
- `version bigint > 0`, `accepted_at`, `en_route_at`, `arrived_at`,
  `in_progress_at`, `completed_at`, `cancelled_at`, `updated_at`.
- `current_quote_id uuid NULL`, `completion_quote_id uuid NULL` đến `rescue_quotes`;
  composite association phải khớp request/assignment/owner.
- `cancellation_reason_code text NULL`, actor/reason code server xác lập.
- Unique partial index trên `rescuer_id` khi state thuộc
  `accepted/en_route/arrived/in_progress` để chặn hai job đồng thời.
- Index history `(rescuer_id, accepted_at DESC, id DESC)` và FK lookup request.

`request_id UNIQUE` đảm bảo một người nhận trong phiên bản đầu; hủy là terminal,
không tự requeue hoặc chuyển cho người khác. Thiết kế tái phân công nhiều attempts
là việc riêng sau này, không âm thầm nới unique.

Với đơn claim mới: `rescue_requests.provider_id = rescuer_profiles.user_id`.
Không add FK cho toàn bộ provider_id ngay: phải kiểm kê ID cũ, null, orphan,
nguồn provider khác trước. Hai bảng được đồng bộ trong một transaction; không
cho client chọn owner/provider hay UPDATE riêng từng bảng.

### 3.8 `public.rescuer_assignment_events`

- `id uuid PK`, `assignment_id uuid FK`, `version bigint`, UNIQUE(assignment_id, version).
- `event_kind text` trong `claimed/status_changed/quote_issued/customer_cancelled`.
- `previous_state text NULL`, `state text` theo CHECK của assignment.
- `actor_kind rescuer/customer/system`, `actor_id uuid NULL`, `reason_code text NULL`,
  `occurred_at timestamptz` server.
- Append-only; không INSERT/UPDATE/DELETE từ client. DTO không xuất `actor_id`
  của khách, không lưu/đưa vào log free text chứa PII.

Trạng thái `arrived` có event riêng ở đây dù trạng thái coarse vẫn `arriving`.
Không backfill các thời điểm/actor chưa biết; chỉ ghi snapshot được gắn nhãn rõ
nếu cần nhập dữ liệu cũ sau xác minh.

### 3.9 `public.rescue_quotes`

- `id uuid PK`, `assignment_id`, `request_id`, `rescuer_id`, composite FK bảo đảm
  cùng assignment/request/rescuer; server derive tất cả quan hệ.
- `revision integer > 0`, UNIQUE(assignment_id, revision).
- `status text IN ('issued','superseded')`, một quote issued/assignment bằng
  partial unique index. Không có trạng thái paid, invoice hoặc payment transaction.
- `currency text CHECK = 'VND'`, `total_vnd integer CHECK >= 0`.
- `items jsonb NOT NULL` là array gồm `service_code`, `quantity`, `unit_price_vnd`;
  validate allowlist keys, số nguyên, giới hạn array/quantity và tính tổng phía server.
- `note text NULL` giới hạn dài; không trả trong history mặc định vì có thể chứa PII.
- `issued_at timestamptz`; quote đã issued không sửa số tiền/items, revision mới
  supersede bản cũ trong cùng transaction, giữ audit.

Chỉ tạo quote tại `arrived` hoặc `in_progress`. Completion yêu cầu quote issued,
khớp assignment; đóng băng `completion_quote_id` và sao chép tổng vào
`rescue_requests.quoted_price` (cột integer cũ). Mọi amount phải không vượt
2,147,483,647 VND để không overflow; nhân/tổng dùng bigint trước khi cast.

Quote là **giá đề xuất**, không chứng minh khách đã đồng ý hay đã thanh toán.
Không tự tạo consent. Nếu nghiệp vụ bắt buộc khách chấp nhận báo giá, phải thiết
kế thêm consent/RPC phía khách và chặn completion cho đến khi có consent thật;
đó là quyết định chưa chốt trước production, chưa sửa UI khách trong lượt này.

### 3.10 `private.rescuer_rpc_receipts`

Schema `private` không nằm trong exposed schemas của Data API.

- PK `(rescuer_id uuid, operation_id uuid)`; `operation_name text`,
  `payload_hash text`, `resource_id uuid`, `committed_at timestamptz`.
- Không lưu DTO PII/contact/địa chỉ hoặc signed URL để trả lại sau khi đã mất quyền.
- Tất cả mutation RPC nhận `p_operation_id uuid`; canonicalize payload phía server,
  băm cả tên operation, resource và tham số nghiệp vụ.
- Retry cùng khóa/payload trả resource hiện tại theo quyền hiện tại; khác payload
  trả `IDEMPOTENCY_CONFLICT`, không chạy thao tác mới. Receipt cùng transaction
  với mutation, không có receipt cho thay đổi rollback.
- Retention khóa không được ngắn hơn thời gian đảm bảo retry đã công bố; đặc biệt
  claim/quote/event không được xóa khóa sớm rồi cho tạo lại. Chốt retention trước DDL.

## 4. Bộ trạng thái và tương thích khách hàng

| Trạng thái API người cứu hộ | Nơi lưu chi tiết | `rescue_requests.status` giữ tương thích |
|---|---|---|
| `pending` | Discovery suy ra từ đơn searching chưa có provider/assignment | `searching` |
| `accepted` | Assignment | `accepted` |
| `en_route` | Assignment | `arriving` |
| `arrived` | Assignment + event riêng | `arriving` |
| `in_progress` | Assignment | `in_progress` |
| `completed` | Assignment | `completed` |
| `cancelled` | Đơn chưa nhận hoặc assignment đã nhận | `cancelled` |
| `expired` | Chưa đưa vào phiên bản đầu | Không ghi giá trị mới vào cột cũ |

Luồng bình thường:

```text
pending -> accepted -> en_route -> arrived -> in_progress -> completed
```

Khách được hủy pending/accepted đúng hợp đồng cũ. Rescuer được hủy job active
của mình với reason_code hợp lệ; sau terminal không reopen. Không cho bỏ bước,
claim trực tiếp từ terminal hoặc chuyển completed sang cancelled.
`accepted` chỉ qua claim RPC; RPC cập nhật trạng thái không dùng để tự nhận đơn.
Expired chưa cần: giữ pending đến khi có quyết định TTL/worker riêng. Không dùng
`cancelled` để giả một expiration không được khách nhìn nhận; không thêm cron.

Assignment là nguồn cho trạng thái chi tiết của job đã nhận; cột đơn là projection
coarse phục vụ hợp đồng khách hiện có. Đơn chưa có assignment dùng cột đơn.
Không thêm một cột fine-status khác trên bảng đơn với semantics chồng chéo.

## 5. Hợp đồng RPC/API đề xuất

### Quy tắc chung

- Mutation nhận `p_operation_id uuid` (bắt buộc); cập nhật resource đã có nhận
  `p_expected_version bigint` nếu resource có cột version. Online/location dùng
  session/sequence thay cho version để kiểm soát stream. Server derive caller và
  mọi owner/FK liên quan.
- Từ chối null, enum ngoài allowlist, tọa độ NaN/Infinity và tham số quá dài.
- Không overload tên RPC theo nhiều chữ ký dễ gây mơ hồ PostgREST.
- RPC đọc trả `RETURNS TABLE` hoặc JSON có schema cố định; không `SETOF rescue_requests`,
  không `SELECT *`, `row_to_json(r)` hay phản hồi lỗi chứa row/contact.
- Datetime là UTC; distance là ước tính, amount integer VND, cursor không chứa PII.
- Unauthorized request detail/claim trả cùng `REQUEST_UNAVAILABLE` cho UUID không
  tồn tại, không đủ quyền hoặc không còn available; không làm oracle tồn tại đơn.
- Lỗi nội bộ/FK/unique được chuyển sang mã nghiệp vụ; không nuốt lỗi không liên quan.
- Không coi membership đã check ở màn hình/app là đủ; check lại bên server mỗi lần.

### Danh sách endpoint

Trong bảng dưới đây, `op` = `p_operation_id`, `ver` = `p_expected_version`.

| RPC | Input nghiệp vụ ngoài op/ver | Output giới hạn | Điều kiện chính |
|---|---|---|---|
| `rescuer_register_profile` | `p_full_name text`, `p_contact_phone text`, op | own profile + version | Auth; tạo draft/owner server, retry không tạo lại |
| `rescuer_update_profile` | tên/liên hệ, op, ver | own profile + version | Owner; không sửa approval; quy tắc re-verification |
| `rescuer_submit_profile` | op, ver | submission status/version | Các tài liệu bắt buộc đã upload thật; không tự approved |
| `rescuer_reserve_document` | loại tài liệu, vehicle_id nullable, MIME, byte_size, op | document_id + reserved path | Xe phải own; chưa cấp trạng thái verified |
| `rescuer_complete_document` | `p_document_id uuid`, op | own document metadata | Kiểm tra object bucket/path/MIME/size trước uploaded_at |
| `rescuer_register_vehicle` | kind, tên, biển số, op | own vehicle + version | Owner server; draft; không có params approval |
| `rescuer_update_vehicle` | `p_vehicle_id uuid`, allowlist fields, op, ver | own vehicle + version | Không xe job active; không sửa owner/verification |
| `rescuer_set_capability` | vehicle_id, service_code, customer_vehicle_kind, enabled, op | capability metadata | Xe own; gửi submitted hoặc tắt; không nâng approved |
| `rescuer_set_online` | `p_online boolean`, vehicle_id nullable, session_id nullable, op | online status, session, server time, busy derived | Bật cần approved/profile/xe; cùng session heartbeat; thay session rõ; offline không hủy job |
| `rescuer_update_location` | session_id, sequence bigint, lat/lon/accuracy double, captured_at timestamptz, op | received_at + accepted sequence | Profile/xe/session hợp lệ; GPS mới; cần cho job active dù offline |
| `rescuer_list_available_requests` | vehicle_id, `p_limit integer DEFAULT 20`, cursor nullable | trang AvailableRequestDTO | Eligible + online fresh + not busy; limit 1–50; capability; vị trí server đã lưu |
| `rescuer_get_available_request` | `p_request_id uuid`, vehicle_id | AvailableRequestDTO | Cùng check với list, chỉ pending; không có đường full-detail preclaim |
| `rescuer_claim_request` | request_id, vehicle_id, op | AssignmentDTO + dữ liệu job hiện được phép | Atomic claim; fresh/eligible/not busy; không nhận đơn của chính mình |
| `rescuer_get_active_job` | không, hoặc assignment_id để lấy đúng job own | ActiveJobDTO + version | Own active; profile còn quyền; offline không làm mất job |
| `rescuer_update_job_status` | assignment_id, target_state text, reason_code nullable, op, ver | AssignmentDTO + version | Own active, transition hợp lệ, optimistic concurrency; completed cần quote |
| `rescuer_create_quote` | assignment_id, items jsonb, note nullable, op, ver | QuoteDTO + assignment version | Own arrived/in_progress; tổng do server tính; issued immutable |
| `rescuer_list_job_history` | limit DEFAULT 20, cursor nullable, state_filter nullable | trang HistoryDTO | Chỉ assignment own terminal; không contact/address/pics |
| `rescuer_get_job_history` | assignment_id | HistoryDTO + event/quote summary đã lọc | Own terminal; không dùng active-detail trả PII cho lịch sử |

Discovery chỉ dùng vehicle_id đúng xe online hiện hành. Cursor keyset dùng cặp
distance coarse + request_id, được kiểm tra và gắn với session/sequence vị trí;
session hoặc vị trí đổi thì bắt đầu trang mới. Mỗi trang check lại eligibility,
không dùng cursor để bỏ qua ownership, giới hạn trang hoặc điều kiện pending.

Cập nhật profile/vehicle/capability bị serialize cùng claim qua khóa profile; không
đổi cấu hình đã dùng để nhận job khi job đang active. Các receipt retry được xét
trước version/freshness khi caller vẫn sở hữu resource, nhưng DTO lại được kiểm
tra quyền: retry sau hủy/completed/suspended không mở lại PII.

`set_online`: `p_online=true` và session null bắt đầu/thay phiên theo thao tác op;
retry cùng op nhận lại cùng session. Heartbeat truyền session hiện tại, session
cũ trả `STALE_ONLINE_SESSION`. Khi job active, thay session phải giữ đúng xe job;
không chuyển xe bằng heartbeat. Tắt online làm mất quyền discovery/claim ngay,
nhưng active-job vẫn được đọc và cập nhật theo assignment.

Mã lỗi đề xuất: `AUTHENTICATION_REQUIRED`, `PROFILE_NOT_READY`, `PROFILE_SUSPENDED`,
`VEHICLE_NOT_READY`, `CAPABILITY_UNAVAILABLE`, `LOCATION_NOT_FRESH`,
`STALE_ONLINE_SESSION`, `STALE_LOCATION_SEQUENCE`, `REQUEST_UNAVAILABLE`,
`RESCUER_BUSY`, `VERSION_CONFLICT`, `IDEMPOTENCY_CONFLICT`,
`INVALID_STATUS_TRANSITION`, `QUOTE_REQUIRED`, `INVALID_QUOTE`, `DOCUMENT_NOT_READY`.
Mã quyền dùng SQLSTATE 42501, input dùng 22023, xung đột nghiệp vụ P0001 kèm code;
không dựa vào giả định P0001 luôn tương đương HTTP 409. HTTP adapter, nếu có về sau,
phải map riêng, trong phạm vi này dùng trực tiếp lỗi PostgREST/RPC.

### DTO và quyền riêng tư

**AvailableRequestDTO**, cùng schema cho list và preclaim detail, allowlist duy nhất:

```text
request_id
approximate_location {latitude, longitude, cell_size_degrees, precision: "coarse"}
service_type
vehicle_type
estimated_distance_km
```

UUID chỉ là tham chiếu thao tác, không phải thông tin nhận dạng khách.
Không trả `customer_id`, `client_request_id`, vehicle_id khách, contact/name/phone,
location_text, tọa độ chính xác, description free text, ảnh/path/URL, giá hoặc lịch sử.
Không đưa những trường đó vào nested join, thông báo Realtime, lỗi hoặc logs.

Vị trí approximate là tâm ô cố định theo tọa độ đơn, dự kiến grid 0.01 độ; không
random hóa lại ở mỗi lần đọc vì nhiều mẫu có thể giúp suy ra vị trí thật. Grid
degree không có kích thước mét đồng nhất và không đảm bảo ẩn danh ở nơi ít dân.
Estimated distance tính đến **tâm ô approximate** từ vị trí rescuer đã lưu,
làm tròn theo bước dự kiến 1 km; không phải đường đi/ETA và không có routing API.
Filter bán kính, ranking và cursor cũng phải dựa vào vị trí/độ xa coarse, không
dùng tọa độ thật ở điều kiện lọc để tạo oracle đo khoảng cách/trilateration.
Không cho truyền tâm lat/lon tùy ý vào discovery. Khoảng bán kính cố định do server
chọn theo cấu hình đã chốt, không cho tìm toàn quốc hoặc thay radius từng mét.
Rate limit theo UID/session, giới hạn truy vấn/cursor và phát hiện đổi GPS bất thường
phải được triển khai trước public rollout; GPS client vẫn có thể bị giả mạo.

Đơn thiếu một/cả hai tọa độ bị loại khỏi discovery và claim trong bản đầu.
Không bịa tọa độ, không dùng (0,0), không tự geocode địa chỉ. Những đơn này vẫn
ở luồng khách hiện tại; cách xử lý cần quyết định riêng trước rollout.

**ActiveJobDTO**: assignment_id, request_id, state, version, service/vehicle type,
contact_name, contact_phone, location_text, exact lat/lon nullable, description
của chính đơn, quote summary. Dùng contact đã lưu trên request; không đọc toàn bộ
`customer_profiles`, `customer_vehicles`, địa chỉ lưu hoặc thông tin Auth.
Ảnh chỉ đưa metadata không nhận dạng khách vào DTO khi cơ chế ở mục 8 được duyệt.
Không xuất storage_path mang customer UUID trước khi có quyền.

**AssignmentDTO**: assignment_id, request_id, state, version, vehicle_id của chính
rescuer, các timestamp job và quote amount/currency hiện tại. Không chứa contact,
customer UUID, địa chỉ hay tọa độ; full data chỉ trong ActiveJobDTO sau check active.
**QuoteDTO**: quote_id, assignment_id, request_id, revision, status, currency,
total_vnd, items đã validate và issued_at. Note chỉ trả cho rescuer own job active,
không xuất qua history. Mỗi item.service_code phải khớp dịch vụ đơn; thêm danh mục
phụ phí/vật tư riêng là quyết định tương lai, không tự tạo trong luồng báo giá này.

**HistoryDTO**: assignment_id, request_id, service/vehicle type, state, các timestamp
job, cancellation reason_code, completion quote amount/currency và event summary.
Không contact, exact coordinates, địa chỉ, description/note free text, ảnh hoặc
actor UUID khách. Không lấy toàn bộ request rồi chỉ trông chờ app ẩn field.

## 6. Transaction nhận đơn và cập nhật trạng thái

### 6.1 Claim tránh hai người cùng nhận

Mọi mutation rescuer giữ thứ tự khóa: **profile rescuer -> request -> assignment
-> quote/receipt phụ thuộc**. Location/online/profile/vehicle mutations cũng khóa
profile trước. Không lấy khóa assignment rồi quay lại lấy khóa request.

Pseudocode thiết kế, chưa phải function được cài:

```text
BEGIN (RPC là một transaction)
  xác minh auth.uid(), payload, operation_id
  SELECT own rescuer_profile FOR UPDATE
  nếu có receipt khớp payload: trả resource theo quyền hiện tại, kết thúc
  SELECT request WHERE id = input FOR UPDATE
  check approved + xe + capability + online/session/location mới sau khi có khóa
  check request.status = searching AND provider_id IS NULL
  check chưa có assignment và customer_id <> caller
  check không có assignment active khác của caller
  INSERT assignment(state=accepted, version=1, owner/vehicle derive server)
  UPDATE rescue_requests
    SET provider_id=caller, status=accepted
    WHERE id=input AND status=searching AND provider_id IS NULL
  assert đúng 1 row; trigger hiện có ghi coarse event searching->accepted
  INSERT assignment event claimed; INSERT receipt
  validate consistency và COMMIT; trả DTO allowlist
```

Hai rescuer có hai profile lock khác nhau nhưng cùng request lock: người tới sau
đợi, rồi đọc trạng thái mới và thất bại mà không nhận PII. Cùng rescuer claim hai
đơn: profile lock serialize, unique active-rescuer là lớp bảo vệ cuối.
UNIQUE(request_id) bảo vệ duplicate assignment. Không dùng đọc available trên
client rồi UPDATE không điều kiện; không coi UUID khó đoán là authorization.

Không dùng `SKIP LOCKED` cho claim một UUID: đang bận khóa không đồng nghĩa đã
biến mất. Thiết lập lock/statement timeout có giới hạn, retry cùng operation_id
khi timeout hoặc mất response. Read committed + row lock + unique constraints
là baseline cần kiểm thử song song; lỗi uniqueness phải rollback toàn mutation.
Hồ sơ chưa tồn tại trả PROFILE_NOT_READY thay vì khóa một row không có.

### 6.2 Transition/quote/completion

1. Khóa profile, request, assignment theo thứ tự; xác minh owner/provider và quyền
   hiện tại. Đọc receipt trước expected_version để retry không tạo event mới.
2. Check expected_version; stale trả VERSION_CONFLICT để client fetch lại.
3. Check edge của đồ thị trạng thái. `arrived` không được skip sang completed.
4. Tăng assignment.version một lần, ghi timestamp/event server; map coarse status
   và cập nhật request cùng transaction. `arrived` giữ request.status=arriving,
   không bịa coarse event `arrived` mà khách chưa hiểu.
5. Quote cũng khóa request/assignment, tăng version và ghi event quote_issued;
   supersede quote cũ, insert quote mới, sync quoted_price nguyên tử. Không cho
   client viết quoted_price qua REST hoặc sửa quote cũ.
6. Completion chỉ từ in_progress, có quote issued cùng assignment;
   freeze completion_quote_id, mark completed, chốt giá quote và event trong
   cùng transaction. Không cho quote phát hành sau terminal.
7. Hủy/hoàn tất giải phóng busy thông qua partial index state, không bật online
   tự động. PII bị đóng ở lần đọc/Storage authorize tiếp theo.

Retry transition/quote sau network timeout trả current summary theo receipt,
không lùi state hoặc hồi sinh job. Một request chuyển terminal giữa quote và
completion làm completion thất bại, không có cập nhật giá/status nửa chừng.

### 6.3 Đồng bộ hủy từ RPC khách và bảo vệ consistency

RPC khách hiện có UPDATE request trước; migration local bổ sung một AFTER UPDATE
hook riêng, tên riêng, khi đơn chuyển cancelled và đã có assignment thì cập nhật
assignment, version, cancelled_at và event customer_cancelled trong transaction
của khách. Khóa theo request -> assignment; **không** quay lại khóa profile rescuer
trong hook để tránh đảo thứ tự với claim.

Nếu rescuer đã mark assignment cancelled trước khi update coarse row, hook phải
nhận biết và không ghi event/version lần hai. Actor lấy từ caller đã xác minh
hoặc system trusted, không tin actor do client nhập.

Customer cancellation cạnh tranh claim: cùng request lock; nếu khách thắng thì
claim không được thực hiện. Nếu claim thắng và job còn accepted thì khách vẫn
hủy được theo RPC cũ, assignment đồng bộ và người cứu hộ không chuyển tiếp.
Nếu đã en_route thì coarse arriving: RPC khách vẫn từ chối hủy như hiện tại.

Cần constraint trigger deferred trên assignment/request để kiểm tra lúc commit:
provider khớp rescuer, mapping fine/coarse khớp, quote/completion khớp assignment.
Đơn legacy chưa có assignment không bị tự suy đoán/backfill provider/actor.
Trusted scripts không được làm lệch assignment mới: kiểm tra consistency phải
từ chối update coarse đơn đã gán mà bỏ qua state tương ứng.
`dev_advance_request.sql` hiện có chưa đáp ứng điều đó và không được dùng để
kiểm thử flow mới mà không thiết kế lại sau; không sửa/chạy script trong lượt này.

## 7. RLS, grants và bảo vệ RPC

RLS lọc row không đủ để che các cột PII trong một row đã được phép SELECT.
Giữ policy owner trên `rescue_requests`; không thêm policy cho tất cả rescuer đã
duyệt, kể cả với `.select('ít_cột')` từ app. Tham số select có thể bị attacker đổi.
Các RPC privileged đọc row nội bộ rồi trả projection allowlist đã nêu.

| Resource | Authenticated owner đọc trực tiếp | Client ghi trực tiếp | Quyền ngoài owner |
|---|---|---|---|
| customer_profiles/vehicles/saved_addresses/reviews | Giữ chính sách cũ của khách | Giữ grant/RPC cũ của khách | Rescuer không thêm quyền |
| rescue_requests/request_status_events | Khách sở hữu như hiện tại | Không thêm UPDATE/INSERT/DELETE | Rescuer chỉ qua RPC có lọc |
| rescuer_profiles | UID = user_id | Không; qua RPC allowlist | Không khách/rescuer khác |
| rescuer_documents/vehicles/capabilities | UID = rescuer_id | Không; qua RPC | Không ngoài owner |
| rescuer_online_status/locations | UID = rescuer_id | Không; qua RPC | Không đọc vị trí/tình trạng toàn hệ thống |
| assignments/events/quotes | Không cấp SELECT trực tiếp trong bản đầu | Không | Chỉ RPC own job/history; khách thấy quoted_price đơn own qua contract cũ |
| private.rescuer_rpc_receipts | Không | Không | Chỉ internal writer |
| Storage giấy tờ | Owner theo bucket + reserved metadata | INSERT object đã reserve; không UPDATE/DELETE | Không khách/rescuer khác |
| Storage ảnh đơn | Chủ đơn giữ quyền cũ | Rescuer không có quyền ghi | Rescuer assigned-active nếu phương án mục 8 được duyệt |

Enable RLS trên tất cả bảng mới, kể cả bảng RPC-only và private receipts.
REVOKE grants mặc định của PUBLIC/anon/authenticated trên **bảng mới** trước khi
grant SELECT own cần thiết. RPC-only không có table grant; có policy owner làm
lớp bảo vệ nếu grant được thêm về sau, nhưng không coi RLS thay thế column filtering.
Assignment events policy đi qua helper internal kiểm tra assignment owner, không
xuất actor_id khách qua direct SELECT. Quotes có thể có policy own-assignment và
customer-own-request cho tương lai; chưa cấp trực tiếp SELECT cho những role này.

Các bảng có authenticated SELECT dùng `USING ((select auth.uid()) = owner_column)`.
Không có policy `USING (true)` cho tài liệu, tọa độ, đơn hoặc quote. Không tự cấp
INSERT/UPDATE để owner có thể sửa verification_status, verified_by, provider/state.

RPC có thể cần SECURITY DEFINER vì authenticated không có quyền ghi bảng và
rescuer không có SELECT bảng đơn. Mỗi function phải:

- `SET search_path = ''`, schema-qualify relation/helper, không dynamic SQL từ input.
- Check auth.uid, owner, approval, assignment và trạng thái ở mọi đường return/retry.
- REVOKE EXECUTE từ PUBLIC/anon theo đúng tên + signature, chỉ GRANT EXECUTE
  cho authenticated ở endpoint được thiết kế. Quyền execute không thay thế check role.
- Helper/trigger đặt ở schema private không exposed; chỉ cấp usage/execute cho
  helper boolean mà policy thật sự cần. Không có helper trả toàn bộ row nhạy cảm.
- Review owner/role privileged của function; SECURITY DEFINER có thể vượt RLS nên
  không gọi SELECT * rồi tin table policy. Không thêm BypassRLS cho authenticated.
- Không revoke toàn bộ function public hiện tại, vì làm hỏng RPC khách đang dùng.
- Không mở view mặc định definer hoặc materialized view chứa PII ra Data API.

Policy/helper phải tránh vòng lặp RLS: Storage helper kiểm tra metadata + assignment
nội bộ theo quyền đã duyệt, không đọc qua bảng có policy quay lại Storage.
Các helper trả bool không được dùng để liệt kê arbitrary customers hoặc documents.
Không bật Realtime của bảng đơn cho rescuer vì sẽ cần nới SELECT và gây lộ row.
Bản đầu rescuer refresh bằng RPC; Realtime của khách hiện có giữ nguyên. Thiết kế
notification sanitised riêng, nếu cần sau này, phải qua review độc lập.

## 8. Quyền ảnh/tài liệu và thu hồi truy cập

Giấy tờ người cứu hộ và ảnh khách là hai bucket private độc lập. Đọc giấy tờ chỉ
owner hoặc quy trình xác minh tin cậy chưa xây; không theo quyền assignment.
Kiểm tra MIME/size/object tồn tại sau upload, không dùng metadata client để duyệt.

**Ảnh khách: mặc định chưa mở cho rescuer cho đến khi quy tắc chia sẻ được chốt.**
Nếu cho phép, predicate phải gồm: ảnh uploaded_at NOT NULL, request đúng assignment,
provider/owner khớp caller, assignment active, hồ sơ caller còn quyền. Không đủ
điều kiện thì trả không có ảnh/deny; không cho bất kỳ rescuer nào đọc ảnh pending.

Phương án trực tiếp bằng JWT cần cả:

1. RPC active-detail trả tham chiếu ảnh đã lọc; không grant toàn bộ metadata ảnh.
2. Policy Storage permissive cho assigned-active đọc.
3. Sửa **predicate restrictive owner-on-read** của bucket hiện có thành owner OR
   assigned-active với cùng điều kiện; giữ nguyên bucket isolation và các policy
   INSERT/UPDATE/DELETE/anon restrictive. Không tắt RLS hoặc đổi bucket thành public.
4. Vì predicate hiện có JOIN qua owner-only rescue_requests/rescue_request_photos,
   nhánh rescuer cần helper nội bộ được review; không giải quyết bằng mở SELECT PII.

Lưu ý: Storage SELECT cấp theo đối tượng, không phân biệt hết mục đích download và
createSignedUrl. Với quyền này rescuer có thể yêu cầu signed URL; thời hạn do app
chọn không phải một giới hạn bảo mật được enforce bằng RLS. URL đã phát hành
không nhất thiết mất hiệu lực khi assignment hủy hoặc JWT bị revoke.

Nếu nghiệp vụ yêu cầu đóng mọi lần đọc mới ngay khi hủy, **ưu tiên phương án proxy
server có JWT user, kiểm tra assignment mỗi lần và stream ảnh**; giữ Storage raw
access đóng với rescuer, không trả signed URL cho rescuer. Proxy là API kỹ thuật
dự kiến, chưa tạo Edge Function và chưa cấp service credential trong lượt này.
Không thay proxy bằng publishable key rồi giả định vượt Storage RLS được.

Nếu chấp nhận rủi ro URL tồn tại đến expiry, có thể dùng signing server giới hạn
TTL cố định sau authorization, nhưng phải không cấp raw SELECT cho rescuer để họ
tự yêu cầu TTL lớn hơn; cần thiết kế gateway cụ thể và kiểm thử trước mở ảnh.
TTL ngắn không thu hồi ảnh đã tải hoặc chụp màn hình; client cache/local retention
và consent vẫn cần quyết định. Không cam kết xóa dữ liệu đã đọc bằng RLS.

## 9. Rủi ro/xung đột và hướng xử lý

| Rủi ro thực tế từ repository | Quyết định thiết kế / việc cần xác minh |
|---|---|
| Enum/check/index/trigger/query khách không hiểu pending/en_route/arrived/expired | Mapping ở mục 4, fine state ở assignment; không đổi status cũ |
| provider_id không FK và có thể là ID ngoài Auth | Kiểm kê provider legacy; claim mới dùng UID; không ép FK/backfill bằng dữ liệu giả |
| Auth tạo customer profile cho rescuer | Hai hồ sơ cùng UID được phép; approval DB quyết định năng lực, không đổi trigger |
| Thêm policy đọc đơn cho rescuer lộ cả row/contact và Realtime | RPC projection + giữ customer-only table RLS |
| Chính sách Storage restrictive chặn rescuer | Review hai loại policy cùng helper; ảnh mặc định đóng đến khi chọn phương án |
| Khách hủy sau claim tạo sidecar lệch | Hook transaction hủy + deferred consistency check, không sửa chữ ký cancel RPC |
| Đơn địa chỉ thủ công thiếu GPS | Không khả dụng trong discovery đầu; không fake/geocode tự ý; cần phương án xử lý |
| Quote và completion chưa có consent nghiệp vụ | Không giả đã chấp thuận/paid; chốt requirement trước triển khai |
| Giá cột hiện tại là integer | Giới hạn VND phù hợp, bigint khi tính; không ALTER rộng cột ngoài nhu cầu |
| Trusted dev script đổi status không có assignment/provider | Không dùng để chứng minh flow mới; không backfill accepted_at/arrived_at giả |
| Fake GPS/rate scraping/repeated coarse location | Coarse mọi filter/sort/output + rate limit, kiểm soát online session; vẫn có rủi ro metadata |
| Suspension/expired document lúc job active | Chặn claim mới và PII khi suspended; cần quy trình tin cậy xử lý job đang làm, chưa có admin |
| Legacy completed/cancelled không có assignment | Không tự nhận vào history rescuer; chỉ những assignment có chứng cứ đã làm |
| Idempotency/đồng thời cancellation/quote/profile | Khóa thống nhất + version + receipt + unique index, kiểm thử thực trước rollout |
| Account deletion và cascade cũ | Không thay semantics cũ trong lượt này; xác minh retention/FK và quy trình xóa trước DDL |

## 10. Migration local đã tạo, chưa áp

Migration `202610020001_rescuer_backend_foundation.sql` nằm sau 6 file cũ và không
rewrite các file đó. Các bước dưới đây đã gộp trong một transaction cho foundation
và RPC; quyền ảnh khách/gateway vẫn là công việc riêng sau khi chốt mục 12:

1. Foundation tables, private receipts, FK/index/check/grants/RLS. Không seed rescuer,
   assignment, quote hoặc hồ sơ approved giả.
2. RPC + fine/coarse consistency + cancellation hook trong transaction hoàn chỉnh;
   bật execute chỉ sau khi toàn bộ invariant đã có. Không publish claim nửa vời.
3. Quyền ảnh/gateway là bước riêng chỉ sau quyết định privacy và review restrictive
   policies. Không tự bật chia sẻ trong foundation migration.

Migration phải assert các table/column/type/constraint/function/policy tiền đề
đúng shape và fail với SCHEMA_MISMATCH nếu khác; không dùng IF NOT EXISTS để lờ
schema drift. Có thể dùng IF NOT EXISTS cho index/extension khi đã đối chiếu đúng
định nghĩa, create-or-replace cho function cùng chữ ký và có review quyền.
Policy replacement có predicate cụ thể, không drop policy unrelated. FK mới lên
provider chỉ khi đã kiểm kê và quyết định dữ liệu legacy.

Rollback thiết kế: đóng execute endpoint mới, dừng nhận job mới, giữ data/audit
và quyền khách cũ. Không DROP bảng history để rollback; xử lý job active trước
thay trigger/sync. Backup, kế hoạch thời gian khóa, dry-run DB local và kiểm thử
staging cần có trước khi xin triển khai môi trường thật. Không có lệnh db push
hay hướng dẫn chạy tự động ở lượt thiết kế này.

## 11. Ma trận kiểm tra bắt buộc trước áp Supabase thật

**Chưa thực hiện các kiểm tra DB/API/Storage dưới đây.** Đây là tiêu chí nghiệm thu
cho migration/RPC được triển khai sau, không phải kết quả đã đạt.

| Nhóm | Trường hợp cần kiểm tra | Kết quả yêu cầu |
|---|---|---|
| Schema/grants | Kiểm kê migration đã áp, các default grants, function owners/signatures, RLS/policies/Realtime | Không object drift, không bảng/query nhạy cảm bị mở |
| Customer regression | Tạo/retry/hủy đơn, one-active, tracking/history/review, upload/list ảnh riêng | Hợp đồng cũ không đổi; trạng thái vẫn trong enum khách |
| Onboarding | Auth UID khác, metadata role tự đặt, direct PATCH approval/owner, giấy tờ chưa upload | Không nâng quyền; owner chỉ sửa allowlist qua RPC |
| Capability/session | Profile/xe chưa duyệt, session cũ, offline, tọa độ stale/NaN/Infinity, sequence đảo | Discovery/claim bị chặn; job active không tự mất |
| Preclaim privacy | Hai rescuer, khách khác, UUID đoán; nested select, REST table, RPC errors, Realtime | Chỉ 5 trường DTO coarse, không contact/photo/ID khách |
| Coarse probing | Đổi vị trí/radius/cursor và gọi nhiều lần, filter/ranking quanh vị trí target | Không lộ tọa độ thật bằng exact-distance/threshold oracle |
| Claim concurrency | Hai JWT rescuer cùng UUID, cùng rescuer hai UUID, cancel vs claim | Chỉ một assignment/provider hợp lệ, busy được enforce |
| Retry | Timeout sau commit, op cùng payload/op khác payload, retry sau terminal/suspension | Không duplicate, không stale PII, mismatch bị từ chối |
| Lifecycle | Skip/regress/sửa job người khác, customer cancel cạnh tranh status/quote | Khóa/version nhất quán, transition đúng, lỗi không partial write |
| Quote | Overflow/âm/float/tổng sai, khác assignment, retry/revision, completed không quote | Tính server, quote immutable, completion atomic, không giả consent |
| Storage | Metadata pending, direct object path, public URL, signed URL TTL dài, sau hủy/completed | Không preclaim/cross-owner access, hiểu rõ giới hạn thu hồi |
| Terminal history | Query history và retry active-detail khi job terminal | Không phone/address/GPS/photo/free text PII |
| Consistency | Trusted writer cập nhật coarse state/provider sai, dev script old | Invariant từ chối lệch assignment mới; không tạo lịch sử giả |
| Load/deadlock | Lock timeout/profile update/location/status/cancel song song, query plan discovery | Timeout có kiểm soát, retry an toàn, không đảo thứ tự khóa |

Không dùng tài khoản, đơn hoặc giấy tờ thật để seed kế hoạch này. Đã tạo fixture
tổng hợp trong `tests/rescuer_local_regression.sql` theo phạm vi local được yêu cầu;
chưa chạy do local DB chưa sẵn sàng. Không tự mở rộng sang staging/Supabase thật.

## 12. Quyết định cần xác minh và phần chưa làm

Trước khi viết/áp migration cần xác minh:

1. Project/ref/env thật, database version/extensions, migration history và schema
   inventory; provider legacy có đại diện user/Auth hay một bảng provider khác.
2. Tổ chức/quy trình tin cậy xét hồ sơ, loại giấy tờ và expiry theo service/vehicle,
   cách đình chỉ và xử lý job active. Không tự xây admin để giải quyết trong lượt này.
3. Cho phép một job/ rescuer, không reassign sau hủy trong bản đầu có đúng nghiệp vụ;
   cần expiry hoặc dispatch cho đơn không GPS hay không.
4. Chốt grid/bán kính/heartbeat/accuracy/rate limit/retention, bảo vệ địa điểm ở
   vùng ít dân và rủi ro GPS giả. Các ngưỡng đang là tham số đề xuất, không dữ liệu đo.
5. Quote trước hoàn tất có cần consent khách không; giới hạn giá/line items,
   lý do hủy và điều kiện chuyển in_progress/completed.
6. Ảnh có được chia sẻ sau claim không; chọn gateway hoặc chấp nhận signed-URL
   expiry, consent, thời hạn lưu/cache, mức thu hồi kỳ vọng.
7. Retention tài liệu/history/receipt và xóa tài khoản; không tự sửa cascade cũ.
8. Tương thích all writers, cancellation hook/trigger order và migration rollback;
   policy/grants thực tế có thể khác 6 file trong repository.

Chưa làm: migration SQL mới, áp SQL/local DB, RPC/Edge Function thực thi, RLS/grants
thực tế, Auth/Storage config, verification pipeline, rate-limit runtime, UI/Stitch,
Supabase Flutter integration, admin, thanh toán, job workers và database tests.
Không có auto-commit. App rescuer vẫn là project tối thiểu hiện thông báo chuẩn bị.

## 13. Nguồn kỹ thuật chính thức

Tài liệu chính thức được dùng để đối chiếu cơ chế bảo mật; các quyết định nghiệp vụ
và schema đề xuất trong tài liệu này là thiết kế riêng, không phải thông tin về
database thật:

- [Supabase Database Functions](https://supabase.com/docs/guides/database/functions):
  invoker/definer, empty search_path và quyền execute.
- [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security):
  Auth UID, table policy và giới hạn quyền của function/view.
- [Supabase Storage Access Control](https://supabase.com/docs/guides/storage/security/access-control):
  authorization object bằng RLS.
- [Supabase Serving assets](https://supabase.com/docs/guides/storage/serving/downloads):
  private download/signed URL; URL đã ký có vòng đời riêng với Auth JWT.
- [PostgreSQL Row Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html):
  kết hợp permissive OR và restrictive AND, khác với grants.
- [PostgreSQL Explicit Locking](https://www.postgresql.org/docs/current/explicit-locking.html):
  row lock, concurrent update và deadlock; cần kiểm thử với DB version thật.
