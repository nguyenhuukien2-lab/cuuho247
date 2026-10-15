# System Configuration & Security V1

Status: implemented locally, 14 October 2026. No deployment or commit.

## Plan

1. Audit all three applications, canonical migrations, Admin membership, RLS and RPCs.
2. Add a private typed configuration registry, versioned singleton, immutable audit and RPC-only mutations.
3. Enforce controls at database entry points and writes, preserve payment snapshots and SePay processing.
4. Replace the Admin Settings placeholder with validated sections, confirmations and history; connect public-safe mobile configuration.
5. Run SQL authorization/validation/version tests, frontend tests, lint/build and existing payment regression suites.

## Audit

- Canonical migrations: `backend/supabase/migrations`; 23 existing migrations through Admin Payment Operations V2.
- Customer: request creation/cancellation RPCs, three reserved photo slots (5 MiB each), payment method RPCs and server-owned QR snapshots. No central settings or feature flag service.
- Rescuer: approved profile/vehicle/capability gates, singular active-job API and unique active assignment indexes; one active job. Quotes: 1–20 items, integer total 0–2147483647 VND. Cash confirmation uses an authenticated RPC.
- Admin: Settings is a placeholder. Roles are `super_admin`, `operator`, `support`, `partner_reviewer`, `finance`; active/blocked membership is authoritative, never user metadata. Existing customer blocking/rescuer suspension and Admin grants are separate legacy controls.
- Payment: `private.payment_bank_config` contains beneficiary, enablement, expiry (default 900s), verification and provider settings. Its private data must never be serialized into generic configuration. SePay credentials remain server environment secrets.
- Existing Admin mutation guard locks membership; readonly guard supports STABLE/PostgREST read-only transactions. Older functions use fixed `public` search_path; new code uses empty search_path with qualified references.

## Security references

