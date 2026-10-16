# SePay Live fix continuation and validation

Validated locally on 2026-10-15. No deployment, commit, production database access,
manual settlement, or historical migration edit was performed.

## Root cause

The original QR generator used only the canonical `BK` reference as the transfer
description. VietinBank personal/household accounts require `SEVQR` for delivery
to SePay. The connection guide requires it at the beginning; the new description
satisfies that stricter form. Sources:
[SePay connection guide](https://docs.sepay.vn/ket-noi-vietinbank.html) and
[SePay QR guide](https://developer.sepay.vn/en/tien-ich-khac/tao-qr-code).

A second matching issue existed when authenticated SePay `code` was empty/null:
the adapter compared the entire narration with the canonical reference. The
preserved fix extracts one exact canonical reference under the conditions below.

These are code/contract findings consistent with the reported incident. This
session did not inspect production transactions or verify TT-000011's state.

## Files already changed in the previous session

Initial `git status --short` showed only an unrelated Stitch report and the
untracked `admin_web/.payment-sevqr-work/` directory. Both `git diff --stat` and
`git diff` were empty. The previous session worked from `admin_web` and preserved
the implementation in that directory instead of the application source paths.

Six changed files were restored to unchanged destinations after comparing them:

- `backend/supabase/functions/bank-webhook/sepay.ts`
- `backend/supabase/functions/bank-webhook/sepay_test.ts`
- `backend/supabase/tests/payment_bank_qr_regression.sql`
- `frontend/customer_app/lib/models/bank_payment_dto.dart`
- `frontend/customer_app/lib/widgets/bank_payment_ui.dart`
- `frontend/customer_app/test/payment_bank_test.dart`

Two new files were restored:

- `backend/supabase/migrations/202610150002_vietinbank_sepay_transfer_description.sql`
- `tools/check_vietinbank_sepay.mjs`

The six other staged webhook files are byte-identical support copies, not new
implementation changes. The entire preserved directory remains intact.

## Remaining fixes completed

- Fixed a nondeterministic replay fixture: retries previously generated a new
  transaction timestamp. Crossing a second boundary correctly caused the
  unchanged processor to return `identity_conflict`, failing the test's expected
  `duplicate_event`. Retries now retain the original timestamp, with a deliberate
  1.1-second delay proving the boundary case. HMAC delivery freshness is retained.
- Added actual adapter-to-SQL checks for null code, malformed references, and a
  different Live scope. Added upgrade checks for unchanged configuration and
  function ownership alongside the existing ACL/security/settlement checks.
- Added optional `DatabaseUser` to `tools/check_full_backend_native.ps1`, retaining
  its `postgres` default. This local Supabase installation uses `supabase_admin`
  as the superuser; no roles or production permissions were changed.
- Captured native-runner output through a subprocess so PostgreSQL NOTICE output
  is not turned into a terminating PowerShell redirection error. The original
  first native attempt stopped on a harmless missing-disposable-database NOTICE.

No additional payment runtime change was needed beyond the preserved fix.

## New migration and QR format

`202610150002_vietinbank_sepay_transfer_description.sql` follows the repository's
latest predecessor `202610150001_system_security_rpc_hardening.sql`.

- Canonical snapshot `transfer_content`: `^BK[0-9]{19}$`, exactly 21 ASCII bytes.
- New VietinBank/SePay Live description: `SEVQR ` followed by that reference,
  exactly 27 ASCII bytes. Example: `SEVQR BK0000000000000000001`.
- Generation is limited to BIN `970415`, provider `sepay`, non-null scope other
  than `sepay_test`. Other banks/providers/Test Mode retain legacy descriptions.
- The encoder permits only this narrow 27-byte extension in addition to its
  existing 1-25-character uppercase alphanumeric form. It rejects arbitrary
  longer descriptions. Nested TLV `62/08`, its lengths, overall size, and CRC16
  are independently checked. Canonical identifiers are never truncated.
- Only new/regenerated snapshots use the new memo. Existing snapshots remain
  immutable. The getter derives the visible description from the stored QR,
  retaining the previous description for old snapshots.
- Flutter displays/copies `transfer_description`, preserves canonical
  `transfer_content`, and accepts old DTOs without the new field.
- The migration preserves the session/account-state guard, function ownership,
  signatures, ACLs, security modes, and the unchanged settlement processor.

The 27-byte bank-app scan behavior remains an external acceptance gate. Local
TLV/CRC validity alone cannot establish compatibility with every payer bank app.
This is a narrow local encoder extension, not a claim of universal compatibility
or permission to truncate through an API limited to 25 characters.

## Adapter fallback

HMAC over the exact raw bytes and delivery freshness are verified before JSON
parsing/extraction. Incoming direction is checked before fallback. Nonempty
`code` stays authoritative and is never repaired from narration. Only `content`
is searched; `description` and `referenceCode` are not fallback sources.

Live empty/null code accepts exactly one case-sensitive `BK[0-9]{19}` occurrence
with explicitly allowed separators. The candidate scan counts uppercase and
lowercase BK/numeric occurrences before accepting the exact uppercase form.
Missing, duplicate, multiple, malformed, embedded, extended, lowercase and
non-ASCII digit references in the negative matrix cannot settle a payment.

Zero/multiple/malformed reference cases normalize to no reference and produce
`reference_unmatched`. Outgoing payloads return 400. Wrong configured provider
scope fails closed with SQLSTATE 55000 / generic HTTP 500. Exact amount,
beneficiary, configured scope, currency, intent validity/time window, ownership,
idempotency and replay checks remain in the existing database processor.
HTTP 200 alone never means a payment was settled.

## Hook failure root cause and evidence limits

The prior session's last integration command exited 1 at `duplicate_event` versus
`identity_conflict`; this is the timestamp fixture issue fixed above. Earlier
fixture failures (expiry constraint and the wrong expected conflict label) had
already been corrected in the preserved files.

The session then recorded interruption at `2026-10-15T16:23:24Z`, with lifecycle
hook started/completed events. The configured hook is `hooks.Interrupt` in
`C:/Users/ADMIN/.codex/config.toml:34`, managed by codex-chatgpt-web 6.1.4. It invokes
the bridge's cancellation handler, not any project payment test.

The configured command starts with a quoted executable followed by quoted
arguments, without PowerShell's invocation operator `&`. Running that exact
command under the configured Windows PowerShell reproduces exit 1 with
`ParserError` / `UnexpectedToken` before the handler executes. Prepending `&`
is the PowerShell syntax correction. Historical hook stderr was not retained,
so this is a reproducible likely cause, not a proven reconstruction of that
specific hook invocation. The session record says `interrupted`; it does not
establish that a usage limit caused the hook error.

No managed Codex hook or configuration was changed. Evidence is saved at
`tools/.work/sepay-live/hook-reproduction.json`.
[Official hook lifecycle documentation](https://learn.chatgpt.com/docs/hooks).

## Test results

| Required check | Result |
| --- | --- |
| Clean migration chain | PASS: all 26 on PGlite and native PostgreSQL |
| Payment bank QR | PASS: 85 assertions at staged and final schema |
| Bank verification | PASS: 141 assertions at staged and final schema |
| Intent regeneration | PASS: 34 assertions at staged and final schema |
| Admin Payment V2 | PASS: 86 assertions at staged and final schema |
| System Configuration | PASS: 100 assertions at staged and final schema |
| Security RPC hardening | PASS: 252 assertions at staged and final schema |
| Native final SQL | PASS: all six suites after migration 202610150002 |
| Native concurrency | PASS: 10 simultaneous-connection scenarios |
| Bank/SePay webhook suite | PASS: 89/89, no skipped tests |
| Signed SePay-to-SQL integration | PASS: 17 deliveries, exactly 3 settlements/events |
| Customer Flutter payment tests | PASS: 156/156 |
| Customer flutter analyze | PASS: no issues |
| git diff --check | PASS |

Additional staged SQL regressions pass: core security 114, prepare 72, cash
selection 91, rescuer cash 122, realtime 27, bank foundation 170, admin read API
51. Native clean-chain coverage also runs the existing rescuer/admin suites and
catalog security audit.

Native concurrency verifies identical event, new delivery/same transaction,
competing transactions, Admin V2 reconciliation, committed-state getter,
webhook-before-regeneration, regeneration-before-webhook, configuration version
conflict, permission revocation, and initial account-control races.

Logs: `tools/.work/sepay-live/` contains `sql-integration.log`, `native-chain.log`,
`native-final-regressions.log`, `concurrency.log`, `webhook.log`,
`flutter-payment.log`, `flutter-analyze.log`, and hook reproduction evidence.
Logs are local ignored artifacts. The native chain used only the disposable
database `sepay_live_regression_20261015`; concurrency used its own random database
and cleaned it up. Existing application databases were not migrated.

Reproduction from the repository root:

```powershell
node tools/check_vietinbank_sepay.mjs
node --test backend/supabase/functions/bank-webhook/*_test.ts
& tools/check_full_backend_native.ps1 -Container supabase_db_backend -Database sepay_live_regression_20261015 -DatabaseUser supabase_admin
# For concurrency, configure GD6C_NATIVE_TEST_URL for the local administrator
# on /postgres and GD6C_PSQL_DOCKER_CONTAINER=supabase_db_backend, then:
node tools/check_payment_bank_verification_concurrency.mjs
git diff --check
```

From `frontend/customer_app`:

```powershell
flutter test --no-pub test/payment_bank_test.dart test/payment_commands_test.dart test/payment_realtime_test.dart test/payment_ui_test.dart
flutter analyze --no-pub
```

## Production readiness and TT-000011 recovery

Local code/migration regression gate: PASS. Unconditional production readiness:
NO. Current production migration history and definitions were not read in this
session, and real bank-app preservation of the complete 27-byte memo is unverified.
Check these before approving deployment. No historical migration is to be edited.

TT-000011 remains unmodified; its current status is unknown here. This migration
cannot retroactively add SEVQR to an already executed bank transfer or cause a
missing upstream transaction notification to appear. An authorized operator must
first reconcile the actual bank transaction, SePay delivery, and stored intent.
Only genuine authenticated evidence satisfying the existing original-reference,
amount, beneficiary, scope, time and replay guards can settle automatically.
Expired/terminally rejected receipts require the existing reconciliation process;
retrying a terminal duplicate does not rematch it. Do not change timestamps,
transaction IDs, snapshots or paid flags, and do not ask the customer to pay twice.

## Next live test (operator, after separate deployment authorization)

1. Confirm production predecessor history/definitions, actual Live scope and
   beneficiary settings; release the reviewed migration, webhook adapter and
   customer display/copy change together through the normal deployment process.
2. Use a fresh controlled payment/intent, separate from TT-000011. Scan its QR and
   confirm the bank app preserves the complete `SEVQR BK...` description, exact
   beneficiary and amount before authorizing any transfer. Abort if truncated.
3. Perform one authorized transfer while the intent is valid. Confirm arrival in
   SePay, a valid signed webhook, the database `paid` result and customer refresh.
4. Retry the same genuine provider transaction with fresh delivery authentication
   and unchanged transaction identity/time; confirm a duplicate outcome and only
   one payment effect/event. Do not synthesize or tamper with live bank evidence.

No deployment or commit was performed by this continuation.
