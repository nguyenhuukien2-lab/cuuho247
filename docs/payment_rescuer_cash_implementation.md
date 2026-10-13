# GD3 — Rescuer đọc payment và xác nhận đã thu CASH

Ngày: 2026-10-10. Đã tạo migration và regression SQL, thực thi trên PostgreSQL PGlite cô lập trong RAM. **Chưa deploy hoặc chạy migration trên Supabase thật. Không commit.**

Nguồn đối chiếu: [payment_backend_plan.md](payment_backend_plan.md), [GD1](payment_core_security_implementation.md), [GD2A](payment_customer_prepare_implementation.md), [GD2B](payment_customer_select_cash_implementation.md), các migration customer/rescuer foundation, approval/assignment/quote/receipt/RLS contract hiện tại.

## 1. Files và RPC signatures

- Migration: [202610100004_payment_rescuer_cash.sql](../backend/supabase/migrations/202610100004_payment_rescuer_cash.sql).
- Tests: [payment_rescuer_cash_regression.sql](../backend/supabase/tests/payment_rescuer_cash_regression.sql).
- Report: `docs/payment_rescuer_cash_implementation.md`.

```sql
public.rescuer_get_job_payment(p_request_id uuid) returns jsonb

public.rescuer_confirm_cash_received(
  p_request_id uuid,
  p_payment_id uuid,
  p_amount_received bigint,
  p_expected_version bigint,
  p_operation_id uuid
) returns jsonb
```

Đúng hai public RPC mới, không overload. Getter `STABLE`; confirm `VOLATILE`. Cả hai `SECURITY DEFINER SET search_path=''`, schema qualify objects, không dynamic SQL. Không nhận actor/customer/assignment/quote, expected amount, status hoặc timestamp từ frontend.

Getter trả DTO đúng 15 keys, tương thích cách serialize GD2A:

```text
payment_id, payment_code, request_id, assignment_id, quote_id,
amount_expected, amount_received, currency, method, status, version,
created_at, updated_at, paid_at, cash_received_at
```

Amounts và version là decimal strings để không mất bigint qua JavaScript; nullable fields là JSON null. Không trả customer identity, raw events/metadata, receipt, payload hash, secret hoặc provider payload. Chưa thêm allowed_actions. Confirm trả `{"payment": <current DTO>, "changed": true|false}`.

Migration có transaction, lock timeout 5 giây, statement timeout 60 giây; preflight dependencies, RLS/grants/guards; từ chối overwrite RPC đã có. Không backfill payment hoặc suy paid từ completed.

## 2. Authentication và ownership

`auth.uid()` là principal duy nhất; NULL trả `AUTHENTICATION_REQUIRED` ngay. Không dùng role tự khai trong user metadata.

Getter join payment với đúng assignment ID, request ID và rescuer; đồng thời payment.request_id = input và payment.rescuer_id = caller. Không có payment phù hợp, UUID không tồn tại, NULL hoặc payment của người khác đều trả `PAYMENT_NOT_ACCESSIBLE`. Không phân biệt existence cho caller không được quyền. Không yêu cầu approved, active job, online hoặc GPS để đọc lịch sử.

Confirm chỉ khóa request nếu tồn tại payment/assignment cùng request, đúng payment ID và cùng caller. Sau request lock, khóa assignment của caller rồi payment; kiểm lại payment.assignment_id = assignment.id. Ownership hoàn tất **trước receipt lookup**, kể cả exact retry. Không trả receipt hay lỗi payload conflict cho resource ngoài quyền.

Customer và rescuer dùng chung PostgreSQL role `authenticated` theo contract repo; không có DB role customer riêng để phân quyền EXECUTE theo user ID. Grant đúng signature cho authenticated là cửa vào; customer principal không sở hữu assignment bị `PAYMENT_NOT_ACCESSIBLE` trước mutation/replay. Không tạo customer mark-paid RPC. User đồng thời có approved rescuer profile chỉ được confirm trong tư cách rescuer của chính assignment đó.

## 3. Completed, payment state và approval

