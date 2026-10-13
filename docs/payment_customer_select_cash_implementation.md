# GD2B — Customer chọn phương thức CASH

Ngày: 2026-10-10. Phạm vi: một RPC chọn CASH, receipt chống lặp, mở đúng transition cần thiết trong guard, security regression và báo cáo. Không deploy, không commit.

Theo thông tin người dùng, GD1/GD2A đã có trên Supabase. Lần này không kết nối Supabase thật và không sửa hai migration đã triển khai. Tham chiếu [payment_backend_plan.md](payment_backend_plan.md), [payment_core_security_implementation.md](payment_core_security_implementation.md), [payment_customer_prepare_implementation.md](payment_customer_prepare_implementation.md).

## 1. Migration và RPC signature

- Migration mới: [202610100003_payment_customer_select_cash.sql](../backend/supabase/migrations/202610100003_payment_customer_select_cash.sql).
- Regression: [payment_customer_select_cash_regression.sql](../backend/supabase/tests/payment_customer_select_cash_regression.sql).

```sql
public.customer_select_payment_method(
  p_request_id uuid,
  p_payment_id uuid,
  p_method text,
  p_expected_version bigint,
  p_operation_id uuid
) returns jsonb
```

Chỉ một public RPC mới. Không nhận customer_id, rescuer_id, amount, actor, status hoặc timestamp. `SECURITY DEFINER SET search_path=''`, schema qualify object, không dynamic SQL.

Return có dạng `{"payment": <PaymentDTO GD2A>, "changed": true|false}`. PaymentDTO giữ nguyên 15 fields của getter GD2A; amount và version là decimal strings, nullable values là JSON null. Không trả raw event, receipt, payload_hash hoặc thông tin provider.

Migration có transaction, timeout và preflight prerequisites/ACL/RLS/guard; từ chối nếu receipt table hoặc RPC cùng tên đã tồn tại. Không tự overwrite một GD2B đã có.

## 2. Authentication và ownership

`auth.uid()` là principal duy nhất; NULL trả `AUTHENTICATION_REQUIRED` trước mọi lookup. Không dùng user metadata hoặc caller-supplied actor.

Sau kiểm operation key bắt buộc, RPC lấy operation advisory lock, rồi khóa request đúng `request_id + customer_id=auth.uid()`. Tiếp theo khóa payment với **đồng thời** payment ID, request ID và customer ID đúng caller. Receipt lookup chỉ diễn ra sau hai kiểm ownership này.

Request/payment không tồn tại, của người khác, cặp ID không khớp hoặc ID NULL đều trả `PAYMENT_NOT_ACCESSIBLE`, không trả true owner/rescuer/quote hoặc thông tin existence. Customer B không thể dùng receipt của A. Assigned rescuer cũng không có quyền customer mutation.

Role `anon` không được EXECUTE nên bị ACL từ chối trước khi vào function; role authenticated thiếu principal nhận lỗi authentication có cấu trúc.

## 3. State transition và guard

Chỉ chấp nhận chuỗi chính xác `cash`. `bank_transfer`, NULL, chuỗi khác hoặc `CASH` trả `METHOD_NOT_IMPLEMENTED` với operation chưa có receipt; không normalize để âm thầm chấp nhận input ngoài contract.

Đường mutation mới yêu cầu request completed, payment pending/method NULL:

```text
pending / method NULL / version N
  -> awaiting_payment / method cash / version N+1
```

`updated_at` do server trigger tạo. Không thay amount_expected/amount_received, customer/rescuer/assignment/quote, code, currency, created_at hoặc bất kỳ collection/settlement timestamp/actor nào. Không set paid. Zero amount vẫn trả `ZERO_AMOUNT_REQUIRES_POLICY`, nhất quán với GD2A; không coi là miễn phí.

Paid/refunded bị `PAYMENT_ALREADY_SETTLED`; cancelled/failed/verifying hoặc trạng thái không hợp lệ khác bị `PAYMENT_NOT_ELIGIBLE`. New operation trên cash/awaiting chỉ được no-op nếu đúng current version. No-op không UPDATE payment nên giữ nguyên updated_at/version.

**Thay đổi guard cần thiết:** GD1 vốn chặn mọi mutation. Migration GD2B mới dùng `CREATE OR REPLACE private.payment_core_guard()` để mở duy nhất transition trên, chỉ khi auth.uid khớp customer và version tăng đúng một. So sánh toàn bộ row JSON, chỉ loại method/status/version/updated_at, bảo đảm không kèm thay đổi field khác. INSERT pending, generator TT, snapshot/identity immutability, DELETE/TRUNCATE denial và server timestamps vẫn giữ behavior GD1. Không thêm flag GUC/JWT để bypass guard.

