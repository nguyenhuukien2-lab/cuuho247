# SePay Test Mode → Live Mode cutover runbook

Cập nhật: 13/10/2026. Runbook này là kế hoạch vận hành; không lệnh nào trong
tài liệu đã được chạy. Không chứa secret, account, password hoặc connection URL
thật. Thay placeholder trong phiên vận hành được kiểm soát, không lưu giá trị
thật vào repository, ticket, log hoặc shell history.

## 1. Gate trước cutover

Chỉ bắt đầu khi tất cả điều kiện sau đều đúng:

- commit cần deploy đã được review và bank-webhook tests, Deno check, GD6C
  regression đều PASS;
- `private.payment_bank_config` có đúng một dòng, beneficiary production đã được
  operator đối chiếu với QR và tài khoản SePay Live;
- `require_beneficiary=true`; tuyệt đối không dùng `false` để cutover;
- không có receipt `received`/`failed` chưa xử lý hoặc transfer Test Mode đang
  chờ retry;
- có maintenance window, người chịu trách nhiệm SePay, Supabase và rollback;
- có một completed request/payment giá trị nhỏ được phê duyệt để test thật.

Code gate không thay thế Live evidence. Mapping Test Mode không chứng minh webhook
Live gửi đúng beneficiary account.

## 2. Secrets

| Secret | Live action |
| --- | --- |
| `SEPAY_WEBHOOK_SECRET` | Đổi sang HMAC secret của webhook SePay Live; không tái sử dụng Test secret |
| `SEPAY_PROVIDER_SCOPE` | Đổi từ `sepay_test` sang `<LIVE_PROVIDER_SCOPE>` ổn định và khác tuyệt đối `sepay_test` |
| `SEPAY_BENEFICIARY_BANK_BIN` | Giữ nguyên và phải bằng `private.payment_bank_config.bank_bin` |
| `BANK_DATABASE_URL` | Giữ nguyên; không đưa URL/credentials vào frontend hoặc log |
| `SEPAY_TEST_ACCOUNT_NUMBER` | Xóa/unset trước Live; Live code vẫn bỏ qua giá trị này nhưng không nên giữ cấu hình thừa |

Live account không có Function Secret riêng: account phải đến từ webhook đã HMAC
xác thực và exact-match `payment_bank_config.account_number`/QR snapshot trong GD6C.

Đặt secret bằng dashboard bảo mật hoặc env file tạm ngoài repository. Ví dụ lệnh
CLI, không đặt giá trị thật trực tiếp vào command history:

```powershell
supabase secrets set --env-file <ABSOLUTE_PATH_TO_SECURE_LIVE_ENV_FILE>
supabase secrets unset SEPAY_TEST_ACCOUNT_NUMBER
```

Env file tạm chỉ cần hai giá trị thay đổi: `SEPAY_WEBHOOK_SECRET` và
`SEPAY_PROVIDER_SCOPE`. Không ghi lại BIN/DB URL đang giữ nguyên; xóa file an toàn
sau khi set.

## 3. Backup và preflight SQL

Chạy bằng DB owner. Lưu output ở nơi hạn chế truy cập vì config chứa beneficiary.
Query phải trả đúng một dòng.

```sql
select
  to_jsonb(c) as before_config,
  c.version as before_version,
  c.enabled as before_qr_enabled,
  c.verification_enabled as before_verification_enabled
from private.payment_bank_config c
where c.singleton = true;

select
  c.enabled,
  c.verification_enabled,
  c.verification_provider,
  c.verification_scope,
  c.require_beneficiary,
  c.reference_policy,
  c.bank_bin ~ '^[0-9]{6}$' as bank_bin_shape_valid,
  c.account_number ~ '^[0-9]{6,19}$' as account_shape_valid,
  c.version
from private.payment_bank_config c
where c.singleton = true;

select
  count(*) filter (where status in ('received','failed')) as incomplete_receipts,
  count(*) filter (where status = 'rejected') as rejected_receipts
from private.payment_webhook_receipts
where provider = 'sepay' and provider_scope = 'sepay_test';

select count(*) as active_unexpired_intents
from private.payment_bank_intents
where status in ('created','ready','matched')
  and expires_at > clock_timestamp();
```