Confirmation mới yêu cầu request.status = completed, assignment.state = completed, request.provider_id = caller; payment.method = cash và payment.status = awaiting_payment. Không sửa request, assignment hoặc quote. Không dùng `private.rescuer_lock_job()` vì helper đó từ chối completed. Job mới, offline và thiếu GPS không chặn thu payment của job cũ.

Reuse `private.rescuer_require_profile(true)` sau receipt check: suspended trả `PROFILE_SUSPENDED`; draft/submitted/rejected trả `PROFILE_NOT_READY`. Profile được khóa trước parent/payment để approval không đổi giữa kiểm tra và commit.

Exact retry đã commit vẫn đọc payment hiện tại khi rescuer vừa bị suspended; không thực hiện thu tiền mới. New-key no-op vẫn yêu cầu approved. Các trạng thái pending, verifying, failed, cancelled không được thu. Refunded hoặc paid không khớp CASH/cùng actor/cùng amount trả `PAYMENT_ALREADY_SETTLED`; không overwrite bank thành cash.

## 4. Amount và version

Expected chỉ lấy từ `payments.amount_expected`, là completion-quote snapshot đã tạo qua GD2A. Không tính lại từ UI hoặc báo giá mới. Received phải bằng expected; NULL, âm, thiếu hoặc thừa trả `PAYMENT_AMOUNT_MISMATCH`. Không partial/tip/split/change/override. Zero amount trả `ZERO_AMOUNT_REQUIRES_POLICY`, giữ policy GD2A/GD2B.

Signature bigint từ chối overflow và chuỗi không hợp lệ ở bước PostgreSQL convert input. SQL regression kiểm overflow, bad type và fractional string; chưa kiểm toàn bộ coercion JSON qua PostgREST HTTP. Client sau này cần gửi số nguyên dạng decimal string theo contract, không tự cast/round numeric phân số trước RPC.

Expected version NULL/<=0 trả `INVALID_EXPECTED_VERSION`; khác version hiện tại trả `VERSION_CONFLICT`. Version cực đại bigint bị từ chối trước phép cộng. Exact receipt replay đi trước các kiểm tra này; hash chứa **expected version gốc** nên retry phải giữ nguyên payload.

## 5. Idempotency và operation receipt

Reuse nguyên `private.rescuer_rpc_receipts`, `private.rescuer_begin_operation` và `private.rescuer_commit_receipt`; không thêm/sửa bảng receipt hoặc helper cũ. Mapping:

| Field hiện có | Giá trị GD3 |
|---|---|
| rescuer_id | actor_id = auth.uid() |
| operation_id | UUID input, bắt buộc |
| operation_name | rescuer_confirm_cash_received |
| payload_hash | SHA-256 UTF8 canonical JSON `[operation_name, [request_id, payment_id, amount_received, expected_version]]` |
| resource_id | payment.id đã authorize/khóa |
| committed_at | clock_timestamp default server khi ghi receipt |

PK `(rescuer_id,operation_id)` dùng chung namespace với rescuer RPC cũ: trùng key của operation khác cũng `IDEMPOTENCY_CONFLICT`. Receipt resource ID được so lại trước replay. `committed_at` là thời điểm ghi trong transaction, không phải PostgreSQL commit timestamp; receipt chỉ tồn tại bền vững nếu transaction commit.

| Tình huống | Kết quả |
|---|---|
| Key mới, cash/awaiting, đúng amount/version/approval | Paid, version +1, một event, một receipt; changed=true |
| Cùng actor/key/payload đã commit | Current authorized DTO, changed=false; không UPDATE/event/receipt mới |
| Cùng actor/key, payload hoặc operation khác | IDEMPOTENCY_CONFLICT sau ownership check |
| Key mới, đã cash-paid cùng actor/amount, current version | Approved + completed vẫn bắt buộc; changed=false, ghi operation receipt cho key mới; không settlement/event mới |
| Key mới, đã cash-paid nhưng version cũ | VERSION_CONFLICT |
| Key mới, đã paid bằng bank hoặc sai actor/amount | PAYMENT_ALREADY_SETTLED |
| Actor khác dùng lại cùng key | Namespace độc lập, vẫn phải sở hữu payment/assignment |
| Event/receipt lỗi trước commit | Rollback toàn bộ; key chưa bị tiêu thụ, có thể retry nguyên payload |

