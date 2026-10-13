# Payment core security — báo cáo triển khai

Ngày: 2026-10-10. Source of truth: [payment_backend_plan.md](payment_backend_plan.md), với phạm vi được thu hẹp theo yêu cầu triển khai core security.

**Đã tạo source migration và regression; đã thực thi trong PostgreSQL PGlite cô lập trong RAM. Chưa áp dụng vào Supabase local, môi trường dev từ xa hoặc production. Không deploy, không commit.** Không sửa frontend/customer_app, frontend/rescuer_app hoặc admin_web. Các thay đổi frontend có sẵn trong workspace thuộc công việc trước đó.

## 1. File migration và phạm vi

- [202610100001_payment_core_security.sql](../backend/supabase/migrations/202610100001_payment_core_security.sql)
- [payment_core_security_regression.sql](../backend/supabase/tests/payment_core_security_regression.sql)
- Báo cáo này: `docs/payment_core_security_implementation.md`.

Chỉ một migration mới. Không sửa migration cũ. Migration chạy trong transaction, có lock timeout 5 giây và statement timeout 60 giây; thiếu prerequisite hoặc đã có bảng/sequence payment thì dừng, không âm thầm merge/overwrite. Rerun được kiểm thử là bị từ chối an toàn.

Dependency bắt buộc: shared customer + rescuer foundation với rescue_requests, assignments, rescue_quotes, customer_profiles, rescuer_profiles, auth.uid và consistency helper. TT được tạo bằng helper riêng không có dynamic SQL, áp dụng cùng quy tắc format của display codes; vì vậy migration không phụ thuộc Admin hoặc helper display-code tổng quát. Đã kiểm thử cả schema có và không có Admin/display codes.

## 2. Tables đã định nghĩa

### public.payments

Đủ các fields yêu cầu: UUID id; payment_code; request/assignment/customer/rescuer/quote IDs; amount_expected/amount_received bigint; currency; method/status/version; cash_received_by/at; paid/verified/failed/cancelled/refunded timestamps; failure_code/cancellation_reason_code; created_at/updated_at.

- `request_id` unique: mỗi request tối đa một payment.
- `payment_code` unique, do server cấp.
- Money bigint, không floating point; expected NOT NULL >=0; received nullable >=0.
- Currency chỉ VND, version >0.
- Method allowlist cash/bank_transfer; status allowlist pending/awaiting_payment/verifying/paid/failed/cancelled/refunded.
- Pending phải chưa có method; cancelled có thể giữ method NULL nếu chưa từng chọn. Các trạng thái còn lại yêu cầu method.
- Timestamp không cho infinity. Failure/reason fields chỉ nhận mã có định dạng giới hạn, không raw thông báo provider.

**Các trạng thái và field được dự trữ cho bước sau, chưa phải flow đã hoạt động.** Core guard hiện chỉ cho privileged setup INSERT payment pending/version=1, chưa có method/received/lifecycle timestamps/reason. UPDATE chỉ cho thao tác không đổi dữ liệu nghiệp vụ; server tự cập nhật updated_at. Mọi đổi method/status/received/version và field lifecycle đều bị chặn với `PAYMENT_MUTATION_NOT_ENABLED` đến khi có migration flow và trusted RPC được review. Không giả định một grant service_role tương lai đã đủ để settlement an toàn.

### public.payment_events

Đủ fields yêu cầu; event_type, actor_type, old/new status có allowlist; amount >=0; payment_version/event_sequence >0; unique(payment_id,event_sequence). Metadata phải JSON object, tối đa 8192 byte dạng text; không dùng metadata làm kho raw payload.

Actor human phải có actor_id; provider/system phải NULL actor_id. Trigger yêu cầu actor human khớp auth.uid; không có callable API nhận actor_id từ client. Setup không có user JWT dùng actor system. Event payment_version phải khớp payment hiện tại; insert khóa row payment để serialize ghi event. Core chưa cấp số event_sequence tự động hoặc tự sinh payment_created: future trusted writer phải cấp sequence và tạo payment/event atomically.

## 3. FK và identity integrity

