# GD2A — Customer prepare/get payment

Ngày thực hiện: 2026-10-10. Chỉ tạo migration, regression SQL và báo cáo; chưa áp dụng lên Supabase thật, chưa deploy, chưa commit.

## 1. Files và RPC signatures

- Migration: [`202610100002_payment_customer_prepare.sql`](../backend/supabase/migrations/202610100002_payment_customer_prepare.sql).
- Regression: [`payment_customer_prepare_regression.sql`](../backend/supabase/tests/payment_customer_prepare_regression.sql).
- Đối chiếu: [`payment_backend_plan.md`](payment_backend_plan.md), [`payment_core_security_implementation.md`](payment_core_security_implementation.md), GD1 `202610100001_payment_core_security.sql`, customer request RPCs và rescuer foundation/completion/quote contract.

```sql
public.customer_prepare_payment(p_request_id uuid) returns jsonb
public.customer_get_payment(p_request_id uuid) returns jsonb
```

Chỉ hai RPC mới; không tạo bảng, overload, helper permanent hoặc operation receipt. Getter là `STABLE`; prepare mặc định `VOLATILE`. Cả hai `SECURITY DEFINER SET search_path = ''`, schema qualify các object, không dynamic SQL.

Migration chạy trong transaction, có preflight prerequisites/RLS/grants/guard triggers và từ chối nếu RPC cùng tên đã tồn tại, thay vì overwrite. Không sửa migration, trigger hoặc bảng của GD1.

## 2. Authentication và ownership

`auth.uid()` là principal duy nhất. Kiểm tra NULL trước khi truy vấn request/payment. Không nhận identity, amount, status, code hay actor từ caller; không đọc user metadata để cấp quyền.

Prepare chỉ khóa request thỏa đồng thời `id = p_request_id` và `customer_id = auth.uid()`. Getter kiểm tra cùng ownership trước khi đọc payment, đồng thời lọc lại `payments.customer_id = auth.uid()`.

Request của người khác, UUID không tồn tại hoặc NULL đều nhận `PAYMENT_NOT_ACCESSIBLE`; không trả owner thật, rescuer, assignment, quote hay thông tin payment có tồn tại hay không. Rescuer dù được phân assignment vẫn không thể dùng hai customer RPC cho request của khách.

| Tình huống | message | SQLSTATE |
|---|---|---|
| Principal NULL trong role có quyền execute | `AUTHENTICATION_REQUIRED` | `42501` |
| Không sở hữu/không tồn tại/NULL request | `PAYMENT_NOT_ACCESSIBLE` | `42501` |
| Request/assignment chưa đủ điều kiện | `PAYMENT_NOT_ELIGIBLE` | `P0001` |
| Completion quote/snapshot không nhất quán | `QUOTE_SNAPSHOT_INCONSISTENT` | `P0001` |
| Completion quote bằng 0 | `ZERO_AMOUNT_REQUIRES_POLICY` | `P0001` |

Theo convention RPC hiện hữu, lỗi dùng `RAISE EXCEPTION` với message ổn định và SQLSTATE; không thêm frontend wrapper. `anon` bị ACL chặn trước khi vào function, nên nhận permission denied thay vì message authentication bên trong. Constraint failure bất ngờ trong khối ghi payment/event được đổi thành `QUOTE_SNAPSHOT_INCONSISTENT`, không trả constraint name/row detail. Không blanket-catch lỗi vận hành như timeout hoặc serialization failure thành một lần thành công.

## 3. Điều kiện tạo payment mới

1. Request thuộc caller và `status = 'completed'`; không đổi trạng thái request.
2. Assignment được lấy bằng request ID trên server; schema hiện có `UNIQUE(request_id)` nên không chọn tùy ý giữa nhiều assignment.
3. Assignment phải `completed`, đúng request, `rescuer_id = request.provider_id`, có `completion_quote_id`.
4. Quote tồn tại, đúng `completion_quote_id`, assignment, request, rescuer; `current_quote_id = completion_quote_id`; status `issued`, currency `VND`, total không NULL và không âm.
5. `request.quoted_price = quote.total_vnd` theo consistency contract hiện hữu.
6. Quote total bằng 0 bị từ chối; không tạo free/paid payment.