New-key no-op receipt là dấu vết operation, không phải lần thu tiền thứ hai. Exact retry trả **current payment**, khác GD2B customer receipt trả DTO lịch sử. Nếu phase tương lai có refund, retry không tự phục hồi paid; getter/replay phản ánh state hiện tại trong quyền truy cập.

## 6. Lock order

```text
advisory hash('rescuer:' + auth.uid())
  -> rescuer_profiles FOR UPDATE
  -> rescue_requests FOR UPDATE
  -> rescue_request_assignments FOR UPDATE
  -> payments FOR UPDATE
  -> event/receipt
```

Namespace giống rescuer foundation. Để ownership đi trước receipt, GD3 lấy advisory/profile locks trước; gọi begin_operation sau khóa payment chỉ tái lấy đúng locks đã giữ, không tạo profile lock theo thứ tự ngược. Getter không khóa mutation. Event guard khóa lại payment đã giữ. Không lấy quote/profile lock mới sau payment, không HTTP/network trong transaction.

GD2A/GD2B customer flow giữ request trước payment và không lấy rescuer profile sau đó; không tạo vòng khóa mới với GD3. READ COMMITTED tuần tự hóa các confirm cùng payment; isolation cao hơn, deadlock hoặc timeout vẫn cần retry cả transaction với key/payload cũ.

## 7. Payment mutation và server timestamp

Trong một transaction: status = paid; amount_received = amount_expected; cash_received_by = auth.uid(); cash_received_at/paid_at/updated_at cùng timestamp server; verified_at = NULL; version +1. Mọi identity, payment_code, amount_expected, currency, created_at và field ngoài danh sách được giữ nguyên.

**Thay đổi guard cần thiết, chỉ nằm trong migration mới:** `private.payment_core_guard()` giữ nguyên INSERT pending, generator TT, snapshot/FK behavior, DELETE/TRUNCATE denial và transition chọn CASH của GD2B. Mở thêm đúng cash/awaiting -> cash/paid, kiểm actor/approved/completed/amount/version và so sánh toàn row ngoài allowlist. Lifecycle thu tiền cũ phải NULL. Không GUC/JWT bypass flag.

Row guard chốt một `v_now=clock_timestamp()` authoritative rồi ghi đè ba timestamps bằng cùng giá trị, kể cả privileged writer truyền timestamp khác. RPC lấy lại cash_received_at qua UPDATE RETURNING, dùng cho event. Không trust frontend timestamp.

Không sửa file migration GD1/GD2A/GD2B đã có. Khi migration GD3 được áp dụng, định nghĩa database core/event guard sẽ được nâng cấp có chủ đích. Public RPC và ACL của GD2A/GD2B giữ nguyên.

## 8. Event mutation và atomicity

Effective settlement ghi đúng một `cash_received`: actor_type rescuer, actor_id caller, old_status awaiting_payment, new_status paid, amount expected, operation_id input, payment_version mới. Event_sequence = max +1 dưới payment row lock; metadata chỉ `{}`.

`private.payment_event_core_guard()` giữ immutability, actor/version checks cũ; nhánh cash_received kiểm event khớp paid CASH row/actor/amount/request/status/operation rồi lấy created_at từ server cash_received_at. Nhánh event khác vẫn dùng clock_timestamp như GD1. Partial unique index `(payment_id) WHERE event_type='cash_received'` chặn event thu CASH lần hai.

Payment UPDATE, event INSERT và receipt INSERT trong cùng mutation block/transaction. Constraint failure rollback cả ba và trả `PAYMENT_STATE_CONFLICT`, không lộ raw row/constraint detail. Exact retry và new-key no-op không UPDATE payment hoặc ghi event.

## 9. RLS và grants

Không thay payment participant SELECT policies; không thêm UPDATE policy, table DML grant hoặc raw event SELECT. Receipts vẫn private/RLS default deny; không thêm helper public.