Không sửa file migration GD1/GD2A; database guard sẽ được nâng cấp **khi áp dụng migration GD2B**. Hai public RPC GD2A và event guard không bị thay định nghĩa hoặc ACL.

## 4. Version handling và error contract

Receipt của actor/key được kiểm trước stale-version rejection. Hash gồm expected_version gốc, vì vậy exact retry phải gửi lại nguyên payload ban đầu, không thay version bằng version mới nhận được.

| Trường hợp | message | SQLSTATE |
|---|---|---|
| Không có principal | `AUTHENTICATION_REQUIRED` | `42501` |
| Không có quyền/cặp request-payment không đúng | `PAYMENT_NOT_ACCESSIBLE` | `42501` |
| Operation ID NULL | `IDEMPOTENCY_KEY_REQUIRED` | `22023` |
| Cùng key nhưng payload khác sau ownership check | `IDEMPOTENCY_CONFLICT` | `22023` |
| Method chưa hỗ trợ | `METHOD_NOT_IMPLEMENTED` | `22023` |
| Expected version NULL hoặc <=0 | `INVALID_EXPECTED_VERSION` | `22023` |
| Expected version khác hiện tại, không có receipt khớp | `VERSION_CONFLICT` | `P0001` |
| Paid/refunded với operation mới | `PAYMENT_ALREADY_SETTLED` | `P0001` |
| Request/payment không đủ điều kiện | `PAYMENT_NOT_ELIGIBLE` | `P0001` |
| Amount snapshot bằng 0 | `ZERO_AMOUNT_REQUIRES_POLICY` | `P0001` |
| Constraint lỗi trong update/event/receipt | `PAYMENT_STATE_CONFLICT` | `P0001` |

Version cực đại bigint bị từ chối trước phép cộng. Terminal-state rejection có thể đi trước VERSION_CONFLICT; không reset state. Lỗi constraint trong khối mutation rollback toàn bộ và không trả raw row/constraint detail. Lỗi vận hành như deadlock/serialization/timeout không bị biến thành thành công; client phải retry transaction đúng operation identity.

## 5. Idempotency

| Tình huống | Kết quả |
|---|---|
| Key chưa có, pending + đúng version + cash | Một transition, một event, một receipt; changed=true |
| Cùng actor/key/payload đã commit | DTO của operation đã lưu, changed=false; không thêm event/receipt hoặc sửa row |
| Cùng actor/key nhưng method/version hoặc cặp owned request/payment khác | IDEMPOTENCY_CONFLICT |
| Key mới, cash/awaiting, version hiện tại | No-op, changed=false; lưu một receipt mới, không event mới |
| Key mới, cash/awaiting, version cũ | VERSION_CONFLICT; không receipt mới |
| Cùng key nhưng actor khác | Namespace độc lập; luôn kiểm ownership, không đọc hoặc tái sử dụng receipt actor trước |

Nếu payload đổi sang resource không được phép đọc, lỗi ownership được ưu tiên thay vì tiết lộ receipt. Một request lỗi trước commit không tiêu thụ operation key; retry cùng key sau khi nguyên nhân lỗi được xử lý có thể thực hiện.

Replay trả kết quả lịch sử của operation; không biểu thị trạng thái payment mới nhất nếu phase sau đã thay đổi payment. Dùng `customer_get_payment` để refresh current state. Exact retry không thực hiện lựa chọn mới, kể cả khi state đã tiến xa hơn.

## 6. Operation receipt

Reuse kiến trúc `private.rescuer_rpc_receipts`: actor-scoped operation key, SHA-256 của JSON canonical payload và advisory transaction lock. Tạo riêng `private.payment_rpc_receipts` vì customer không phải rescuer profile, và cần lưu DTO an toàn để replay kết quả đã commit.

| Field | Contract |
|---|---|
| actor_id uuid | NOT NULL, FK auth.users ON DELETE RESTRICT; trigger đối chiếu auth.uid và payment.customer_id |
| operation_id uuid | NOT NULL; PK(actor_id,operation_id) |
| operation_name text | Allowlist hiện chỉ customer_select_payment_method |
| payload_hash text | SHA-256 hex 64 ký tự của `[operation_name, request_id, payment_id, method, expected_version]` |
| payment_id uuid | NOT NULL, FK payments ON DELETE RESTRICT |
| response_payment jsonb | Safe DTO từ getter GD2A; object <=8192 byte |
| committed_at timestamptz | Server clock_timestamp, finite, ghi đè input trong trigger |

`committed_at` theo naming convention receipt hiện có: thời điểm server ghi receipt trong transaction, không phải PostgreSQL commit timestamp. Row chỉ tồn tại bền vững nếu cả transaction commit.