Missing assignment, chưa completed, sai provider hoặc thiếu completion quote trả `PAYMENT_NOT_ELIGIBLE`. Quote thiếu/sai identity, superseded, khác current quote hoặc sai amount trả `QUOTE_SNAPSHOT_INCONSISTENT`.

Contract này dựa trên completion RPC hiện tại: dùng current issued quote, chốt vào completion_quote_id, chuyển assignment/request completed và lưu quoted_price. GD2A không thay status machine hoặc quote revision rules.

## 4. Amount snapshot và DTO

Nguồn duy nhất cho số tiền là `rescue_quotes.total_vnd` của `assignment.completion_quote_id` đã được kiểm tra. `request.quoted_price` chỉ là kiểm tra nhất quán, không phải fallback. Không lấy giá UI, base price hoặc quote do client chỉ định.

Insert lấy customer từ request, rescuer từ assignment, các FK từ server, amount cast sang bigint. Giá trị khởi tạo là `currency='VND'`, `status='pending'`, `method=NULL`, `version=1`. Received amount và mọi lifecycle timestamp/actor giữ NULL. GD1 trigger cấp TT code/server timestamps, kiểm tra snapshot và bảo vệ immutable fields.

DTO có đúng 15 keys:

```text
payment_id, payment_code, request_id, assignment_id, quote_id,
amount_expected, amount_received, currency, method, status, version,
created_at, updated_at, paid_at, cash_received_at
```

UUID/code/status/currency là JSON string; timestamps là JSON timestamptz strings, nullable timestamps giữ JSON null. Amounts và version được serialize thành **decimal string** để giữ nguyên bigint khi qua JSON/JavaScript; amount_received chưa có là null, không phải chuỗi `"null"`. Đây là contract cần giữ khi tích hợp client về sau.

Không trả customer_id/rescuer_id trong RPC DTO, raw events, metadata, operation receipt, provider payload hoặc secret. GD1 direct SELECT của participant vẫn theo contract cũ; DTO không thay đổi quyền đọc bảng hiện có.

## 5. Concurrency và idempotency

Prepare khóa owned request `FOR UPDATE` trước khi kiểm payment. Đường tạo mới tiếp tục khóa assignment `FOR UPDATE`, completion quote `FOR SHARE`; insert event dùng guard GD1 khóa payment.

Hai prepare trên cùng request ở `READ COMMITTED` phải tuần tự hóa tại parent lock. Sau khi transaction thứ nhất commit, lần sau thấy payment hiện hữu. `UNIQUE(payments.request_id)` là bảo vệ bổ sung; `INSERT ... ON CONFLICT (request_id) DO NOTHING` xử lý writer trusted cạnh tranh và chỉ trả row đúng customer. Không nuốt unique violation khác thành retry thành công.

Không cần operation_id/receipt vì request là idempotency identity, payment và event cùng transaction. Sequence có thể nhảy số sau rollback/conflict; không yêu cầu TT liên tục không có gap. Ở isolation cao hơn, serialization error vẫn yêu cầu retry transaction; không được xem là duplicate thành công.

**Chưa chạy concurrency thật hai connection.** PGlite là một session, hai process kiểm thử dùng hai database RAM độc lập; không phải concurrency test trên cùng database.

Kịch bản cần chạy tiếp trên DB local native: tạo và commit một fixture completed chưa có payment; connection A/B dùng role authenticated và cùng JWT customer; A gọi prepare nhưng giữ transaction, B gọi cùng request và phải đợi; commit A rồi B phải trả cùng payment ID. Xác nhận count payment = 1, count payment_created = 1, DTO/version không reset. Chạy thêm biến thể rollback A rồi B tạo thành công. Không dùng regression rollback-only hiện tại làm fixture chia sẻ giữa hai connection.

