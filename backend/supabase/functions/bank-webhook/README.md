# SePay bank webhook

This Supabase Edge Function accepts SePay incoming-transfer webhooks and delegates
all payment decisions to `private.process_verified_bank_transaction(jsonb)`.
Customer, rescuer, admin, anon, authenticated, and service-role API paths receive
no new ability to settle payments and `private.bank_transactions` stays private.

Security sequence:

1. Enforce POST, JSON, no content encoding, 64 KiB maximum, and a read deadline.
2. Preserve the exact raw request bytes.
3. Verify `X-SePay-Signature` as HMAC-SHA256 over
   `{X-SePay-Timestamp}.{raw_body}` using `SEPAY_WEBHOOK_SECRET`, with a five-minute
   timestamp window and constant-time digest comparison.
4. Parse and validate JSON only after authentication, then accept only final
   incoming transfers and normalize the SePay transaction.
5. Only when `SEPAY_PROVIDER_SCOPE=sepay_test`, require the authenticated payload
   account to exactly equal `SEPAY_TEST_ACCOUNT_NUMBER`, then replace its test
   beneficiary with the BIN/account read server-side from
   `private.payment_bank_config`. Missing/mismatched test configuration fails closed.
6. Call the existing private PostgreSQL processor for transaction idempotency,
   exact amount/reference/currency/beneficiary/state matching, replay protection,
   and atomic settlement.

The function never logs secrets, signatures, headers, raw payloads, SQL details,
or stack traces. Authentication-failure audit is best effort and stores only the
raw-body SHA-256 digest. Operational monitoring stores only allowlisted status,
result code, processing stage, duration and optional body digest in the private
schema; the Admin API never returns the digest. A valid authenticated terminal mismatch receives SePay's
short `{"success":true}` acknowledgement; internal/incomplete processing returns
500 so the provider can retry.

Required server environment:

- `SEPAY_WEBHOOK_SECRET`: SePay webhook HMAC secret.
- `SEPAY_PROVIDER_SCOPE`: exact scope configured in
  `private.payment_bank_config.verification_scope`.
- `SEPAY_BENEFICIARY_BANK_BIN`: six-digit beneficiary BIN; the authenticated
  payload supplies the beneficiary account number for exact database matching.
- `SEPAY_TEST_ACCOUNT_NUMBER`: required only when `SEPAY_PROVIDER_SCOPE` is exactly
  `sepay_test`. It contains SePay's Test Mode account number and is never logged.
  Every other scope ignores this value and uses the authenticated webhook account
  unchanged, preserving live exact-beneficiary verification.
- `BANK_DATABASE_URL`: server-only PostgreSQL connection URL configured explicitly
  in Supabase Function Secrets; the database role must be able to call the private
  processor. Never include this credential in frontend configuration or logs.

The direct database transport uses one lazy connection. It does not expose the
private schema over PostgREST and does not use a service-role key.

The Test Mode mapping does not prove that SePay reports the real beneficiary in
Live Mode. Before enabling production settlement, run a Live Mode transfer to the
real configured account and verify exact beneficiary matching end to end. Do not
change the production bank account or set `require_beneficiary=false` for testing.

Temporary production diagnostics emit one JSON object per failure through
`console.error`, with only `category`, `provider: "sepay"`, `stage`, and optional
SQLSTATE / allowlisted error name and code. Processor SQLSTATE 22023 with the
exact known validation message adds the constant `processorReasonCode`:
`BANK_NORMALIZED_INPUT_INVALID`; arbitrary message text is never emitted.
No error messages, stacks, causes,
SQL, parameters, connection URLs, headers, payloads or account numbers are logged.
The Postgres client's default raw NOTICE logging is disabled.

Categories:

- `BANK_WEBHOOK_HMAC_FAILED`
- `BANK_WEBHOOK_PAYLOAD_INVALID`
- `BANK_WEBHOOK_DB_CONNECT_FAILED`
- `BANK_WEBHOOK_DB_PROCESSOR_FAILED`
- `BANK_WEBHOOK_INTERNAL_ERROR`

Database stages distinguish configuration/connection failure, `begin_transaction`,
`statement_timeout`, `beneficiary_mapping`, `processor_call` / `auth_audit_call`, `processor_result`,
`commit`, and `rollback`. Authentication/transport failures before the transaction
callback are classified as `connect` from known driver codes or SQLSTATE classes
08/28. Other failures before the callback are classified as `begin_transaction`.
The original `sql.begin` still manages commit and rollback. A successful rollback
does not produce another failure log; a rollback failure produces a separate log.
The handler may also emit a generic internal-error record for the same DB failure.
Use these diagnostics temporarily for the HTTP 500 investigation; remove the
diagnostic instrumentation once the investigation is complete.

Tests:

```text
node --test backend/supabase/functions/bank-webhook/*_test.ts
deno check backend/supabase/functions/bank-webhook/index.ts
```

The processor argument must use Postgres.js `transactionSql.json({...transaction})`,
not an interpolated `JSON.stringify(transaction)`: the latter is serialized again
as a JSONB string and fails the root-object contract before matching.
See `docs/sepay_webhook_22023_diagnosis.md` for the real PostgreSQL reproduction,
field-by-field contract comparison, and disposable transport regression runner.

No production deployment or configuration activation is performed by this
repository change.