Preflight bắt buộc: provider `sepay`, scope `sepay_test`, cả hai switch đang ở
trạng thái operator mong đợi, `require_beneficiary=true`, reference policy
`bank_sequence_v1`, shape BIN/account hợp lệ và `incomplete_receipts=0`.
`active_unexpired_intents` cũng phải bằng 0; nếu khác 0, chờ expiry hoặc hoàn tất
reconciliation thay vì ép đóng/xóa intent. Ghi lại `<BEFORE_VERSION>`, `<BEFORE_QR_ENABLED>` và
`<BEFORE_VERIFICATION_ENABLED>` cho rollback.

Kiểm tra ACL không drift:

```sql
select
  has_table_privilege('anon','public.payments','INSERT,UPDATE,DELETE') as anon_can_write,
  has_table_privilege('authenticated','public.payments','INSERT,UPDATE,DELETE') as authenticated_can_write,
  has_function_privilege('authenticated','private.process_verified_bank_transaction(jsonb)','EXECUTE') as authenticated_can_process,
  has_function_privilege('service_role','private.process_verified_bank_transaction(jsonb)','EXECUTE') as service_role_can_process;
```

Cả bốn giá trị phải `false`.

## 4. Thứ tự cutover chính xác

### Bước 1 — Freeze QR và verification, đồng thời stage Live scope

Không sửa BIN/account/name/reference policy/TTL. Thay placeholder scope/version,
chạy nguyên transaction và lưu `scope_staged_version` trả về.

```sql
begin;
set local lock_timeout = '5s';
set local statement_timeout = '15s';

update private.payment_bank_config
set enabled = false,
    verification_enabled = false,
    verification_provider = 'sepay',
    verification_scope = '<LIVE_PROVIDER_SCOPE>',
    require_beneficiary = true
where singleton = true
  and version = <BEFORE_VERSION>
  and verification_provider = 'sepay'
  and verification_scope = 'sepay_test'
  and require_beneficiary = true
  and reference_policy = 'bank_sequence_v1'
  and '<LIVE_PROVIDER_SCOPE>' <> 'sepay_test'
  and '<LIVE_PROVIDER_SCOPE>' !~ '[<>]'
  and length('<LIVE_PROVIDER_SCOPE>') between 1 and 128
returning version as scope_staged_version;

commit;
```

`RETURNING` phải có đúng một dòng. Nếu không, `ROLLBACK`, đọc lại backup và dừng.
Trong trạng thái này không có QR mới và processor không settle, nên Test/Live
delivery đến nhầm thời điểm chỉ có thể fail closed.

### Bước 2 — Tắt webhook Test Mode

Disable hoặc xóa webhook Test Mode tại SePay. Không thay HMAC secret trước khi DB
đã freeze. Ghi lại webhook ID/config phục vụ rollback nhưng không ghi secret.

### Bước 3 — Set Live secrets và deploy đúng commit đã review

Set các secret theo mục 2, unset `SEPAY_TEST_ACCOUNT_NUMBER`, sau đó deploy đúng
artifact/commit đã test:

```powershell
supabase functions deploy bank-webhook --no-verify-jwt
```

`--no-verify-jwt` chỉ bỏ Supabase JWT gateway; HMAC SePay trong function vẫn bắt
buộc. Sau deploy, gửi request không có/sai HMAC và xác nhận 401; không dùng payload
thật hoặc secret trong log.

### Bước 4 — Tạo webhook SePay Live

Tạo webhook Live trỏ tới endpoint `bank-webhook`, chỉ đăng ký incoming transfer,
và cấu hình cùng Live HMAC secret. Nếu SePay cho phép disable webhook, giữ disabled
đến hết bước 5. Nếu webhook active ngay, processor vẫn đang disabled và trả lỗi
retry được; hoàn tất bước 5 ngay trong maintenance window.

Không để webhook Test và Live cùng hoạt động trên endpoint chỉ có một HMAC secret.

### Bước 5 — Verify staged config rồi activate

