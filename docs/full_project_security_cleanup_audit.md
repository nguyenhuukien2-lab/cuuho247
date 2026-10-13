# Full Project Security Audit and Cleanup

Date: 2026-10-13 (Asia/Bangkok)  
Repository: `D:\DAndroidStudioProjects\flutter_app`

## Executive result

The security review and cleanup are complete for the checked-out workspace. No
critical or high-severity production security finding remains open. No
production secret was found in tracked content, no frontend service-role client
was found, and no customer, rescuer, or Admin browser flow can directly mark a
bank payment paid.

No deployment or commit was performed. Existing working-tree changes were
preserved. Production security and business logic were not changed by the final
cleanup pass.

## Security

### Findings

| Item | Final result |
|---|---|
| Critical findings | **0 open** |
| High-severity findings | **0 open** |
| Production secret exposure | **Not detected** in tracked filenames/content or final credential-pattern scan |
| Frontend `service_role` | **Absent as a credential/client/authorization mechanism** |
| Direct private bank access | **Absent** from customer, rescuer, and Admin production clients |
| Admin mark-paid action | **Absent**; Admin payment API and UI are read-only |
| Rescuer bank confirmation | **Absent**; rescuer may confirm assigned cash only |
| Customer mark-paid action | **Absent**; payment refresh only re-reads authoritative server state |

The customer debug redaction helper mentions the environment variable name
`SUPABASE_SERVICE_ROLE_KEY` only so an accidentally supplied value would be
redacted from debug diagnostics. No value is present, it is not used to create a
client, and the final builds did not receive such a define. Other `service_role`
matches are negative tests or documentation.

Admin production code calls only the four read-only RPCs
`admin_get_payment_overview`, `admin_list_payments`,
`admin_get_payment_detail`, and `admin_list_bank_transactions`. The browser
does not query `private.bank_transactions`, `payments`, or `payment_events`
directly and does not expose payment mutation controls.

Bank settlement remains server-authoritative. Provider verification performs
the trusted atomic transition; QR timers, refresh actions, customer UI, rescuer
UI, and Admin UI do not infer or write `paid`. Private bank tables have no
direct `anon`/`authenticated` access.

### Fixes made during this audit

- Corrected one regression assertion that incorrectly depended on which valid
  PostgreSQL foreign-key constraint PostgreSQL 17 reports first. The assertion
  now accepts the equivalent protected assignment/payment graph outcomes.
- Hardened the native payment concurrency runner to send SQL over stdin,
  validate an optional Docker container name, bound execution time, and avoid
  exposing connection/SQL details by default.
- No production security policy, payment authorization, or business transition
  was weakened or changed.

### Remaining security work

There is no blocking code finding from this audit. Operational bank provider
activation, reconciliation/manual review, refund handling, production key
provisioning, and production deployment verification remain separate rollout
tasks. They must not be treated as implemented by this local audit.

## Cleanup

### Source cleanup

- Removed four customer analyzer issues: two unused private widgets, one unused
  password local, and one unused HTTP response local.
- Removed the unused direct dependency `cupertino_icons` from customer
  `pubspec.yaml` and `pubspec.lock`.
- Customer and rescuer analyzers are clean after the changes.

### Generated artifacts removed

- Root/app `build/` trees, including generated debug APK output.
- Customer and rescuer `.dart_tool/` trees.
- Customer and rescuer Android `.gradle/` and `.kotlin/` caches.
- Flutter generated `.flutter-plugins-dependencies` files.
- `admin_web/dist`, `admin_web/test-results`, and any Playwright report target.
- `tools/.work`, `.cache_rescuer`, `.npm_cache`, and repository-local
  `.pub-cache`.
- Two root APK copies: `cuuho247-khachhang-debug.apk` and
  `cuuho247-doitac-debug.apk`.
- Six customer backend test/analyze log files.
- Empty accidental root `package-lock.json` (there is no root `package.json`).
- Supabase CLI cache `supabase/.temp`.

The old customer `.dart_tool` backup contained Administrator-owned generated
files. It was removed with one UAC-elevated deletion scoped exactly to that
verified untracked directory. No source, tests, docs, or migrations were
deleted.

`admin_web/node_modules` was intentionally retained because the pre-existing
Vite development server is using it. It is ignored and not tracked by Git.

`.gitignore` now covers local pub/npm/temp caches, `node_modules`, build and
coverage output, test/Playwright output, `dist`, Flutter plugin metadata,
Gradle/Kotlin caches, local environment/signing material, logs, APKs, and AABs.

## Final validation

All validation commands were run before generated artifacts were removed.

### Customer

| Check | Result |
|---|---|
| `flutter test` | **PASS — 601/601** |
| `flutter analyze` | **PASS — No issues found** |
| Debug APK build with `config/supabase.dev.json` | **PASS** |

The generated customer APK was deleted during cleanup. Test output contained
non-fatal OpenStreetMap usage notices and an existing widget hit-test warning;
the suite exited successfully.

### Rescuer

| Check | Result |
|---|---|
| `flutter test` | **PASS — 203/203** |
| `flutter analyze` | **PASS — No issues found** |
| Debug APK build with `config/supabase.dev.json` | **PASS** |

The machine-wide pub cache had an ACL issue on
`shared_preferences_android-2.4.28`. The successful build used a temporary
workspace pub cache under `tools/.work`, which was deleted afterward. No
manifest or source workaround was introduced. The generated APK was deleted.

### Admin

| Check | Result |
|---|---|
| `npm test` | **PASS — 36/36 Playwright tests** |
| `npm run lint` | **PASS** |
| `npm run build` | **PASS** |

Vite emitted a non-fatal warning for a shared minified chunk over 500 kB. Build
output and Playwright artifacts were deleted. The pre-existing Vite development
server was left running and no duplicate development server was started.

### Backend and payment security

| Check | Result |
|---|---|
| Native PostgreSQL clean migration chain | **PASS — 19 migrations** |
| Payment/Admin regression assertions | **PASS — 872 assertions** |
| Admin Payment backend regression | **PASS — 51/51** |
| Payment bank-verification concurrency | **PASS — 4/4** |

The clean-chain run used a disposable native PostgreSQL database. No migration
was deployed to a remote or production database.

## Git and sensitive-file audit

- Tracked `.env`, `auth.json`, token/secret credential files: **none found**.
- Credential-value scan for Supabase secret keys and JWT-shaped values:
  **no production secret found**.
- Tracked `.pub-cache`, `node_modules`, build directories, APK/AAB files, or
  current build/test output: **none found**.
- Six historical customer `.log` files are tracked in `HEAD`; cleanup deleted
  them from the working tree and added `*.log` to ignore rules. Because this
  task must not commit or stage changes, their removal remains visible as six
  unstaged `D` entries until a future authorized commit.
- Existing and audit-created source/test/tool/doc changes remain uncommitted.
- No files were staged, committed, pushed, or deployed.

## Scope and completion

This document records the completed local full-project security audit, cleanup,
and final validation. It does not certify live infrastructure configuration or
replace production deployment, provider, device, or penetration testing.

Status: **COMPLETE for the requested local audit and cleanup.**
