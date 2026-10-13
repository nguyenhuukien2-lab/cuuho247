# SePay — Kết quả tích hợp và runbook cấu hình production

Cập nhật: 13/10/2026.

Tài liệu tổng hợp kết quả tích hợp `bank-webhook` và SQL cấu hình production.
Người dùng thông báo function đã deploy thành công; phiên làm việc này không
truy cập production để xác nhận deployment, schema thực tế hoặc Function Secrets.
Không có SQL nào trong tài liệu được chạy thay người dùng. Không deploy, commit
hoặc sửa migration đã triển khai.

## 1. Nguồn đã đọc và đối chiếu

- `backend/supabase/migrations/202610110001_payment_bank_foundation.sql`
- `backend/supabase/migrations/202610110002_payment_bank_qr.sql`
- `backend/supabase/migrations/202610110003_payment_bank_verification.sql`
- `backend/supabase/functions/bank-webhook/sepay.ts`
- `backend/supabase/functions/bank-webhook/postgres_store.ts`
- `backend/supabase/functions/bank-webhook/index.ts`
- Các migration về sau trong hai thư mục backend/admin: không tìm thấy thay đổi
  tiếp theo đối với schema hoặc guard của `private.payment_bank_config`.

Schema dưới đây là schema suy ra chính xác từ source migration hiện tại. Query
ở bước 4 dùng để người vận hành đối chiếu schema production trước khi cập nhật.

## 2. Schema `private.payment_bank_config`

| Cột | Kiểu | Ý nghĩa |
| --- | --- | --- |
| `singleton` | boolean, primary key, chỉ nhận true | Một dòng cấu hình duy nhất |
| `enabled` | boolean NOT NULL | Bật khả năng chọn bank transfer/tạo QR |
| `bank_bin` | text NOT NULL, 6 chữ số | BIN ngân hàng nhận tiền |
| `bank_code` | text NOT NULL, 2–20 ký tự A–Z/0–9 | Mã ngân hàng dùng cho QR/DTO |
| `bank_name` | text NOT NULL | Tên ngân hàng; độ dài sau btrim 2–120 |
| `account_number` | text NOT NULL, 6–19 chữ số | Số tài khoản nhận tiền, giữ số 0 đầu |
| `account_name` | text NOT NULL | Tên chủ tài khoản; độ dài sau btrim 3–120 |
| `reference_policy` | text NOT NULL | Chỉ nhận `bank_sequence_v1` |
| `expiry_seconds` | integer NOT NULL | TTL intent, từ 60 đến 86400 giây |
| `version` | bigint NOT NULL, > 0 | Guard tự tăng khi UPDATE |
| `verification_enabled` | boolean NOT NULL | Bật processor xác minh/settle bank payment |
| `verification_provider` | text nullable | Provider theo regex `^[a-z][a-z0-9_]{0,63}$` |
| `verification_scope` | text nullable, 1–128 ký tự | Scope account/environment phía server |
| `require_beneficiary` | boolean NOT NULL | Bắt buộc có beneficiary evidence |

Không có cột `provider`, `provider_scope`, `beneficiary_bank_bin` hoặc
`beneficiary_account_number` trên bảng config này. Các tên đó thuộc normalized
transaction hoặc bảng khác, không được dùng làm tên cột UPDATE config.

Constraint `bank_verification_config_complete` yêu cầu provider và scope không
NULL khi `verification_enabled = true`.

Trigger `bank_config_guard` gọi `private.payment_bank_config_guard()`; mỗi UPDATE
tự đặt `new.version = old.version + 1`. Không tự ghi hoặc hạ `version` trong SQL.

## 3. Giá trị cần điền và nguyên tắc giữ QR

| Giá trị | Lấy từ đâu |
| --- | --- |
| `<SEPAY_PROVIDER_SCOPE>` | Chính xác Function Secret `SEPAY_PROVIDER_SCOPE`; scope ổn định do server cấu hình, dài 1–128 ký tự |
| `<BENEFICIARY_BIN>` | BIN 6 chữ số của ngân hàng nhận tiền; bằng Function Secret `SEPAY_BENEFICIARY_BANK_BIN` và `bank_bin` hiện có |
| `<BENEFICIARY_ACCOUNT>` | Tài khoản nhận tiền liên kết SePay; bằng `account_number` hiện có và `accountNumber` trong webhook đã xác thực |
| `<BEFORE_VERSION>` | `before_version` từ query bước 4 |
| `verification_provider` | Giá trị cố định `'sepay'`, đúng adapter hiện tại |
| `verification_enabled` | `true` để bật private processor |
| `require_beneficiary` | `true` để giữ kiểm tra beneficiary bắt buộc |