Receipt RLS bật trong migration transaction, không policy và không client SELECT/DML. Trigger invoker `private.payment_receipt_guard()` chặn UPDATE/DELETE/TRUNCATE kể cả writer privileged thông thường; schema/DDL owner vẫn là trust boundary. Không TTL hoặc cleanup job xóa receipt vì sẽ làm mất lịch sử idempotency. Chưa bổ sung index ngoài PK: đường truy cập chính là actor/key.

## 7. Event và atomicity

Mỗi effective transition ghi đúng một `payment_method_selected`:

- actor_type customer, actor_id từ auth.uid.
- old_status pending, new_status awaiting_payment.
- amount từ payment.amount_expected, request_id từ payment đã khóa.
- metadata chỉ `{"old_method":null,"new_method":"cash"}`.
- payment_version là version mới; operation_id là key đã kiểm.
- event_sequence = max hiện có +1 dưới payment row lock, không hardcode 2 cho mọi lịch sử.
- created_at do event guard GD1 cấp.

Update payment, event insert và receipt insert cùng transaction/subtransaction. Event hoặc receipt constraint failure rollback cả ba. Không ghi event cho exact retry hoặc new-key no-op. Chọn CASH chỉ ghi nhận ý định thanh toán, không chứng minh đã thu tiền.

## 8. RLS, grants và phạm vi thay đổi

Giữ nguyên hai participant SELECT policies của payments. Không thêm UPDATE policy, không cấp table INSERT/UPDATE/DELETE/TRUNCATE cho anon/authenticated và không mở raw payment_events.

RPC mới revoke EXECUTE PUBLIC/anon/authenticated rồi grant đúng signature cho authenticated. Receipt table/guard revoke PUBLIC/anon/authenticated; nếu service_role tồn tại cũng revoke các quyền trên objects GD2B. Hai guards private là SECURITY INVOKER, search_path rỗng, không exposed callable helper. `private` vẫn phải nằm ngoài PostgREST exposed schemas.

Migration cũ, test/report cũ, frontend/customer_app, frontend/rescuer_app và admin_web không thay đổi. Checksum tập file này khớp baseline trước/sau GD2B. Các diff frontend có sẵn trong workspace không thuộc công việc lần này.

## 9. Tests và kết quả

Đã chạy trong database RAM mới: **PGlite 0.5.8 / PostgreSQL 18.3**, schema Auth/Storage/roles mô phỏng cho migrations repository. Không kết nối Supabase URL hoặc database vận hành.

| Kiểm tra | Kết quả |
|---|---|
| GD2A regression trước GD2B | 72/72 PASS trên mỗi cấu hình schema |
| Apply GD2B shared + admin/display codes | PASS |
| GD2B SQL regression full schema, hai lần | **91/91 PASS mỗi lần, 0 FAIL** |
| Apply GD2B shared-only | PASS |
| GD2B SQL regression shared-only, hai lần | **91/91 PASS mỗi lần, 0 FAIL** |
| Retry ở transaction mới sau commit thực trong RAM | **3/3 PASS trên mỗi cấu hình**: changed=false, DTO giống receipt, method event count=1 |
| Fixture/receipt rollback và repeat suite | PASS |
| Thiếu local opt-in | Từ chối đúng |
| Rerun migration GD2B | Từ chối overwrite đúng |
| GD2A function definitions/ACL và event guard trước/sau GD2B | Không đổi |

91 assertions bao phủ các nhóm success/state/method/version/event actor/status/amount; received/paid/cash timestamps NULL; full-row invariant; wrong customer/unrelated/rescuer/unauthenticated/anon/wrong IDs; stale/missing/invalid version/key/method; năm trạng thái paid/cancelled/refunded/verifying/failed; exact retry/payload conflict/cross-resource conflict/cross-actor receipt isolation; new-key no-op; direct payment/event/receipt denial; guard chống bank/paid/skipped version/collection fields; rollback khi audit hoặc receipt lỗi và recovery cùng key; getter/prepare không reset payment đã chọn cash; không thêm RPC ngoài phạm vi hoặc realtime.

Fixtures cho paid/refunded/cancelled/verifying/failed không thể tạo bằng production API hiện tại. Test chỉ trong disposable local DB: subtransaction privileged tạm disable **đúng row guard payment_core_guard**, set synthetic state, bật lại guard **trước** khi gọi RPC với role authenticated rồi rollback toàn subtransaction. Không disable RLS, không nới client grants; cuối suite xác nhận guard bật. Đây không phải cách tạo payment thật hay một migration flow bổ sung.

SQL regression có local opt-in, privileged setup và cuối file ROLLBACK; sequence increments không rollback. Khi chạy qua psql cần `-X -v ON_ERROR_STOP=1`, `SET payment.test_mode='local_disposable'` trên cùng connection đã xác minh disposable. Opt-in không tự chứng minh host an toàn.

