FINAL GATE: PASS

Remediation gate completed on 2026-10-15. Production-ready: YES, for the pending migration pair 202610140001 then 202610150001. Production is still pre-hardening: this result establishes readiness, not that the fixes are deployed. No deployment, db push, commit, production mutation, or access to the protected STITCH report was performed.

All four original blockers are resolved. The previous findings are preserved in REPORT.previous-gate.md. Original baseline hashes remain in reviewed-files.sha256.json; final reviewed files and hashes are in reviewed-files.txt and reviewed-files.final.sha256.json.

| Area | Result | Final evidence |
|---|---|---|
| Display-code RPC | PASS | Active customer can read own request; another customer cannot read it; locked/suspended and anonymous callers denied. Ownership and bounded request filtering preserved. |
| Nearby-provider RPC | PASS | Exact production signature/definition reviewed; active customer allowed, anonymous/rescuer/locked/suspended denied; empty fixed search_path with qualified objects; explicit authenticated-only EXECUTE. Private name/phone/plate fields withheld. |
| Legacy RPC audit | PASS | Every authenticated application RPC exercised for locked/suspended customer/rescuer; invoker review RPC denied by RLS with valid input. All 102 canonical application definers have fixed search_path. Public config is the intentional anonymous entrypoint. |
| Configuration | PASS | All 30 configurations; V1 100 assertions and extended matrix 205 assertions. Hardening suite adds 252 assertions including permission-array negative/positive cases. |
| RBAC | PASS | Super admin and permitted admin intended operations succeed; restricted admin, customer, rescuer, anonymous and blocked accounts denied as appropriate. MFA/JWT enforcement remains fail closed. |
| Real concurrency | PASS | All 11 native two-connection races; lock/sleep barriers observed through pg_stat_activity. |
| Clean chain | PASS | Actual supabase db reset --local applied all 25 migrations. Local history matches. |
| Payment/SePay | PASS | Payment core, cash, bank QR/verification/regeneration, Admin Payment V2, payment reads, native backend and concurrency regressions; SePay webhook 67/67. |
| Admin | PASS | Lint, build, full Playwright 54/54; separate Settings 13/13. Both final browser commands exited normally with code 0. |
| Customer | PASS | Flutter analyze, 611 tests, web build. |
| Rescuer | PASS | Flutter analyze, 207 tests, web build. |
| Production preflight | PASS | 13 read-only checks: 23 predecessors aligned, two pending migrations ordered, captured legacy state unchanged, bank configuration fingerprint unchanged, SePay Live and beneficiary verification enabled. |
| Diff/secret checks | PASS | git diff --check; 238 frontend source/generated text files scanned with no secret findings. |

Security fixes and scope:

- The new migration backend/supabase/migrations/202610150001_system_security_rpc_hardening.sql adds authoritative session/account-state checks to customer_request_display_codes(uuid[]) and get_nearby_providers(double precision,double precision,double precision). PUBLIC, anon and service_role EXECUTE are revoked on both; authenticated receives only the checked entrypoints. The nearby function also requires a customer profile and rejects rescuer identities.
- The production-only nearby definition and provider schema are guarded against the exact observed state. Unknown overloads or bodies abort; an unchanged rerun succeeds. Clean installations without the legacy provider table return an empty result. Existing production-shaped providers still produce safe discovery rows; the existing client supports a missing-name fallback.
- Read-only investigation confirmed an additional route to the same PII: legacy providers had public SELECT policy and broad client table/column privileges. The new migration revokes direct client access. There are no current application callers of direct providers DML. No provider rows are removed or rewritten.
- Only the pending V1 migration was corrected for permission arrays. JSON null, SQL-array null converted to JSON, non-string values, empty/invalid identifiers and duplicates are rejected. Valid allowlisted arrays remain accepted. Application validation also rejects null/invalid/duplicate entries. The existing contract is permission-to-role arrays; it was not broadened into new permission identifiers.
- Settings navigation used a generic test RPC response with the wrong shape. General and dedicated browser fixtures now share the actual config contract. Runtime parsing converts malformed responses into a recoverable error, with retry covered. Router, lazy route and RBAC visibility were reviewed and preserved. Playwright starts Vite directly to avoid the Windows npm child-process teardown chain.
- New test files: backend/supabase/tests/system_security_rpc_hardening_regression.sql and admin_web/tests/systemConfigFixtures.ts. Modified existing files: pending V1 migration, admin_web/src/lib/systemConfigApi.ts, admin_web/tests/admin.spec.ts, admin_web/tests/system-config.spec.ts and admin_web/playwright.config.ts. Gate harnesses, verifier SQL and logs are under admin_web/production-gate.
- Baseline comparison in fix-change-scope.json confirms applied historical migrations, payment/webhook implementation and Flutter source were unchanged. No service-role secret or private security configuration was found in the frontends. Public values remain registry-allowlisted. No direct client DML against config, RBAC, audit or account-control tables was found.

