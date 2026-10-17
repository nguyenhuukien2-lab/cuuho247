# Monitoring production data load investigation — 2026-10-16

## Confirmed cause and production evidence

The UI was released ahead of its database migration. Production project
`mqnnzobfzbtolvmatuwr` does not have the Monitoring RPC or its two new tables.
No deployment, migration repair, grant change, or production data write was performed.

`supabase migration list --workdir backend` from the repository root reports
26 matching local/remote migrations through `202610150002`. The only pending
migration is `backend/supabase/migrations/202610160001_notifications_monitoring_v1.sql`
(local `202610160001`, remote empty). Running the command from the root without
`--workdir backend` misses the local migrations, which are in `backend/supabase`.

A POST to `/rest/v1/rpc/admin_get_system_monitoring` with the same named
parameters as the UI returned HTTP **404**, code **PGRST202**:

> Could not find the function public.admin_get_system_monitoring(p_limit, p_window_hours) in the schema cache

This reproduction used the public anon key, not an administrator session. It
establishes the missing function, not successful authorization of an admin.
Independent production catalog queries in `BEGIN READ ONLY` confirmed:

- `public.admin_get_system_monitoring(integer,integer)`: absent.
- `public.admin_acknowledge_system_alert(text,text,uuid)`: absent.
- `private.system_webhook_attempts`: absent.
- `private.system_alert_acknowledgements`: absent.
- Migration history contains no `202610160001`.
- Referenced pre-existing tables exist: `public.payments`, `private.payment_bank_config`,
  `private.bank_transactions`, `private.payment_webhook_receipts`,
  `private.payment_reconciliation_cases`, `private.system_config`,
  `private.system_config_audit`, `private.system_account_controls`,
  `public.admin_profiles`, `public.admin_audit_logs`, `public.rescue_requests`,
  `public.rescuer_online_status`, and `public.rescuer_profiles`.
- Existing session and readonly admin guards are STABLE SECURITY DEFINER, with
  `search_path=""` and only owner EXECUTE grants.
- Aggregate admin inventory: two active `super_admin` accounts. No account IDs,
  names, email addresses, credentials, or webhook payloads were queried.

RPC EXECUTE grants and settings cannot be inspected on production for a function
that does not exist. No full column-by-column schema parity or current browser
admin identity claim is made. No permission change can fix this missing migration.

## Request and authorization contract

`src/app/router.tsx` → lazy `SystemMonitoringPage` →
`useAdminData(getSystemMonitoring)` → Supabase RPC POST:

```json
{"p_window_hours":24,"p_limit":100}
```

Local SQL signature:
`public.admin_get_system_monitoring(p_window_hours integer DEFAULT 24, p_limit integer DEFAULT 100)`
returns one JSONB object (not a table/array):
`generated_at`, `window_hours`, `can_acknowledge`, `summary`, `alerts`,
`payment_events`, `webhook_events`, `rescue_events`, `security_events`,
`delivery_channels`. Summary contains two status enums and twelve nonnegative
integer counters. Frontend types are in `src/lib/monitoringTypes.ts`.

The function is STABLE SECURITY DEFINER with an empty fixed search_path. EXECUTE
is revoked from PUBLIC, anon, authenticated and service_role, then granted only
to authenticated. Its body checks `private.system_require_session()` followed
by `private.admin_require_role_readonly(['super_admin','operator','finance'])`.
This architecture uses explicit role allowlists, not a separate `monitoring.read`
permission. UI route admission through `is_admin()` alone is insufficient.
Acknowledgement stays limited to active super_admin/operator with valid sessions.

Anonymous, customer, rescuer, support, partner_reviewer and blocked super admin
remain denied. Finance, operator and super admin are allowed to read. Private
tables remain unavailable to API roles. No RBAC or SQL function was changed by
this fix.

## Frontend correction

- Separate safe messages for permission denial, expired login, missing backend,
  temporary backend failure, and incompatible DTOs. Raw SQL/message/details/hint
  are never rendered or logged by this client.
- Missing/null/incompatible snapshots cannot silently become a healthy dashboard
  with zero counters. Valid empty arrays still render the existing empty states.
- A failed refresh hides retained metrics, timestamps, counts and detail drawer.
- Both existing Reload buttons call the loader and issue the same RPC again.

## Verification

- `node tools/check_admin_payment_readonly.mjs` (repository root): all 27 migrations,
  Monitoring SQL regression (30 assertions), cash, bank, payment operations,
  System Configuration/Security and existing read-only RPC regressions.
- `node scripts/check-monitoring-readonly.mjs` (admin_web): exact signature,
  grants, fixed search_path, DTO and full role matrix in real READ ONLY
  transactions using disposable PGlite. Specifically covers SQLSTATE 25006 risk.
- `node tools/check_vietinbank_sepay.mjs`: signed SePay/payment integration.
- `node --test backend/supabase/functions/bank-webhook/*_test.ts`: 89/89 passed.
- Full Playwright: 84/84 passed, including 20 Monitoring tests (15 added here).
  Vite was managed separately with the same test environment and browser settings
  to avoid the existing Windows webServer teardown hang; temporary config removed.
- Admin lint/build: passed. Existing unrelated lint warning in `.payment-sevqr-work`
  and existing bundle-size warning remain.
- `git diff --check`: passed with repository line-ending settings. Additional
  no-index whitespace checks cover all six files edited in this fix because the
  Monitoring files from the prior phase are still untracked.

The SQL checks use disposable PGlite PostgreSQL, not a production administrator
session. Browser tests use mocked Supabase responses. Production remains NOT READY
until the missing migration is applied in a separately authorized deployment and
the authenticated production read is verified.

## Exact next step (not performed)

Review and separately authorize application of only
`202610160001_notifications_monitoring_v1.sql` to the linked project using the
correct backend migration directory. Then verify catalog grants/search_path,
run the read RPC as an authorized admin and the denied-role checks, and press
Tải lại. Release the frontend error-handling fix through the normal authorized
deployment process. Do not bypass RBAC or repair migration history to mark an
unapplied migration as applied.