Đối chiếu `<LIVE_PROVIDER_SCOPE>` với Function Secret và
`<SCOPE_STAGED_VERSION>` với output bước 1. Query đầu phải trả `staged_ok=true`.

```sql
select
  verification_provider = 'sepay'
    and verification_scope = '<LIVE_PROVIDER_SCOPE>'
    and verification_scope <> 'sepay_test'
    and not verification_enabled
    and not enabled
    and require_beneficiary
    and reference_policy = 'bank_sequence_v1' as staged_ok,
  version
from private.payment_bank_config
where singleton = true;

begin;
set local lock_timeout = '5s';
set local statement_timeout = '15s';

update private.payment_bank_config
set verification_enabled = true,
    enabled = true,
    require_beneficiary = true
where singleton = true
  and version = <SCOPE_STAGED_VERSION>
  and verification_provider = 'sepay'
  and verification_scope = '<LIVE_PROVIDER_SCOPE>'
  and verification_scope <> 'sepay_test'
  and verification_scope !~ '[<>]'
  and require_beneficiary = true
  and reference_policy = 'bank_sequence_v1'
returning version as live_active_version;

commit;
```

`RETURNING` phải có đúng một dòng. Lưu `<LIVE_ACTIVE_VERSION>` cho rollback. Bật
webhook Live nếu nó đang disabled.

### Bước 6 — Post-activation verify

```sql
select
  enabled,
  verification_enabled,
  verification_provider,
  verification_scope,
  require_beneficiary,
  reference_policy,
  bank_bin,
  account_number,
  version,
  enabled
    and verification_enabled
    and verification_provider = 'sepay'
    and verification_scope = '<LIVE_PROVIDER_SCOPE>'
    and verification_scope <> 'sepay_test'
    and require_beneficiary
    and reference_policy = 'bank_sequence_v1' as live_ready
from private.payment_bank_config
where singleton = true;
```

Kỳ vọng `live_ready=true`. Đối chiếu BIN/account/name/TTL với `before_config`; chúng
phải không đổi.

## 5. Một giao dịch Live thật giá trị nhỏ

1. Dùng một completed request/payment dành riêng cho smoke test, với số tiền nhỏ
   đã được phê duyệt. Không chỉnh amount trực tiếp trong DB.
2. Customer chọn bank transfer bằng RPC/UI bình thường sau cutover. Lưu nội bộ
   `payment_id`, `request_id`, exact `transfer_content`, amount và expiry từ DTO.
3. Kiểm tra QR hiển thị đúng production beneficiary; chuyển đúng exact amount và
   exact reference trước expiry bằng tài khoản thật được phép.
4. Không gửi lần hai khi UI chậm. Chờ realtime invalidation rồi refetch getter.
5. Xác nhận webhook trả 200 và SQL dưới đây chứng minh settlement đúng một lần.

```sql
select
  p.id as payment_id,
  p.request_id,
  p.method,
  p.status,
  p.amount_expected,
  p.amount_received,
  p.currency,
  p.paid_at,
  p.verified_at,
  i.id as intent_id,
  i.status as intent_status,
  s.transfer_content,
  t.id as bank_transaction_id,
  t.provider,
  t.provider_scope,
  t.status as transaction_status,
  t.amount as transaction_amount,
  t.currency as transaction_currency,
  t.transfer_reference,
  t.beneficiary_bank_bin,
  t.beneficiary_account_number,
  r.status as receipt_status,
  r.result_code
from public.payments p
join private.payment_bank_intents i on i.payment_id = p.id
join private.payment_bank_qr_snapshots s on s.intent_id = i.id
join private.bank_transactions t on t.matched_payment_id = p.id
join private.payment_webhook_receipts r on r.id = t.receipt_id
where p.id = '<PAYMENT_UUID>'::uuid;

select
  count(distinct t.id) filter (where t.status = 'verified') as verified_transactions,
  count(distinct e.id) filter (where e.event_type = 'bank_payment_verified') as paid_events
from public.payments p
left join private.bank_transactions t on t.matched_payment_id = p.id
left join public.payment_events e on e.payment_id = p.id
where p.id = '<PAYMENT_UUID>'::uuid;
```