| Constraint | Quan hệ |
|---|---|
| payments_request_customer_fk | (request_id,customer_id) -> rescue_requests(id,customer_id) |
| payments_assignment_identity_fk | (assignment_id,request_id,rescuer_id) -> rescue_request_assignments(id,request_id,rescuer_id) |
| payments_quote_assignment_fk | (quote_id,assignment_id) -> rescue_quotes(id,assignment_id) |
| payments_customer_id_fkey | customer_id -> auth.users(id) |
| payments_rescuer_id_fkey | rescuer_id -> rescuer_profiles(user_id) |
| payments_cash_received_by_fkey | cash_received_by -> rescuer_profiles(user_id) |
| payment_events_payment_request_fk | (payment_id,request_id) -> payments(id,request_id) |
| payment_events_actor_id_fkey | actor_id -> auth.users(id) |

Tất cả 8 FK validated, immediate, **ON DELETE RESTRICT**. Không CASCADE xóa dữ liệu tài chính. Thêm candidate UNIQUE `rescue_requests_payment_customer_key(id,customer_id)` trên request, và `payments_id_request_key(id,request_id)` để hỗ trợ event FK. Candidate key mới không thay đổi ownership/request data; id vốn đã unique.

Trigger khi INSERT khóa request -> assignment -> quote bằng FOR SHARE và kiểm tra snapshot: request/assignment completed, provider/rescuer khớp, quote là current/completion quote issued, amount_expected và currency khớp quote, quoted_price khớp total_vnd. Identity sai vẫn bị composite FK từ chối, không tự sửa input. Không có fallback dùng quoted_price đơn lẻ cho request legacy thiếu assignment/completion quote. Quote 0 vẫn được phép ở cấu trúc pending vì yêu cầu schema là >=0; chưa quyết định thu/miễn phí 0 trong core.

Xóa auth user/request đang được ledger tham chiếu có thể bị chặn. Quy trình xóa/anonymize tài khoản cần được review trước khi triển khai chức năng đó.

## 4. RLS policies

RLS bật trên **cả payments và payment_events** ngay trong cùng transaction tạo schema; không có thời gian committed với bảng chưa bật RLS.

Payments chỉ có hai policy SELECT cho authenticated:

- `payments_customer_read`: customer_id = (select auth.uid()).
- `payments_rescuer_read`: rescuer_id = (select auth.uid()).

Rescuer identity được composite FK bảo vệ, không cần mở SELECT assignment/quote cho client. Không có USING(true), không có write policy, không có admin role override. Admin dùng JWT authenticated chỉ được xem row nếu bản thân cũng là participant; bước này chưa mở tài chính cho admin.

Payment_events không có policy và không có grant SELECT client. RLS default deny kể cả customer/rescuer có quyền đọc payment tương ứng. Không FORCE RLS cho table owner; owner/superuser/BYPASSRLS là trust boundary quản trị, không phải tài khoản frontend.

## 5. Grants và revokes

| Đối tượng | Quyền được cấp |
|---|---|
| authenticated trên payments | Chỉ SELECT, tiếp tục chịu RLS |
| anon trên payments | Không quyền |
| anon/authenticated trên payment_events | Không quyền, kể cả SELECT |
| service_role trên hai bảng mới | Revoke toàn bộ nếu role tồn tại; chưa mở writer server ở phase này |
| public/anon/authenticated/service_role trên payment_code_seq | Không USAGE/SELECT/UPDATE |
| public/anon/authenticated/service_role trên hai helper mới | Không EXECUTE |

Revoke ALL còn chặn TRUNCATE/REFERENCES/TRIGGER; không chỉ chặn INSERT/UPDATE/DELETE. Kiểm thử mô phỏng default privileges ban đầu rộng cho anon/authenticated/service_role và xác nhận migration đã thu hồi quyền đúng trên objects mới. Không thay default privileges của các bảng khác.

## 6. Immutability và server timestamps

`private.payment_core_guard()` là SECURITY INVOKER, SET search_path='', không dynamic SQL. Không tạo SECURITY DEFINER helper mới.