## 6. Existing payment và getter

Sau authentication/ownership và request lock, nếu đã có payment thì prepare trả getter ngay, trước điều kiện **tạo mới**. Không insert, update, reset method/status/amount/version/timestamps hoặc ghi event lần hai. Cách này giữ snapshot lịch sử kể cả khi các phase sau thêm trạng thái paid/failed/cancelled.

GD1 hiện chặn mọi state mutation; regression kiểm chứng retry pending không đổi cả DTO/timestamps và event count. Chưa dựng paid fixture bằng cách vô hiệu hóa guard để giả lập phase chưa triển khai.

Getter không khóa để mutation và không tạo payment. Owned request chưa có payment trả SQL NULL, dự kiến PostgREST biểu diễn JSON null; HTTP shape chưa integration test qua PostgREST.

## 7. Event và tính nguyên tử

Chỉ nhánh INSERT thành công ghi đúng một `payment_created`:

- `actor_type='customer'`, `actor_id=auth.uid()`.
- `old_status=NULL`, `new_status='pending'`.
- `amount=amount_expected`, payment/request IDs từ row vừa tạo.
- `payment_version=payments.version`, `event_sequence=1`.
- Metadata mặc định `{}`, operation_id NULL, timestamp từ GD1 server trigger.

Payment và event cùng transaction/subtransaction. Nếu audit insert lỗi, payment insert rollback; test ép lỗi CHECK trên audit xác nhận không còn cả hai row và retry sau khi bỏ lỗi tạo được đúng một event. Không mở quyền ghi event cho client.

## 8. RLS, grants và immutability

Không sửa RLS/grants trên payments, payment_events, sequence hoặc GD1 helpers. Payments vẫn chỉ SELECT participant theo ownership/assignment snapshot; client không INSERT/UPDATE/DELETE/TRUNCATE. Events không mở raw SELECT hoặc DML, kể cả cho admin trong bước này.

Revoke EXECUTE hai RPC khỏi PUBLIC, anon, authenticated trước khi grant lại đúng authenticated; nếu service_role tồn tại cũng revoke EXECUTE được thừa hưởng từ default privileges. Không thêm bank/server endpoint. Owner triển khai vẫn là trust boundary của SECURITY DEFINER; cần migration owner đáng tin có quyền các bảng/sequence tương ứng.

GD1 immutable snapshot/event guards không đổi. Kiểm thử có permissive default function grants cho anon/authenticated/service_role để xác nhận revoke vẫn có hiệu lực. Checksum toàn bộ frontend/admin và files GD1/plan/report gốc trước/sau GD2A khớp; các frontend diff có sẵn trong workspace không thuộc lần triển khai này.

## 9. Kết quả tests

Engine: **PGlite 0.5.8 / PostgreSQL 18.3**, database RAM mới, auth/storage/roles được mô phỏng để chạy migrations repository. Không kết nối database URL hay server từ xa.

| Kiểm tra | Kết quả |
|---|---|
| GD1 regression trước khi thêm GD2A | 114 assertions PASS trên mỗi schema |
| Apply GD2A trên shared + admin/display codes | PASS |
| GD2A regression trên shared + admin/display codes, chạy hai lần | 72/72 PASS mỗi lần, 0 FAIL |
| Apply GD2A trên shared-only | PASS |
| GD2A regression shared-only, chạy hai lần | 72/72 PASS mỗi lần, 0 FAIL |
| Không có local opt-in | Suite từ chối đúng |
| Rollback fixture và chạy lại khi sequence đã tăng | PASS |
| GD1 guard definitions/ACL trước và sau GD2A | Không đổi |
| Chạy lại migration GD2A | Từ chối overwrite đúng |

72 assertions bao phủ success pending/method NULL/amount/identity/quote/TT/event; getter/retry; customer khác khi payment chưa có và đã có; unrelated/rescuer/anon/NULL principal; missing/NULL UUID; searching/accepted/arriving/in_progress; completed thiếu assignment hoặc assignment chưa completed; sai provider; completion quote thiếu/sai assignment/superseded/khác current/amount mismatch; zero amount; direct DML/audit/sequence denial; exact DTO; participant RLS; atomic rollback và phục hồi sau lỗi audit; immutability vẫn chặn privileged write.