Design follows [PostgreSQL SECURITY DEFINER guidance](https://www.postgresql.org/docs/current/sql-createfunction.html) and [Supabase database function security](https://supabase.com/docs/guides/database/functions). Credentials are outside this registry; only explicitly public fields are projected to clients.

## Implementation and RPC contracts

Migration: `202610140001_system_configuration_security_v1.sql`, additive after V2. Historical migrations and SePay webhook/processor source are unchanged.

| Object | Purpose |
|---|---|
| `private.system_config_definitions` | 30 allowlisted keys, type, limits, section, public projection and confirmation requirement |
| `private.system_config` | Singleton, global bigint version, atomically merged flat JSON map |
| `private.system_account_controls` | Account lock, timed/indefinite suspension, JWT cutoff and per-account version |
| `private.system_config_audit` | Append-only actor, server timestamp, reason, before/after and version |
| `private.system_quote_policy_snapshots` | Immutable fee/commission policy at quote issuance |

All five tables have RLS and no direct access for PUBLIC/anon/authenticated/service_role. Private helpers and the audit sequence are also revoked. Audit and quote policy UPDATE/DELETE/TRUNCATE fail even through ordinary owner DML; database/migration owners remain trusted administrators.

| RPC | Access / behavior |
|---|---|
| `get_public_system_config(p_app)` | anon/authenticated; only `customer` or `rescuer`; explicit per-app projection; version serialized as text |
| `admin_get_system_config()` | All five active Admin roles; definitions/current values/editable sections |
| `admin_apply_system_config(p_patch,p_expected_version,p_reason,p_confirm_dangerous)` | Membership lock, singleton row lock, exact global version, per-section authorization, typed/cross-field validation and atomic audit |
| `admin_list_system_config_audit(p_before_id,p_limit)` | Active Admin; descending immutable IDs, exclusive keyset cursor, max 100 rows |
| `admin_get_system_account_control(p_user_id)` | super_admin only; configured account state and existing Admin membership snapshot |
| `admin_apply_system_account_control(...)` | super_admin only; account identity lock also serializes the first insert, expected account version, reason/confirmation; own access changes rejected |
| `admin_apply_system_admin_access(...)` | super_admin only; changes existing membership role/status, exact `updated_at` concurrency guard, immutable before/after audit; own access changes rejected |

Read RPCs are STABLE and work in PostgREST read-only transactions. New definer functions fix `search_path=''`; identifiers are qualified. No role comes from user metadata. Config errors use SQLSTATE 22023; unauthorized access 42501; stale version/timestamp 40001. No stale update is automatically retried. If a response is lost, reload to reconcile server state before saving again.

Default section permissions:

| Role | Read settings/history | Customer | Rescuer | Payment & Business | Security/accounts/Admin roles |
|---|---|---|---|---|---|
| super_admin | Yes | Edit | Edit | Edit | Edit |
| operator | Yes | Edit | Edit | — | — |
| finance | Yes | — | — | Edit | — |
| support, partner_reviewer | Yes | — | — | — | — |
| customer, rescuer, blocked Admin, anon | Public projection only | — | — | — | — |

Only super_admin can change the section permission matrix; every section must retain super_admin and Security must remain exclusive to super_admin. Authorization uses the permission matrix from the row locked by the update, including after waiting for another writer. Existing Admin-profile client column INSERT/UPDATE privileges are revoked; role/status changes now go through the dedicated RPC. Trusted bootstrap/provisioning is unchanged.

## Configuration effects

- Customer: maintenance/request-enable/kill switch gate INSERT, including direct client attempts. Photo cap is enforced under the existing parent lock; existing photo reservation retries remain valid when the cap decreases. Banner is public plain text rendered by Flutter/React, never HTML.
- Rescuer: maintenance/online flags gate new presence; offline flag gates self-initiated transitions while Admin suspension still works. New-job kill gates assignment creation. Quote enable/min/max are checked on new quote INSERTs. Bank visibility only affects display and never changes bank state or authorization.
- Payment: cash enable gates new method selection; cash-confirmation flag independently gates cash settlement. Min/max apply when choosing a method. Bank enable/kill gate new intent INSERTs, including regeneration. New QR expiry updates the existing private bank config; bank-config provisioning after V1 takes the central expiry. Existing intent/reference/QR snapshots remain unchanged.
- Business: customer cancellation flag gates customer cancellation, preserving Admin cancellation. Refund flags gate new refund records; processing an existing refund remains possible. Fee/commission are stored in basis points (100 = 1%), sum at most 10000, and snapshotted on future quotes. **V1 does not add charges, deduct balances, calculate payouts, or rewrite quote/payment amounts.** Monetary accounting needs a separately specified settlement phase.
- Explicit feature flags include banner display, new quotes and bank visibility. Emergency switches independently stop new requests, new jobs and new QR intents. There is no switch that disables receipt verification or rewrites an already paid payment.

Compatibility limits are intentional: max photos 0–3 (existing slot/schema contract), max active jobs exactly 1 (existing unique indexes and singular job API), quote totals within signed int32. Changing those architectural limits requires a separate migration and app flow update.

## Sessions and account security

Restrictive `system_session_gate` policies are added alongside existing policies on RLS-enabled public application tables and storage objects. They never grant additional access. Existing exposed PL/pgSQL definer RPCs receive an entry session guard, retaining names/signatures/grants/volatility and original logic; the migration fails if an expected body cannot be instrumented. SQL Admin membership helpers also check the session. Server-only SePay processing is outside this instrumentation.

The guard rejects locked accounts, active suspensions, old/missing JWT `iat` when a token cutoff/age policy is present, and Admin AAL1 when MFA is required. Timed suspension expires automatically. Account JWT cutoff rejects tokens issued at or before the server cutoff; a subsequently issued Auth token can pass. This is application authorization, **not deletion of Supabase Auth sessions/refresh tokens**. Normal Auth refresh/sign-in stays with the existing Auth service. Maximum token age is not a maximum login-session duration.

MFA cannot be enabled unless the acting Admin already has AAL2. Policies default to current Auth behavior (`max_token_age_seconds=0`, MFA=false); successful saves must still return through the session guard, so a policy that immediately rejects the actor rolls back. Controls affect subsequent authorization checks; they do not cancel an already authorized SQL transaction or retract files previously downloaded/signed URLs already issued.

Secrets, SePay API/webhook keys, service-role keys, verification mode/provider/scope, beneficiary details and Supabase private credentials cannot be added as keys. Public config never serializes bank config. Existing frontend Supabase URL/publishable key bootstrap is separate from business settings. The Customer debug logger references service-role environment names for **redaction**, not for authorization or config delivery.

## Frontends

`/settings` replaces the placeholder with Customer / Rescuer / Payment & Business / Security. Each field displays its current server value. Forms validate before mutation, dangerous writes use native modal dialogs with keyboard focus containment, and all writes require a reason. Conflicts/ambiguous failures retain drafts but disable writes until reload. Audit supports expandable before/after data and cursor pagination. Account/role controls require super_admin. Loading/empty/error/retry and readonly views are covered in browser tests.

Both Flutter apps read only `get_public_system_config`. Their public DTO explicitly discards unknown/private keys. They refresh on startup, foreground resume and every 60 foreground seconds, ignore older versions and late disposal completions, and retain last known hints on transient errors. Defaults preserve pre-migration UI behavior; SQL is always authoritative. Maintenance/banner remain notices so existing job/request/payment screens stay reachable. New requests, photo picking, payment method/QR generation, online/offline, quote creation, cash confirmation and bank summaries consume public hints.

## Local verification

```powershell
node tools/check_admin_payment_readonly.mjs
node --test backend/supabase/functions/bank-webhook/*_test.ts

# Native runner requires a loopback admin URL and creates/removes only a random disposable DB.
$env:GD6C_NATIVE_TEST_URL='postgresql://supabase_admin:postgres@127.0.0.1:54322/postgres'
$env:GD6C_PSQL_DOCKER_CONTAINER='supabase_db_backend'
node tools/check_payment_bank_verification_concurrency.mjs

cd admin_web
npm run lint
npm run build
npx playwright test tests/system-config.spec.ts tests/payments.spec.ts

# Run in EACH frontend/customer_app and frontend/rescuer_app:
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

SQL fixtures require privileged `payment.test_mode=local_disposable`, refuse an occupied fixture namespace and roll back. No test calls SePay or a remote production database. Earlier payment suites run at their original schema stages; QR, verification, regeneration and V2 are also rerun after V1. Final-schema cash/limits/kill switches/refund behavior is covered in the new suite. Native concurrency uses `pg_stat_activity` lock/sleep barriers rather than assuming execution order.

| Verification | Result |
|---|---|
| Clean 24-migration chain + payment/Admin SQL regression | PASS; 100 V1 assertions, 1403 SQL assertion executions across stage/final suites |
| Native PostgreSQL V1 regression | PASS; final 100-assertion fixture |
| Native races: 7 payment/V2 + config/version, permission revocation, first account insert | PASS; 10 scenarios |
| Admin lint / TypeScript / Vite build | PASS |
| Settings browser tests / existing payment browser tests | PASS; 11 / 35 |
| Full Flutter tests | PASS; Customer 610 / Rescuer 206 |
| Additional policy UI tests | PASS; request creation disabled / cash confirmation disabled |
| Flutter web builds | PASS; both apps |
| Final Flutter lint / targeted policy UI regression | PASS; 134 Customer / 44 Rescuer targeted regression tests, plus additional policy widgets |
| SePay webhook unit regression | PASS; 67 tests |

Existing build notices include Vite's >500 KiB chunk advisory and Flutter's missing optional Cupertino font advisory. These do not fail builds. Android/iOS release packages and production smoke tests were not run; no deployment, migration push, commit, or production history repair was performed.
