# Admin Payment V1 backend implementation

Date: 2026-10-12. Scope: read-only Admin Payment API and `admin_web` connection. No deployment or commit was performed.

## Migration and authorization

The additive migration is `backend/supabase/migrations/202610120001_admin_payment_read_api.sql`. It depends on the payment chain through GD6C, the Admin foundation, and display codes. Existing migrations are unchanged.

All four public RPCs are `SECURITY DEFINER`, use `set search_path=''`, schema-qualify database objects, and begin with `private.admin_require_role(array['super_admin','finance'])`. This reuses the existing server-side Admin membership check against `auth.uid()` and active `public.admin_profiles`; no email, browser role, or local storage value is trusted. `PUBLIC`, `anon`, and `service_role` have no execute grant. `authenticated` has only execute permission and must still pass the per-call guard.

The browser uses the existing Supabase session and publishable/anon client. It never receives a service-role credential and never queries the private schema.

## Read contracts

- `admin_get_payment_overview(p_from, p_to, p_bucket)` returns summary counts/amounts, Vietnam-time chart buckets, and ten recent safe payment rows. Paid totals use `paid_at`; waiting/verifying state counts use `created_at`. The default range is 30 days and the maximum is 366 days.
- `admin_list_payments(...)` supports bounded search, method/status, half-open creation range, amount bounds, a clamped 1–100 limit, and stable `(created_at,id)` keyset pagination. Amounts and versions are exact decimal strings.
- `admin_get_payment_detail(p_payment_id)` returns one safe payment/request/customer/rescuer projection, method-specific cash or bank data, and a sanitized timeline. Finance can see safe names and identifiers; customer phone/email remain null. Existing super-admin/operator/support contact policy is reused.
- `admin_list_bank_transactions(...)` reads `private.bank_transactions` only inside the server function. It supports provider, verification/match result, transaction-time and amount filters plus stable `(received_at,id)` keyset pagination.

The API returns no raw payload, webhook headers, body hash, normalized hash, provider credential, auth token, signature, secret, or full beneficiary account number. The beneficiary account is masked. Timeline descriptions and result codes are selected from known server fields; unrestricted metadata is excluded.

There is no Admin payment mutation RPC. Admin cannot confirm cash, mark a bank transfer paid, edit an amount, delete a transaction, refund, or perform manual settlement. Existing payment and bank table protections remain authoritative.

## Issue count

`issue_count` is the sum, within the requested range, of:

- failed payments;
- rejected bank transactions, including unmatched reference, wrong amount, wrong beneficiary, expired/closed intent, or an already allocated payment;
- expired/failed bank intents that do not already have a corresponding rejected transaction;
- recorded bank identity conflicts.

Clean idempotent duplicate retries are excluded. A duplicate that reveals an allocation conflict can still be represented by its rejected transaction or explicit conflict audit event.

## Index review

Existing payment status/creation and request indexes and the provider transaction identity unique index were retained. The migration adds only the read-order indexes needed by these contracts: payment creation, method/creation, paid time/method, bank occurrence, bank receipt order, and bank status/receipt order.

## Frontend connection

`admin_web/src/lib/paymentApi.ts` calls the exact four RPCs and maps only allowlisted response fields into the existing UI models. UI date inputs are converted from inclusive Vietnam calendar dates to a half-open timestamp range. Overview, list, detail, and bank screens retain loading, empty, generic error, permission-denied, retry, filter, search, and cursor pagination behavior. A network error remains an error and is never translated into a payment status.

Operational mock data remains only in Playwright fixtures. Production source contains no mock endpoint, private-schema query, service-role key, or local paid mutation.

## Regression and current limitation

`backend/supabase/tests/admin_payment_read_api_regression.sql` covers anon/normal/operator denial, finance/super-admin access, overview totals and date range, list filters and keyset cursor, cash and bank detail, sanitized timeline, bank filters/cursor, sensitive-field exclusion, private-table denial, payment-update denial, and absence of an Admin payment mutation RPC.

The existing GD1, GD2A, GD2B, GD3, GD4, GD6A, and GD6B regressions pass in the local PGlite runner. The checked-in GD6C migration currently contains the invalid token `cõe` after a publication predicate. A fresh migration chain stops there with SQLSTATE `42601`, before GD6C, this migration, and its regression can execute. The task required old migrations to remain unchanged and prohibited a workaround, so the defect is documented rather than patched. Admin Payment source is implemented and frontend-connected, but backend runtime validation remains blocked until that existing GD6C source is corrected in an explicitly authorized follow-up.

No live Supabase/PostgREST environment, provider integration, deployment, refund, payout, settlement accounting, or manual settlement was added.