Harness cache ignored dùng trong phiên: `.cache_rescuer/temp/payment-core-security/run_payment_select_cash.mjs`, chạy mặc định full schema và `--shared-only`. Riêng scenario post-commit thay terminal ROLLBACK của suite bằng COMMIT **chỉ trong bản SQL RAM của harness**, rồi gọi RPC trong transaction mới và hủy database RAM khi đóng engine. File regression giao cho repo vẫn rollback-only. Scenario mô phỏng response thất lạc sau commit, không mô phỏng lỗi mạng HTTP thật.

Suite GD2A nguyên bản có assertion chưa tồn tại select-method RPC nên chạy trước GD2B; không sửa test cũ để thay lịch sử. Các invariants cần thiết sau GD2B được kiểm trong suite mới. Default grants được cố tình mở rộng trên objects mới trong harness để xác nhận migration revoke vẫn đúng.

## 10. Concurrency

Thứ tự khóa: advisory actor/operation -> owned request FOR UPDATE -> payment FOR UPDATE. Không truy vấn hoặc mutation assignment nên không cần thêm assignment lock ở GD2B. Operation lock ngăn cùng actor/key đua trên hai payment khác nhau; parent/payment lock tuần tự hóa các key khác nhau trên cùng payment. PK receipt và GD1 unique event sequence là bảo vệ bổ sung.

**Chưa chạy concurrency hai connection trên cùng DB.** Docker Desktop Linux engine không hoạt động trong môi trường này. PGlite single session và hai process test trên hai database độc lập không được tính là concurrency thật.

Kịch bản cần chạy trên Supabase/PostgreSQL local native:

1. Hai connection cùng owner/payment/key/payload/version=1: A chọn cash giữ transaction, B phải đợi; commit A thì B replay changed=false. Một transition, version=2, một method event, một receipt.
2. Hai key khác nhau cùng payment/version=1: A commit trước, B nhận VERSION_CONFLICT; vẫn chỉ một event. B refresh version=2 và gửi operation chưa commit đó thì no-op, không event mới.
3. Cùng actor/key nhưng hai owned payment khác nhau: sau một transaction commit, transaction kia IDEMPOTENCY_CONFLICT; không mutate payment thứ hai.
4. Rollback transaction A trong khi B đợi: B được phép thực hiện một transition, không thấy receipt/event dở dang.

Ở isolation cao hơn READ COMMITTED hoặc khi deadlock/timeout, phải retry cả transaction với key/payload cũ. Chưa kiểm native Supabase/PostgREST/Auth/JWT HTTP, lock contention thực hoặc load test. Không chạy SQL trên production.

## 11. Security risks còn lại

- SECURITY DEFINER dựa vào migration owner, schema/ACL và JWT gateway đáng tin. Superuser/DDL owner có thể thay trigger; không tuyên bố chống được quyền quản trị DB toàn phần.
- Guard giới hạn hình dạng transition; ACL/RLS và RPC là đường client mutation. Một privileged SQL writer có table access và principal phù hợp vẫn thuộc trust boundary; không grant writer tổng quát cho app để bỏ qua RPC/audit/receipt.
- Future mutation phải giữ lock order, ownership, immutable snapshot, version và atomic event/receipt. Receipt replay là historical DTO; caller cần getter khi cần current state.
- New-key no-op lưu receipt để đảm bảo key không tái sử dụng với payload khác. Chưa có payment rate limit/quota riêng; volume receipt/lock contention cần được theo dõi khi chuẩn bị vận hành. Không tự thêm settings admin ngoài phạm vi.
- Chưa xác minh native concurrency hoặc toàn bộ PostgREST deployment settings. Không suy từ PGlite rằng gateway/role mapping production đã đúng.
- Không có thu tiền hoặc settlement; cash/awaiting không được hiển thị như paid hoặc tiền về hệ thống. Không log token, secret, raw provider data; metadata event là allowlist hai method keys.

## 12. Chưa làm

Không tạo rescuer_get_job_payment/rescuer_confirm_cash_received hoặc rescuer mutation. Không UI customer/rescuer/admin, realtime publication/subscription, QR/bank transfer/bank intent/provider/webhook, auto paid, settings admin hay refund. Không sửa frontend/admin hoặc files GD1/GD2A. Không deploy, không commit.

## 13. Bước tiếp theo

Review migration GD2B, chạy native Supabase local với JWT/PostgREST và concurrency hai connection trước khi người dùng yêu cầu áp dụng môi trường cụ thể. GD3 sau đó mới triển khai rescuer đọc payment/xác nhận thu CASH theo assignment, amount rule và idempotency được duyệt riêng. Chưa thực hiện GD3.