Chưa có scope/BIN/account production thật trong thông tin người dùng cung cấp.
Phải thay toàn bộ placeholder trước khi chạy SQL; không dùng giá trị minh họa
làm cấu hình thật. Nếu giá trị chứa dấu nháy đơn, escape thành hai dấu nháy đơn
trong SQL string literal.

BIN và account được dùng chung cho QR và matching. SQL bên dưới kiểm tra chúng
khớp bank config đang hoạt động, không ghi đè chúng. Nếu SePay dùng tài khoản
khác, script dừng: thay beneficiary là một thay đổi riêng cần xem xét QR/intent
đã phát hành. Không dùng INSERT, UPSERT, DELETE hoặc TRUNCATE để thay config.

## 4. Kiểm tra schema và lưu cấu hình trước UPDATE

Chạy bằng DB owner trong production SQL Editor. Không mở quyền private schema
cho API role để chạy các query này.

```sql
-- Đối chiếu schema production.
select
  a.attname as column_name,
  pg_catalog.format_type(a.atttypid, a.atttypmod) as data_type,
  a.attnotnull as not_null
from pg_catalog.pg_attribute a
where a.attrelid = 'private.payment_bank_config'::regclass
  and a.attnum > 0
  and not a.attisdropped
order by a.attnum;

-- Lưu kết quả: before_config, before_version và rollback_sql.
select
  to_jsonb(c) as before_config,
  c.version as before_version,
  format(
    $rollback$
begin;
set local lock_timeout = '5s';
set local statement_timeout = '15s';

update private.payment_bank_config
set verification_provider = %L,
    verification_scope = %L,
    verification_enabled = %L::boolean,
    require_beneficiary = %L::boolean
where singleton = true
  and version = %s
returning
  verification_provider,
  verification_scope,
  verification_enabled,
  require_beneficiary,
  version;

commit;
$rollback$,
    c.verification_provider,
    c.verification_scope,
    c.verification_enabled,
    c.require_beneficiary,
    c.version::numeric + 1
  ) as rollback_sql
from private.payment_bank_config c
where c.singleton = true;
```

Query thứ hai phải trả đúng một dòng. Nếu không có dòng, chưa có bank config để
cập nhật; dừng và không tự tạo bản ghi thay thế. Lưu kết quả ở nơi riêng tư vì
chứa thông tin tài khoản nhận tiền. `rollback_sql` khôi phục đúng giá trị cũ,
kể cả provider/scope NULL, và không chứa HMAC secret.

## 5. SQL bật SePay verification

Thay bốn placeholder. Chạy toàn bộ block trong một lần; exception khiến
transaction không thể commit thay đổi. Nếu công cụ giữ transaction lỗi mở,
chạy `ROLLBACK;` trước thao tác tiếp theo.

