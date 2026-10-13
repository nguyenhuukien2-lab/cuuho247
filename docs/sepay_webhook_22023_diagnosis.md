# SePay webhook SQLSTATE 22023 diagnosis — 2026-10-13

## Confirmed defect and evidence

The current store passed `JSON.stringify(transaction)` into an interpolated
`::jsonb` parameter. Postgres.js 3.4.7 applies its JSON serializer to this parameter
again. PostgreSQL receives a JSONB **string**, not the required object.

Reproduced with the actual driver and actual processor on disposable local
PostgreSQL:

- Old binding: `jsonb_typeof(...) = 'string'`; processor raises SQLSTATE `22023`,
  message `BANK_NORMALIZED_INPUT_INVALID`.
- Fixed binding: `transactionSql.json({ ...transaction })`; root type `object`.
- Actual HMAC -> adapter -> store -> processor: exact match pays once; replay
  returns `duplicate_event`; mismatches are recorded as safe rejected outcomes.

The failing contract field is the root argument `p_transaction`, not a particular
SePay account, amount, reference or timestamp. This deterministic defect explains
the reported failure if production runs the inspected store version. The live
SQLSTATE alone cannot establish which validation clause fired: no real production
payload, deployed source comparison, production config or secret was accessed.

## SQL exception paths

In `202610110003_payment_bank_verification.sql`, the processor has two explicit
22023 paths: the initial JSON shape/required-field/type/format/length/authentication
validation (line 487), and conversion of amount to bigint / occurred_at to
timestamptz (line 492). Both use `BANK_NORMALIZED_INPUT_INVALID`.
The first guard rejects a non-object before matching or receipt/transaction writes.
Its native `jsonb_object_keys` / `jsonb_each` also require an object and can raise
invalid_parameter_value for scalar input; the reproduced path was the explicit
named guard above.

Provider/scope not configured or verification disabled raises `55000`, not 22023.
The settlement update conflict raises `40001`. The bank-record, audit, intent,
payment and event trigger guards use `23514` for their invariant violations;
they do not translate these to 22023. QR-generation/customer-intent helpers with
22023 paths are not called by this processor. No SQL contract change is needed.

## Field-by-field adapter / processor comparison

| Normalized field | Adapter output / source | Processor contract and result |
| --- | --- | --- |
| Root argument | Object validated in JS; previously double-serialized by store | JSONB object required; **confirmed failure before fix** |
| provider | Constant `sepay` | Lowercase identifier <=64; then exact configured provider |
| provider_scope | `SEPAY_PROVIDER_SCOPE` | Nonempty <=128; exact `verification_scope`; mismatch is 55000 |
| provider_transaction_id | Positive safe-integer payload `id`, converted to string | Nonempty string <=256 |
| provider_event_id | `transaction:` plus id | Optional string <=200; stable replay identity |
| delivery_id | Omitted | Falls back to namespaced event ID; otherwise body digest |
| amount | Positive safe-integer `transferAmount`, decimal string | Positive decimal <=19 digits, bigint cast; exact payment/intent amount |
| currency | Constant `VND` | Three uppercase letters; exact payment/intent currency |
| direction | `transferType = in` becomes `credit` | credit/debit shape; settlement requires credit |
| occurred_at | `transactionDate` becomes ISO with `+07:00` | ISO timestamp then timestamptz cast; intent/time guards remain |
| authentication_verified | Boolean true only after HMAC passes | Boolean true required |
| authentication_method | `signature` | signature/token/mtls; signature requires verified flag |
| signature_verified | Boolean true after HMAC | Boolean; true for signature method |
| raw_payload_sha256 | SHA-256 of exact raw request bytes | 64 lowercase hex characters |
| transfer_reference | Nonempty `code`, otherwise unchanged `content` <=128; longer content becomes null | Optional string <=128; exact QR snapshot content; no fuzzy matching |
| beneficiary_bank_bin | Six-digit `SEPAY_BENEFICIARY_BANK_BIN` | Optional string <=64; exact config/snapshot matching |
| beneficiary_account_number | Payload `accountNumber`, unchanged string including leading zeros | Optional string <=128; exact snapshot matching |