Kỳ vọng: payment/intent/transaction/receipt lần lượt `paid`/`verified`/`verified`/
`processed`; amount/currency/reference/beneficiary exact; `paid_at=verified_at`;
scope đúng Live; `result_code=paid`; `verified_transactions=1`, `paid_events=1`.
Gửi lại cùng delivery để xác nhận replay trả 200 nhưng hai count vẫn bằng 1 nếu
SePay có chức năng retry an toàn; không tạo giao dịch ngân hàng thứ hai.

## 6. Rollback về Test Mode

Rollback không đảo ngược payment đã paid và không xóa transaction/receipt/audit.
Nếu tiền Live đã rời tài khoản nhưng payment chưa paid, dừng tự động retry/
regeneration và chuyển sang reconciliation; không dùng Test mapping để hợp thức
hóa giao dịch Live.

### Bước R1 — Kill switch và stage lại Test scope

Dùng version hiện tại vừa đọc, không đoán. Lệnh dưới đây vừa tắt QR/verification
vừa đổi scope về Test trong một transaction; lưu `test_staged_version`.

```sql
begin;
set local lock_timeout = '5s';
set local statement_timeout = '15s';

update private.payment_bank_config
set enabled = false,
    verification_enabled = false,
    verification_provider = 'sepay',
    verification_scope = 'sepay_test',
    require_beneficiary = true
where singleton = true
  and version = <CURRENT_LIVE_VERSION>
  and verification_provider = 'sepay'
  and verification_scope = '<LIVE_PROVIDER_SCOPE>'
  and '<LIVE_PROVIDER_SCOPE>' <> 'sepay_test'
  and '<LIVE_PROVIDER_SCOPE>' !~ '[<>]'
  and require_beneficiary = true
  and reference_policy = 'bank_sequence_v1'
returning version as test_staged_version;

commit;
```

Nếu `RETURNING` không có đúng một dòng, dừng; không bỏ version guard.

### Bước R2 — Tắt Live webhook, khôi phục Test secrets và deploy

Disable webhook Live. Khôi phục Test HMAC secret, đặt
`SEPAY_PROVIDER_SCOPE=sepay_test`, giữ nguyên BIN/DB URL, khôi phục
`SEPAY_TEST_ACCOUNT_NUMBER` từ secret manager, rồi deploy cùng reviewed commit.
Tạo/bật lại webhook Test Mode với đúng Test HMAC secret. Không để Live webhook
còn active.

### Bước R3 — Reactivate Test Mode

Dùng flags từ `before_config`; thông thường cả hai là `true`, nhưng không tự giả
định. Thay placeholder boolean và `<TEST_STAGED_VERSION>`:

```sql
begin;
set local lock_timeout = '5s';
set local statement_timeout = '15s';

update private.payment_bank_config
set enabled = <BEFORE_QR_ENABLED>,
    verification_enabled = <BEFORE_VERIFICATION_ENABLED>,
    require_beneficiary = true
where singleton = true
  and version = <TEST_STAGED_VERSION>
  and verification_provider = 'sepay'
  and verification_scope = 'sepay_test'
  and require_beneficiary = true
  and reference_policy = 'bank_sequence_v1'
returning version;

commit;
```

Verify đúng Test scope, exact beneficiary config không đổi, sau đó chạy lại một
Test Mode fixture với exact test account. Không re-enable nếu còn receipt
`received`/`failed` hoặc transfer Live chưa reconciliation.

## 7. Stop/rollback conditions

Rollback hoặc giữ kill switch nếu bất kỳ điều kiện nào xảy ra:

- Live scope bằng `sepay_test`, secret test vẫn được dùng, hoặc HMAC invalid;
- webhook Live không gửi account thật hay account/BIN không exact-match config;
- config `require_beneficiary` khác `true`;
- wrong amount/reference/currency/state có thể settle;
- replay tạo payment event/verified transaction thứ hai;
- frontend có write grant/RPC để mark bank paid;
- payment đã chuyển tiền thật nhưng không thể xác định trạng thái: chuyển sang
  reconciliation, không thử giao dịch thứ hai.

Không sửa migration cũ, không xóa audit/receipt/transaction và không đổi
production beneficiary để làm cho smoke test pass.