```sql
begin;
set local lock_timeout = '5s';
set local statement_timeout = '15s';

do $configure$
declare
  v_scope text := '<SEPAY_PROVIDER_SCOPE>';
  v_bin text := '<BENEFICIARY_BIN>';
  v_account text := '<BENEFICIARY_ACCOUNT>';
  v_expected_version bigint := '<BEFORE_VERSION>'::bigint;
  v_config private.payment_bank_config;
begin
  if v_scope ~ '[<>]'
     or length(v_scope) not between 1 and 128
     or v_bin !~ '^[0-9]{6}$'
     or v_account !~ '^[0-9]{6,19}$' then
    raise exception 'CONFIG_PLACEHOLDERS_OR_FORMAT_INVALID';
  end if;

  select c.*
  into strict v_config
  from private.payment_bank_config c
  where c.singleton = true
  for update;

  if v_config.version <> v_expected_version then
    raise exception 'CONFIG_VERSION_CHANGED_RECHECK_BACKUP';
  end if;

  if v_config.version = 9223372036854775807 then
    raise exception 'CONFIG_VERSION_EXHAUSTED';
  end if;

  if not v_config.enabled
     or v_config.reference_policy <> 'bank_sequence_v1' then
    raise exception 'EXISTING_QR_CONFIG_NOT_ACTIVE';
  end if;

  if v_config.bank_bin is distinct from v_bin
     or v_config.account_number is distinct from v_account then
    raise exception 'BENEFICIARY_DIFFERS_FROM_EXISTING_QR_CONFIG';
  end if;

  -- Không ghi đè provider/scope verification khác đang hoạt động.
  if v_config.verification_enabled
     and (
       v_config.verification_provider is distinct from 'sepay'
       or v_config.verification_scope is distinct from v_scope
     ) then
    raise exception 'OTHER_VERIFICATION_CONFIG_ALREADY_ACTIVE';
  end if;

  update private.payment_bank_config
  set verification_provider = 'sepay',
      verification_scope = v_scope,
      verification_enabled = true,
      require_beneficiary = true
  where singleton = true;
end;
$configure$;

select
  enabled,
  bank_bin,
  bank_code,
  bank_name,
  account_number,
  account_name,
  reference_policy,
  expiry_seconds,
  verification_provider,
  verification_scope,
  verification_enabled,
  require_beneficiary,
  version
from private.payment_bank_config
where singleton = true;

commit;
```

Chỉ bốn field verification được cập nhật. `enabled`, BIN/account, bank code/name,
account name, reference policy và TTL giữ nguyên; QR snapshots không thay đổi.
Trigger tăng version một lần. Chạy lại script yêu cầu đọc lại version và tạo lại
rollback SQL ở bước 4.

## 6. Kiểm tra sau UPDATE

Điền cùng scope/BIN/account đã dùng ở bước 5.

```sql
select
  verification_provider,
  verification_scope,
  verification_enabled,
  require_beneficiary,
  enabled as qr_enabled,
  reference_policy,
  version,
  (
    verification_provider = 'sepay'
    and verification_scope = '<SEPAY_PROVIDER_SCOPE>'
    and verification_enabled
    and require_beneficiary
    and enabled
    and bank_bin = '<BENEFICIARY_BIN>'
    and account_number = '<BENEFICIARY_ACCOUNT>'
    and reference_policy = 'bank_sequence_v1'
  ) as config_matches_expected
from private.payment_bank_config
where singleton = true;
```

Kỳ vọng đúng một dòng, `config_matches_expected = true`,
`version = before_version + 1`. Đối chiếu các field QR với `before_config`.
Query SQL không đọc hoặc xác minh được Supabase Function Secrets: operator phải
đối chiếu scope/BIN bên Function riêng.

## 7. Rollback an toàn

Nếu cấu hình sai sau commit, chạy nguyên SQL trong cột `rollback_sql` đã lưu ở
bước 4. SQL này khôi phục bốn field verification về giá trị trước UPDATE và giữ
nguyên QR config.

- Điều kiện `version = before_version + 1` ngăn rollback ghi đè thay đổi mới hơn.
- `RETURNING` phải trả đúng một dòng. Nếu trả 0 dòng, không có thay đổi nào được
  khôi phục; đọc lại cấu hình và review trước khi thực hiện rollback khác.
- Không bỏ điều kiện version để ép rollback.
- Trigger tiếp tục tăng version; không đưa version về số cũ.
- Nếu version đã đạt giới hạn bigint, guard không thể tăng tiếp và UPDATE bị
  rollback; cần xử lý riêng thay vì bỏ trigger.
- Rollback config không đảo ngược payment đã settle, không xóa transaction,
  receipt, QR snapshot hoặc audit.

## 8. Security và hoạt động của adapter

- `SEPAY_WEBHOOK_SECRET` chỉ ở Supabase Function Secrets. Không đưa vào SQL,
  source, frontend, config backup hoặc log.
- Adapter lấy provider scope từ `SEPAY_PROVIDER_SCOPE`, BIN từ
  `SEPAY_BENEFICIARY_BANK_BIN`, account từ payload đã xác thực.
