# Notifications & Monitoring V1

## Audit findings

- SePay webhook already verifies HMAC over exact bytes, validates time/direction,
  writes receipts and bank transactions in `private`, and settles through one
  atomic database processor. Before this phase, HTTP 4xx/5xx existed only in
  sanitized runtime logs and could not be queried by Admin Web.
- Rejected bank transactions and receipt result codes were retained privately.
  Payment Operations V2 exposed finance reconciliation, but there was no common
  health view across payment, webhook, rescue and security domains.
- Rescue request state and rescuer presence are authoritative in PostgreSQL.
  Online availability is fresh only while `last_seen_at` is within 120 seconds.
- Account locks/suspensions and system/admin audit records already existed. The
  system audit is immutable; direct Admin profile writes are revoked.
- `admin_notifications` is an audited broadcast record for customers/rescuers.
  It does not prove device delivery and is not an operational alert transport.

## V1 architecture

The webhook writes one append-only, private attempt record after each response.
Only provider/scope, HTTP status, an allowlisted result/stage, duration, timestamp
and optional body digest are stored. The Admin projection never returns the digest.
No raw body, header, signature, beneficiary account or secret is stored or exposed.

`admin_get_system_monitoring` is a role-guarded, read-only snapshot for
`super_admin`, `operator` and `finance`. It derives current health, incidents and
alerts from authoritative tables. `admin_acknowledge_system_alert` is limited to
`super_admin` and `operator`, validates the current alert fingerprint, serializes
concurrent acknowledgements with an advisory lock, and writes append-only audit.

## Alert rules

| Severity | Rules |
|---|---|
| CRITICAL | 3+ webhook 401 or 500 in 15 minutes; verification disabled; bank payment disabled; beneficiary/config mismatch; settlement inconsistency |
| WARNING | individual webhook 4xx; failed/incomplete receipt; rejected transaction requiring reconciliation; payment waiting beyond QR expiry + 5 minutes; failed payment; stale rescuer heartbeat |
| INFO | recent system configuration, account-control and access audit events |

Acknowledgement records receipt by an operator; it never removes or rewrites the
source event. A changed source version/fingerprint creates a new alert occurrence.

## Delivery channels

- **Admin Web:** active in V1. It polls the admin-only RPC every 60 seconds and on
  focus/manual refresh. This is the primary interactive operations surface.
- **Telegram:** recommended for CRITICAL out-of-band alerts. Add a scheduled
  server-side worker with the bot token and chat allowlist in Function Secrets.
- **Email:** recommended for WARNING/CRITICAL escalation and daily summaries. Add
  a server-side provider with credentials in Function Secrets.

Telegram/email are intentionally reported as `requires_server_configuration`.
V1 does not ship a browser token, provider credential, fake delivery state or an
automatic sender without an approved server worker and destination configuration.

## Validation

The disposable SQL regression covers clean-chain application, RPC/RBAC denial for
anon/customer/rescuer/support, finance read-only access, operator acknowledgement,
idempotent replay, immutable telemetry/audit, explicit ACLs, fixed `search_path`,
safe projections and preservation of the SePay processor. Admin Playwright covers
all six sections, filtering, detail drawer, acknowledgement, permission errors and
mobile layout.

Native multi-connection acknowledgement concurrency still needs a local native
PostgreSQL/Docker run. The current environment had no Docker daemon; the PGlite
clean-chain, advisory-lock catalog and idempotency/unique-conflict tests passed.