Các fixture trạng thái sai được tạo bằng privileged test setup trong subtransaction rồi rollback. Với thiếu completion quote, test tạm drop đúng CHECK; với quote sai assignment, tạm defer composite FK; thay đổi constraint tự rollback, không disable trigger. Cuối suite ép kiểm tra deferred constraints và xác nhận CHECK/FK đã phục hồi. Đây chỉ là fault injection để kiểm tra RPC phòng thủ, không thay migration hoặc cho phép client tạo trạng thái sai.

File SQL portable cho disposable PostgreSQL/Supabase local có đủ prerequisites. Cần explicit `SET payment.test_mode='local_disposable'` trên **cùng connection**, chạy privileged setup, `psql -X -v ON_ERROR_STOP=1`; suite tự chuyển role kiểm client và cuối cùng ROLLBACK. Sequence increments không rollback, vì vậy không chạy suite trên database thật. Harness RAM dùng trong phiên nằm ở cache ignored `.cache_rescuer/temp/payment-core-security/run_payment_prepare.mjs`.

GD1 suite có assertion chưa tồn tại prepare RPC, nên chỉ chạy nguyên bản **trước GD2A**; sau GD2A, suite mới kiểm lại các invariant RLS/ACL/immutability phù hợp. Không sửa suite GD1 để đổi lịch sử.

## 10. Những kiểm thử chưa chạy

- Supabase local native/Docker và PostgREST/Auth HTTP integration: chưa chạy. Docker daemon không khả dụng; postgres/pg_ctl/initdb không có trong PATH.
- Concurrency hai connection cùng database: chưa chạy; không tính PASS.
- Supabase production/staging thật: chưa chạy SQL hoặc deploy.
- Lock timeout/deadlock/serialization dưới tải và JWT expired/signature qua API gateway: chưa integration test.

## 11. Phần chưa triển khai

Không sửa GD1 hoặc frontend/customer_app, frontend/rescuer_app, admin_web. Không tạo customer_select_payment_method, cash confirmation, rescuer mutation, realtime, UI, admin payment module, QR/bank intent/provider/webhook, refund, settings hay secrets. Không set cash/awaiting_payment/paid. Không commit hoặc deploy.

## 12. Security risks và giới hạn còn lại

- SECURITY DEFINER phụ thuộc migration owner/schema/ACL đáng tin và auth.uid do gateway xác thực; không bảo vệ trước superuser hoặc role có thể tự DDL/giả JWT claims bằng SQL trực tiếp. Test SET ROLE/claims chỉ dùng trong privileged local setup.
- Cần chạy native DB/PostgREST và concurrency trước khi triển khai thực tế; PGlite xác minh PostgreSQL logic/constraints/RLS nhưng không mô phỏng toàn bộ Supabase vận hành.
- Future payment writer phải giữ thứ tự lock, ownership, snapshot immutable và atomic audit. Không được thêm direct client DML để mở flow.
- Zero amount cố ý từ chối cho tới khi có policy được duyệt. Hỏng consistency không fallback sang quoted_price/UI; cần điều tra và xử lý bằng quy trình riêng.
- Chưa có rate-limit payment riêng; repeated authorized prepare có thể tranh parent lock. Không tự thêm settings/rate-limit infrastructure trong GD2A.
- Không log token, secret hoặc provider data; events mới chỉ chứa dữ liệu tối thiểu đã nêu.

## 13. Bước tiếp theo

Kiểm thử trên Supabase local native, đặc biệt HTTP DTO/error/ACL và hai connection; review migration trước khi người dùng yêu cầu triển khai vào môi trường cụ thể. Sau đó mới xem xét phase chọn payment method với business rules/grants/transition được duyệt riêng. Chưa triển khai bước tiếp theo trong GD2A.