- Adapter xác minh HMAC-SHA256 của `{timestamp}.{raw_body}` trước JSON.parse;
  dùng `X-SePay-Signature`, `X-SePay-Timestamp`, constant-time comparison và
  timestamp window 5 phút.
- Thiếu/sai HMAC hoặc secret trả 401 trước ghi transaction/cập nhật payment.
  Payload sai trả 400; lỗi processor/DB trả generic 500 không leak internals.
- Authenticated terminal outcome, duplicate hoặc replay trả 200
  `{"success":true}`. Private processor kiểm soát idempotency và settlement.
- Chỉ chấp nhận `transferType=in`. Reference lấy từ `code`, fallback toàn bộ
  `content` khi vừa giới hạn model; không trim/fuzzy-match.
- Entrypoint đọc `BANK_DATABASE_URL` từ Supabase Function Secrets và truyền vào
  `postgres_store.ts`. Operator phải cấu hình secret này bằng PostgreSQL connection
  URL server-only, với role có quyền gọi private processor. Không đưa URL chứa
  credentials vào frontend, source hoặc log. Transport vẫn dùng PostgreSQL trực
  tiếp, transaction và private helper; không cần cấp API role EXECUTE.
- Exact amount/reference/VND/beneficiary/payment state và atomic settlement
  tiếp tục do `private.process_verified_bank_transaction(jsonb)` xử lý.
- Không expose private schema/bank transactions; không grant anon/authenticated
  hoặc thêm quyền service_role. Customer/rescuer/admin không được mark bank paid.
- Không log secret, raw sensitive payload, headers, stack trace hoặc SQL details.
  Auth-failure audit chỉ lưu raw-body SHA-256 và metadata an toàn.

## 9. Kết quả validation từ lượt tích hợp trước

Các kết quả dưới đây đã được báo trong lượt implementation trước; không chạy lại
test hoặc SQL trong lượt chỉ chuẩn bị cấu hình/tạo tài liệu này.

| Validation | Kết quả |
| --- | --- |
| Edge Function Node tests | 38/38 PASS |
| Deno type-check entrypoint | PASS |
| Native PostgreSQL clean chain và catalog security audit | PASS |
| Payment bank verification regression | 141 assertions PASS |
| Admin payment regression | 51 assertions PASS |
| git diff --check tại lượt implementation | PASS |
| Concurrency chạy lại tại lượt implementation | Chưa thành công: local postgres role không phải superuser; baseline trước đó 4/4 PASS |

PGlite runner cũ không chạy được vì cache dependency đã bị dọn; native PostgreSQL
runner được dùng để xác minh SQL. Local Supabase serve chưa hoàn tất ở lượt đó;
type-check đã PASS qua Deno CLI tạm trong npm cache. Kết quả local không chứng
minh secrets, quyền kết nối DB, live webhook hoặc staging E2E của production.

Các file đã thêm/sửa trong lượt tích hợp:

- Modified: `README.md`, `adapter.ts`, `boundary_test.ts`, `handler.ts`, `index.ts`
  trong `backend/supabase/functions/bank-webhook/`.
- Added: `sepay.ts`, `postgres_store.ts`, `sepay_test.ts` trong cùng thư mục.
- Modified: `docs/payment_provider_integration.md`.
- Không sửa frontend hoặc migration payment.

Production cần scope/BIN/account và Function Secrets thật, schema đúng migration,
DB transport có quyền gọi private processor, cùng staging E2E valid/mismatch/
duplicate/replay trước khi coi auto-paid đã được xác nhận vận hành.

## 10. Tài liệu liên quan

- [Payment provider integration](payment_provider_integration.md)
- [Bank webhook README](../backend/supabase/functions/bank-webhook/README.md)
- [SePay webhook authentication](https://developer.sepay.vn/vi/sepay-webhooks/xac-thuc)
- [SePay webhook payload](https://developer.sepay.vn/vi/sepay-webhooks/tich-hop-webhook)
- [Supabase direct Postgres](https://supabase.com/docs/guides/functions/connect-to-postgres)

Tài liệu là runbook để người vận hành review và tự chạy. Việc tạo file này không
thực hiện SQL, sửa cấu hình production, deploy hoặc commit.