`referenceCode` is validated as optional provider metadata, not used as the
payment reference or transaction identity. `gateway` is validated, not inferred
into a new BIN; `subAccount` does not replace the beneficiary account.

## Test Mode versus synthetic fixtures

[Official SePay Test Mode documentation](https://developer.sepay.vn/vi/tien-ich-khac/test-mode/mo-phong-giao-dich)
describes the same webhook shape as live transactions, numeric id/amount,
UTC+7 transaction time, and optional empty code/subAccount. It does not establish
that every test account is `0000000001`.

Earlier Node SePay tests used a fake matching store, so never exercised driver
serialization. SQL regressions constructed JSONB directly, also bypassing this
transport defect. The new integration runner crosses both boundaries.

`0000000001`, BIN `970415`, and scope `sepay_test` were tested as **local hypotheses**,
not claimed as observed live configuration. All are valid normalized strings.
An account/BIN differing from the QR snapshot produces `beneficiary_mismatch`
when the earlier matching guards pass. An unmatched reference takes precedence
and produces `reference_unmatched`. A config changed since QR creation can yield
`config_mismatch`. None of these ordinary matching outcomes requires 22023.
Do not replace a production beneficiary or relax exact matching for Test Mode.

## Change and safe diagnostics

Only the store's JSONB binding changes at runtime, plus safe diagnostic metadata.
No adapter, normalized model, HMAC, settlement, migration, frontend or grant changes.
For PostgresError 22023 at processor_call/process_transaction, only an exact
allowlisted message maps to constant `processorReasonCode =
BANK_NORMALIZED_INPUT_INVALID`. No arbitrary error message, account, payload,
headers, SQL, URL, secret or stack is logged. External HTTP 500 remains generic.

## Verification

- Bank-webhook Node tests: **57/57 PASS**, including **14 SePay tests**.
- Deno 2.5.2 typecheck: entrypoint and transport runner **PASS**.
- Fresh local native chain: **21 migration files PASS** (current runner scope).
- Payment regressions: **872 assertions PASS**, including bank verification
  **141** and admin payment **51**.
- Real transport: **7 signed deliveries PASS**; six unique transactions, five
  rejected, one payment and one payment event; replay causes no second settlement.
- Native multi-connection concurrency: **4/4 PASS** (same event, same transaction
  with new delivery, competing transactions, and committed-state visibility).

Transport runner: `tools/check_sepay_postgres_transport.ts`. It reads only
`SEPAY_LOCAL_TEST_URL`, permits loopback and explicitly restricted test DB names,
and never reads `BANK_DATABASE_URL`. `--full` requires a fresh disposable database
named `sepay_transport_test_*`, with migrations applied and no bank config.
Run with Deno permissions `--allow-env --allow-net=127.0.0.1:54322
--allow-read=backend/supabase/tests/payment_bank_verification_regression.sql`.
The full test commits disposable fixtures; never point it at a shared/live DB.

## Next production action (operator only)

1. Review this fix, then deploy the corrected function yourself:
   `supabase functions deploy bank-webhook --no-verify-jwt`.
   Existing secrets remain unchanged; no SQL migration or grant change is needed.
2. Ask SePay to retry with a fresh valid signed delivery within the existing HMAC
   time window. The reproduced 22023 path persisted no receipt or transaction.
3. Check safe diagnostic categories/reason codes and private processor outcome
   through an authorized backend/operator path. HTTP 200 acknowledges processing;
   it does not imply payment was paid. Test mismatches should remain rejected.
4. If a prior delivery was already terminally processed, do not expect replay to
   rematch it after configuration changes. Use a new legitimate transaction/test
   identity with a current QR intent and exact reference/amount/beneficiary.

No production SQL, deployment, commit or production credential investigation was
performed for this change.