- Không sửa id, payment_code, request_id, assignment_id, customer_id, rescuer_id, quote_id, amount_expected, currency, created_at sau INSERT.
- Không DELETE payment; trigger statement chặn cả TRUNCATE/CASCADE.
- Các mutation nghiệp vụ chưa triển khai bị chặn, kể cả writer đã có quyền bảng; bước tiếp theo phải thay guard có chủ đích đồng thời với RPC/audit, không thêm bypass bằng JWT claim hoặc custom GUC.
- INSERT ghi đè created_at/updated_at bằng clock_timestamp server. UPDATE no-op bỏ qua updated_at do caller truyền và lấy timestamp server; không tăng version vì không thay nghiệp vụ.

DB owner có quyền ALTER/DROP/disable trigger vẫn có thể thay cơ chế bảo vệ; core không tuyên bố chống được quyền quản trị database toàn phần.

## 7. Event security

`private.payment_event_core_guard()` cũng SECURITY INVOKER, search_path rỗng, revoke EXECUTE. UPDATE/DELETE/TRUNCATE bị từ chối kể cả privileged test setup. Timestamp server ghi đè input. Customer/rescuer/admin JWT không thể ghi event hoặc đọc raw event.

Chưa có sanitized event RPC, admin audit view hay event realtime. Metadata object/size constraint không tự loại bỏ mọi PII/secret; privileged writers ở bước sau phải dùng allowlist và không lưu token/secret/raw provider payload. Không thêm logging endpoint trong bước này.

## 8. Payment code và indexes

`public.payment_code_seq`: bigint, bắt đầu 1, NO CYCLE, chỉ server có quyền dùng. Trigger từ chối mọi payment_code supplied khác NULL kể cả import privileged; không dùng mã client cung cấp.

Format TT- + ít nhất 6 chữ số; lpad dùng `greatest(6,length(value))`, giữ nguyên số 1000000 trở lên. Unique index vẫn từ chối collision nếu sequence bị drift; không âm thầm sửa/reuse mã. Sequence gaps sau rollback là bình thường.

Ba index query ngoài PK/UNIQUE bắt buộc:

- payments(customer_id, created_at DESC, id).
- payments(rescuer_id, created_at DESC, id).
- payments(status, created_at DESC, id).

Không thêm indexes cho bank/refund/admin/realtime chưa triển khai. Event unique(payment_id,event_sequence) đồng thời hỗ trợ đọc lịch sử theo payment trong tương lai.

## 9. Tests đã chạy và kết quả

Docker CLI có nhưng Docker Desktop Linux engine không chạy; không có kết nối Supabase local khả dụng được sử dụng. Đã cài PGlite **0.5.8 / PostgreSQL 18.3** vào cache test `.cache_rescuer/temp/payment-core-security`, dùng database RAM mới mỗi lần, không database URL và không kết nối dự án Supabase.

| Kiểm tra | Kết quả |
|---|---|
| Áp toàn bộ migration shared + admin foundation + display codes + core mới vào RAM | PASS |
| Payment security regression trên full schema | **114 assertions PASS**, chạy lại lần hai PASS |
| Chỉ shared migrations + core, không Admin/display codes | **114 assertions PASS**, chạy lại lần hai PASS |
| Test suite thiếu local opt-in | Bị từ chối đúng guard — PASS |
| Fixtures/users/payment/events sau ROLLBACK | Không còn — PASS |
| Rerun migration core | Bị từ chối PAYMENT_CORE_ALREADY_EXISTS — PASS |
| Existing rescuer_local_regression.sql trên shared-schema contract của nó sau core | PASS |

114 assertions bao gồm đủ 19 tình huống bắt buộc: customer/rescuer đúng chủ được đọc; đọc chéo bị lọc; unrelated/anon bị chặn; client payment/event DML bị chặn; sửa amount/identity/status bị chặn; composite FK payment và event mismatch bị từ chối; duplicate request và generated payment_code bị unique constraint từ chối.

Kiểm tra bổ sung gồm broad SELECT không leak, customer B/rescuer B, JWT metadata tự nhận admin/service_role không nâng quyền SQL role, missing UID, admin không có override, row_security=off không bypass, helper/sequence ACL, privileged immutability, TRUNCATE, server timestamps, snapshot giá khác quote, incomplete request, actor/version/metadata event, mã vượt 999999, default privileges rộng, không publication và không public payment mutation RPC.