Hai RPC revoke EXECUTE PUBLIC/anon/authenticated trước khi grant đúng authenticated signature. Revoke service_role trên hai RPC và guards nâng cấp nếu role tồn tại. Guards vẫn SECURITY INVOKER, search_path rỗng, không client EXECUTE. `private` phải tiếp tục không nằm trong exposed schemas.

Không mở admin override, bank writer, sequence access hoặc realtime publication. Anon bị EXECUTE ACL từ chối trước function; authenticated thiếu principal nhận `AUTHENTICATION_REQUIRED`.

## 10. Tests và kết quả

Engine thực thi: **PGlite 0.5.8 / PostgreSQL 18.3**, database RAM mới; auth.uid/Auth/Storage/roles mô phỏng để chạy repository migrations. Không dùng Supabase URL hoặc database vận hành.

| Kiểm tra | Kết quả |
|---|---|
| GD2B regression nguyên bản trước GD3 | 91/91 PASS trên mỗi cấu hình schema |
| Apply GD3 shared + Admin/display codes | PASS |
| GD3 regression full schema, hai lần | **122/122 PASS mỗi lần, 0 FAIL** |
| Apply GD3 shared-only, không Admin/display codes | PASS |
| GD3 regression shared-only, hai lần | **122/122 PASS mỗi lần, 0 FAIL** |
| Retry trong transaction mới sau commit trong RAM | **5/5 PASS mỗi cấu hình**: changed=false, paid, version giữ nguyên, một event, một receipt cho key gốc |
| Public GD2A/GD2B function definitions + ACL trước/sau GD3 | Không đổi |
| Missing local opt-in / migration rerun | Đều bị từ chối đúng |
| Fixture/receipt rollback và repeat suite | PASS |

122 assertions bao phủ 44 nhóm tình huống yêu cầu; bổ sung exact DTO, NULL args, approval các trạng thái, replay sau suspended, operation namespace cũ, current DTO replay, new-key no-op receipt conflict, zero/max version, new active job independence, nguyên row request/assignment không đổi, atomic rollback và retry sau lỗi event/receipt, RLS/grants/service_role, privileged guard và unique event defense.

Lần chạy thử đầu có lỗi fixture PostgreSQL `55006`: không thể ENABLE request trigger khi deferred trigger events đang pending. Đã sửa fixture: request-only transition trigger được rollback cùng subtransaction; payment guards luôn bật khi gọi RPC. Kết quả bảng trên là các lần chạy cuối sau sửa.

Synthetic invalid states chỉ được dựng bằng privileged test setup trong subtransaction có rollback. Với state payment chưa được API hỗ trợ, tạm disable **payment_core_guard** để dựng fixture, bật lại trước gọi RPC dưới role authenticated. Test request chưa completed tạm disable request transition trigger và defer consistency checks; rollback phục hồi trigger/data trước test tiếp theo. Không nới RLS hoặc client grants. Cuối suite kiểm guards phục hồi và ép deferred constraints immediate.

Regression SQL có local opt-in và kết thúc ROLLBACK; sequence increments không rollback. Chỉ chạy trên database disposable đã xác minh, bằng privileged connection:

```sql
-- psql -X -v ON_ERROR_STOP=1; cùng connection, sau toàn bộ prerequisites + GD3.
SET payment.test_mode='local_disposable';
\i backend/supabase/tests/payment_rescuer_cash_regression.sql
```

Harness cache ignored dùng trong phiên: `.cache_rescuer/temp/payment-core-security/run_payment_rescuer_cash.mjs`, chạy mặc định full schema hoặc thêm `--shared-only`. Post-commit test chỉ đổi terminal ROLLBACK thành COMMIT trong bản SQL RAM, sau đó mở transaction mới và đóng/hủy database RAM. File SQL giao trong repo vẫn rollback-only. Mô phỏng response bị mất sau commit, chưa mô phỏng HTTP network failure thật.

Suite GD2B nguyên bản có assertion chưa tồn tại rescuer payment RPC, nên chạy trước GD3. Suite mới kiểm customer getter/prepare/select và invariants sau GD3; không sửa test cũ để thay lịch sử.