Configuration coverage retains type/range/null/default/public-private/dangerous classification checks, version guards and immutable audit. Maintenance, request/online kill switches, cash/bank visibility, amount/quote bounds and auth controls pass. Photos remain capped at 3, active jobs at 1, QR expiry at 60–86400 seconds, and combined fees/commission at 10000 basis points. Config mutation cannot mark a payment paid or bypass payment verification/rescue authorization. Account controls preserve accounts, data and prior audit.

| Real race | Result |
|---|---|
| Identical delivery/event | One settlement |
| New delivery, same transaction | One settlement |
| Competing transactions for one payment | One settlement |
| Admin V2 reconciliation | One immutable resolution; payment unchanged |
| Getter during settlement | Committed authoritative state only |
| Webhook before QR regeneration | Reconciliation required |
| QR regeneration before old webhook | Old receipt cannot settle new intent |
| Same config version | One winner; 40001 stale loser; one version increment and audit; no lost update |
| Permission revocation vs waiting operator | Operator denied after lock; no unauthorized audit |
| Concurrent initial account control | One insert/version/audit; stale loser |
| Same admin membership timestamp | One role-change winner; stale loser; one audit |

Concurrency ran only on randomly named disposable loopback PostgreSQL databases. Evidence: fix-native-final.log. The native harness retains synchronization assertions and uses longer holds for the Windows/Docker environment. The final permission-null probe is false (rejected).

The production-shaped upgrade test installs the exact captured legacy function and matching PostGIS schema with synthetic data before applying the pending pair. Both V1 and hardening suites pass, plus 6 privacy assertions. Hashes prove provider rows and existing bank configuration remain unchanged. An idempotent rerun passes; intentionally unknown overload/definition tests correctly abort. Evidence: fix-legacy-final.log and its stderr (expected guard exceptions).

Other final evidence:

- fix-reset.log / fix-reset.stderr.log: full clean local reset.
- fix-payment-sql.log: staged/final payment SQL suites.
- fix-full-native.log: native full backend, rescuer and Admin regressions.
- fix-webhook.log: 67 webhook tests.
- fix-admin-final.log / fix-settings-final.log: full and dedicated browser suites.
- fix-customer-analyze.log / fix-customer-tests.log / fix-customer-build.log: customer checks.
- fix-rescuer-analyze.log / fix-rescuer-tests.log / fix-rescuer-build.log: rescuer checks.
- hardening-verifier.sql: BEGIN READ ONLY catalog/config-fingerprint verifier generated before hardening; hardening-before.json and hardening-after.json record the unchanged production state.
- provider-access-before.json: confirmed legacy direct-table access defect.
- hardening-preflight-result.json: all 13 production/local history checks pass.
- fix-production-history.json / fix-local-history.json / expected-migration-history.md: 23 production predecessors applied, 202610140001 and 202610150001 pending in production, all 25 applied locally.

No real bank transfer or production mutation was performed. Flutter validation covers the requested web builds, not native release packaging. Nonfatal build advisories do not affect these passing checks. Remaining blockers: none within the requested gate. Deploy the pending migrations together in order when separately authorized; no deployment was performed by this task.