Một lần chạy thử suite rescuer cũ trên full schema báo `TEST_FAIL: discovery privacy`: test cũ đếm đúng 5 field, trong khi display-code migration thêm request_code thành 6. Không sửa test/DTO rescuer ngoài phạm vi. Final full-schema payment run không chạy assertion legacy này; suite rescuer được chạy và PASS trên shared-schema contract của chính nó. Đây không phải một payment core assertion thất bại.

Một lỗi kỳ vọng trong payment test ban đầu đã sửa: PostgreSQL trả SQLSTATE **23001** cho parent DELETE bị ON DELETE RESTRICT chặn, khác 23503 dùng cho FK identity mismatch. Kết quả cuối cùng là PASS nêu trên.

## 10. Tests chưa chạy và cách chạy lại

**Chưa integration test Supabase stack thật:** Auth JWT validation, PostgREST HTTP/RLS, local Docker PostgreSQL, Realtime, nhiều connection/concurrency, môi trường dev/production. PGlite thực thi PostgreSQL/PLpgSQL/RLS/ACL/constraints, nhưng auth.uid và Auth/Storage schemas được mô phỏng; kết quả không chứng minh toàn bộ gateway/session behavior thật.

Regression SQL có fixture setup và DML negative tests trong transaction rồi ROLLBACK; không phải transaction SQL READ ONLY. Điều này phục vụ các case ghi bị từ chối theo yêu cầu. Chỉ dùng database **local disposable**, privileged connection; không nới client grant để tạo fixture. Sequence advance không rollback, nên tuyệt đối không chạy test trên dữ liệu vận hành. Local opt-in là chốt chống chạy nhầm, không tự chứng minh host là local.

Trong psql của database disposable đã được xác minh và áp migrations:

```sql
\set ON_ERROR_STOP on
SET payment.test_mode = 'local_disposable';
\i backend/supabase/tests/payment_core_security_regression.sql
```

Cache runner dùng trong lần này (không phải dependency ứng dụng hoặc deliverable deployment):

```powershell
node .cache_rescuer/temp/payment-core-security/run_payment_core.mjs
node .cache_rescuer/temp/payment-core-security/run_payment_core.mjs --shared-only
```

## 11. Security risks và giới hạn còn lại

1. Bảng hiện chỉ usable cho participant SELECT và privileged pending fixtures; chưa có mutation RPC/writer/audit tự động. Client chưa có cách tạo payment là có chủ đích.
2. Chưa có settlement constraints/evidence cho bank, refund hoặc atomic paid+event vì các flow chưa triển khai. Phase guard chặn khởi tạo/chuyển sang các state đó; không bỏ guard trước khi có thiết kế writer đầy đủ.
3. Owner/superuser/role có quyền thay DDL nằm ngoài bảo vệ client; giữ credential quản trị khỏi frontend. service_role hiện cũng không được cấp table access trên objects mới.
4. `private` phải tiếp tục không nằm trong exposed schemas. Helpers hiện invoker/revoked ngay cả khi cấu hình exposed schemas sai, nhưng vẫn cần kiểm deployment settings trước rollout.
5. Snapshot validated lúc insert và identity được FK bảo vệ; privileged thay đổi khác trên shared parent objects vẫn thuộc trust boundary. Không sửa state machine/quote schema hiện có trong phase này.
6. Migration thêm candidate key có thể cần lock/index build trên request table lớn; timeout giúp fail closed, cần đánh giá dữ liệu và maintenance window trước lần áp môi trường thật.
7. Metadata không có secret scanner; future writer phải sanitized. Không mở direct SELECT raw events để tiện debug frontend/admin.

## 12. Bước tiếp theo đề xuất

Trước khi triển khai môi trường thật: xác minh migration history/schema và auth/exposed schema settings; chạy suite trên Supabase local disposable với gateway JWT/PostgREST thật. Sau khi được giao giai đoạn tiếp theo mới thêm trusted prepare/method/cash RPC, cùng idempotency, state validation, atomic event và thay phase guard tương ứng.

Chưa làm customer_prepare_payment, customer_select_payment_method, rescuer_confirm_cash_received; chưa làm bank intent/QR/webhook/provider transaction/secrets; chưa làm settings/realtime/refund/split payment hoặc UI. Không deploy. Không commit.