## 11. Concurrency

**Chưa chạy hai connection thật trên cùng database.** Docker CLI có nhưng Docker Desktop Linux engine không hoạt động (`dockerDesktopLinuxEngine` pipe không tồn tại); không có native psql/postgres trong PATH. PGlite là single session, hai cấu hình RAM độc lập không được tính là concurrency.

Kịch bản cần chạy trên PostgreSQL/Supabase local disposable có hai connections, fixture cash/awaiting đã commit, cùng approved rescuer:

1. A BEGIN, confirm key K/version N, giữ transaction. B BEGIN, confirm cùng K/payload; B đợi advisory/profile lock. COMMIT A; B trả paid/current DTO, changed=false. Tổng một settlement/event/receipt K; version N+1.
2. A và B dùng K1/K2 nhưng cùng version N. Sau A commit, B nhận VERSION_CONFLICT; không event/receipt K2. B refresh version N+1 rồi retry K2 với payload chưa từng commit: no-op, thêm operation receipt, không event.
3. A rollback khi B đang đợi: B được thực hiện settlement duy nhất. Không còn event/receipt dở dang của A.
4. Cùng actor/key nhưng hai owned payments: chỉ operation đầu được commit; operation còn lại IDEMPOTENCY_CONFLICT, payment thứ hai không đổi.
5. Approval suspend đồng thời: profile lock quyết định thứ tự; suspension commit trước thì confirm mới bị chặn; settlement commit trước thì exact retry vẫn được trả.

Không tuyên bố các race này đã được thực nghiệm. Chưa integration test Supabase Auth/JWT/PostgREST HTTP, lock contention hoặc load.

## 12. Security risks còn lại

- Backend xác thực **lời xác nhận đã thu của đúng rescuer**, không chứng minh được tiền mặt vật lý đã trao tay. Audit lưu actor/time/amount/operation; tranh chấp cần quy trình hỗ trợ riêng. CASH paid không có nghĩa tiền vào tài khoản hệ thống hoặc đã payout cho rescuer.
- SECURITY DEFINER, auth.uid gateway, schema owners và privileged DB writers là trust boundary. Superuser/DDL owner có thể thay guard. Guard là defense bổ sung; quyền client vẫn do ACL/RLS/RPC kiểm soát.
- Reuse rescuer receipts giữ contract cũ: resource_id là UUID chung, không FK riêng tới payment; bảng receipt cũ không có append-only trigger như receipt customer GD2B. GD3 bind resource trong RPC, clients không đọc/ghi; privileged sửa/xóa receipt vẫn thuộc trust boundary. Không thêm cleanup/TTL.
- Chưa có rate limit riêng cho cash/receipt; actor advisory lock hiện tuần tự hóa toàn bộ rescuer mutations như foundation. Cần đo contention và receipt volume trước vận hành.
- Chưa kiểm gateway coercion/role mapping và concurrency native. Không suy từ PostgreSQL RAM rằng toàn bộ deployment settings/JWT validation đã đúng.
- Future bank/refund/recovery phải giữ lock order, snapshot immutability, ownership trước replay, atomic event/receipt và giới hạn một settlement. GD3 không triển khai các flow đó.

## 13. Chưa làm và bước tiếp theo

Không sửa frontend/customer_app, frontend/rescuer_app hoặc admin_web; workspace có thay đổi frontend từ trước. Không UI customer/rescuer/admin, realtime, QR, bank intent/transfer/provider/webhook, refund, admin settings, payout/settlement cho rescuer. Không sửa source GD1/GD2A/GD2B. Không deploy, không commit.

Backend source và PostgreSQL RAM **đã có thể chuyển CASH awaiting_payment sang paid** qua RPC đúng rescuer/approval/amount/version; môi trường thật chưa được áp GD3 bởi phiên này.

Bước tiếp theo: review migration, chạy concurrency và JWT/PostgREST integration trên Supabase local disposable; chỉ áp môi trường cụ thể khi người dùng yêu cầu. UI và bank/realtime thuộc phase được giao riêng.
