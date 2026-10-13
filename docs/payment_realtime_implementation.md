# GD4 Payment Realtime — implementation and verification

Date: 2026-10-10. Continued from the existing working tree, including the GD4
watchers, services, DTOs, controller integration, migration and regression tests.
No commit and no deployment. UI and bank/QR implementation are outside this change.

## Delivery scope

Both apps now expose payment state through a controller-owned `PaymentWatcher`.
The watcher tracks one authenticated user and one request at a time. It subscribes
to INSERT/UPDATE notifications on `public.payments` and reloads the authoritative
payment DTO through the existing role-specific RPC. It never creates a payment,
selects a payment method or confirms receipt as a side effect of watching.

| App | Authoritative getter | Controller entry points |
| --- | --- | --- |
| Customer | `customer_get_payment(p_request_id)` | `loadPayment`, `watchPayment`, `refreshPayment`, `clearPayment`, `payments` |
| Rescuer | `rescuer_get_job_payment(p_request_id)` | `loadJobPayment`, `watchJobPayment`, `refreshJobPayment`, `clearJobPayment`, `payments` |

Customer request hydration, creation and tracking updates select the current
request. If there is no current selection or active request, hydration can watch
the most recent completed request. Rescuer integration watches active jobs,
completion results and selected history details; history loading supplies a
fallback when no payment request is selected. Completed-job payment reads do not
require an active job, an online rescuer session or working GPS.

This is controller/service integration. Existing payment widgets are unchanged;
GD4 does not add a paid indicator, method picker, receipt-confirmation action or
bank/QR flow. Consumers can observe `payments.payment`, `loading`, `stale` and
`error`. One selection is watched, not every item in history simultaneously.

## Data and security boundaries

- Realtime filters by `request_id`. The adapter also checks the notification's
  customer/rescuer ID against its captured authenticated user before invalidating.
  These filters are optimizations and defensive checks; database RLS authorizes
  delivery and the getter rechecks access.
- Raw websocket rows never reach the watcher as payment data. Every accepted
  snapshot comes from the getter, including after SUBSCRIBED/reconnect.
- Payment/request identity is checked. A DTO for another request or a different
  payment ID within the selected scope clears the snapshot as inaccessible.
- Amounts and versions use decimal strings parsed as `BigInt`, retaining exact
  values above JavaScript's safe integer range. Versions must be positive bigint.
- Only a strictly newer version replaces an accepted snapshot. Equal/older
  versions cannot roll a paid snapshot back. An authoritative null clears it.
- Auth/access-denied getter failures clear cached payment data. Network failures
  retain only the current scope's snapshot and mark it stale; they never fabricate
  paid state. DTO format errors receive one immediate refetch per refresh cycle.
- Getter HTTP requests have a 20-second timeout. The adapter maps authentication
  and permission errors to `PaymentAccessDenied` without exposing raw details.

## Lifecycle, retries and cleanup

The existing app lifecycle observers forward foreground changes to the
controllers, which forward them to their payment watchers.

| Trigger | Behavior |
| --- | --- |
| Initial watch | Remove the preceding subscription, connect, then read the getter |
| Same request watched again | Refresh without adding a second subscription |
| INSERT/UPDATE or SUBSCRIBED | Refetch the getter while foregrounded |
| Event during a getter call | Coalesce overlapping refreshes; perform a further read if invalidated during the call |
| Channel error/closure | Mark stale; while foregrounded, remove the old channel and reconnect after 3 seconds |
| Getter fails while websocket is still connected | Schedule a getter retry after 3 seconds; continue until success or scope/lifecycle cleanup |
| Background | Cancel reconnect/getter-retry timers; retain the subscription but suppress event-driven reads |
| Resume | Refetch immediately and schedule reconnect if disconnected |
| Same-user auth restoration/token renewal | Refetch the selected request |
| Logout or user switch | Clear DTO and request immediately; invalidate late responses and cancel timers/subscription |
| Request switch | Invalidate the previous generation and await channel removal before connecting the next scope |
| Dispose | Invalidate the generation, clear state, cancel auth/channel subscriptions and timers |

RPC futures already in flight are not forcibly cancelled; generation and owner
checks discard their results after clear, user/request changes or disposal.
Channel removal is asynchronous, while visible state clears synchronously.

The continuation added recovery for a failed getter after an event even when the
websocket remains healthy. It also reserves the refresh future before notifying
listeners: a listener may synchronously call refresh or clear without recursive
loads or leaving the next request attached to an already completed refresh task.

## Migration and publication

`backend/supabase/migrations/202610100005_payment_realtime.sql` already existed in
the unfinished GD4 tree. It is retained; this continuation creates no additional
migration and changes none of the GD1–GD3 migrations.

The migration adds only `public.payments` to `supabase_realtime`, creating the
publication if absent. Reapplying it leaves exactly one payments membership and
preserves other existing publication members. It checks prerequisite getters,
RLS/grants/policy counts and an explicit safe inventory of payment columns before
publishing. Unexpected columns or publication exposure require security review.

There are **no RLS, policy or ACL changes** in GD4, no direct client payment DML
grant and no `REPLICA IDENTITY FULL`. `payment_events` and private receipt tables
are **not published**. No client subscribes to them. The SQL suite uses existing
participant RLS and public RPCs; it does not weaken RLS to make assertions pass.

## Files belonging to GD4

The existing `.cache_rescuer/temp/gd4_baseline.json` was used to distinguish GD4
integration changes from the many earlier UI/location changes in the working tree.

| Area | Files |
| --- | --- |
| Backend | `backend/supabase/migrations/202610100005_payment_realtime.sql`; `backend/supabase/tests/payment_realtime_regression.sql` |
| Customer state | `frontend/customer_app/lib/app/app_controller.dart`; `frontend/customer_app/lib/app/payment_watcher.dart` |
| Customer transport/data | `frontend/customer_app/lib/services/supabase_service.dart`; `frontend/customer_app/lib/services/payment_service.dart`; `frontend/customer_app/lib/models/payment_dto.dart` |
| Customer regression | `frontend/customer_app/test/payment_realtime_test.dart`; `frontend/customer_app/test/backend_flow_regression_test.dart` |
| Rescuer state | `frontend/rescuer_app/lib/app/rescuer_controller.dart`; `frontend/rescuer_app/lib/app/payment_watcher.dart` |
| Rescuer transport/data | `frontend/rescuer_app/lib/services/rescuer_service.dart`; `frontend/rescuer_app/lib/services/payment_service.dart`; `frontend/rescuer_app/lib/models/payment_dto.dart` |
| Rescuer regression | `frontend/rescuer_app/test/payment_realtime_test.dart` |
| Documentation | `docs/payment_realtime_implementation.md` |

The continuation changes the two watchers and their two tests, adds this document,
and repairs the first import in `frontend/customer_app/test/request_location_test.dart`.
That test contained two accidentally pasted shell-command fragments at the start;
they were removed as text, not executed. No assertions or UI behavior were changed.
The safe `use_super_parameters` cleanup is limited to the two payment test fakes.

## Verification

| Flutter check | Final result |
| --- | --- |
| Customer `flutter test --no-pub --reporter expanded` | **485 passed**, exit 0 |
| Rescuer `flutter test --no-pub --reporter expanded` | **169 passed**, exit 0 |
| Customer `flutter analyze --no-pub` | **0 errors; 4 pre-existing warnings**, exit 1 |
| Rescuer `flutter analyze --no-pub` | **No issues**, exit 0 |
| `git diff --check` | Passed |

Customer's four unchanged warnings are in `lib/screens/login_screen.dart`:
unused `password` at line 73, unused `response` at line 86, unused `_NetworkChip`
at line 507 and unused `_SocialBtn` at line 524. No GD4 analyzer issues remain.
The analyzer exit code is not reported as clean because these warnings remain.

The initial customer run failed to compile the corrupted first import in
`request_location_test.dart`, including tests that import that file. After removing
the pasted shell text, the complete suite was rerun and passed. The failure was
not bypassed by excluding tests or weakening assertions.

Final full-suite logs are `.cache_rescuer/gd4_customer_test_final.log` and
`.cache_rescuer/gd4_rescuer_test.log`; customer analysis is recorded in
`.cache_rescuer/gd4_customer_analyze_final.log`. These are ignored local artifacts.

Both payment regression files contain 32 cases covering getter contracts,
participant filters, raw-payload distrust, pending/awaiting/paid transitions,
bigint precision, version ordering, invalid DTO retry, null responses, access
denial, reconnect, resume, user/request switches, logout/dispose, event coalescing,
listener reentry, rapid request selection and recovery after failed event reads.

SQL verification ran with PGlite 0.5.8 / PostgreSQL 18.3 in disposable RAM databases:

| Check | Result |
| --- | --- |
| Shared + admin/display-code prerequisites | 14 migrations applied |
| Shared-only prerequisites | 12 migrations applied |
| GD3 regression before GD4 | 122/122 in each configuration |
| GD4 regression, twice in each configuration | 27/27 each run |
| Apply GD4 twice | Payments published once; other members unchanged |
| Catalog comparison before/after | ACL, full policy definitions, RLS flags and replica identity unchanged |
| Missing publication, then repeat migration | Payments-only publication, one member |
| Unexpected extra payment column | Migration refuses publication with security-review error |

The SQL suite tests customer/rescuer ownership and inaccessible foreign payments,
unrelated/missing users, anonymous denial, direct mutation denial, inaccessible
events/private receipts, and visibility of GD3 cash settlement through both getters.
Fixtures roll back. Tests run only with the privileged `local_disposable` opt-in.

Run from each app directory:

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
```

The existing ignored local harness can reproduce the RAM verification from the
repository root (its PGlite dependencies are already installed in that cache):

```powershell
node .cache_rescuer/temp/payment-core-security/run_payment_realtime.mjs
node .cache_rescuer/temp/payment-core-security/run_payment_realtime.mjs --shared-only
```

On a separately verified disposable PostgreSQL database with prerequisites and
GD4 applied, the versionable regression suite can instead run via `psql -X -v
ON_ERROR_STOP=1`, using one connection:

```sql
SET payment.test_mode = 'local_disposable';
\i backend/supabase/tests/payment_realtime_regression.sql
```

## Verified limits and deployment status

The Dart tests exercise the real payment adapter with mocked HTTP and realtime
channels. PGlite executes PostgreSQL migrations, RLS, RPCs and publication catalog
checks, but does not run a Supabase Realtime websocket server.

Docker's local Linux engine is unavailable (`dockerDesktopLinuxEngine` pipe not
found). No end-to-end websocket/JWT delivery, device suspend/resume or multi-client
live test was run. Source and automated local behavior are implemented; delivery
through a deployed Supabase service remains unverified. Production publication
membership has not been inspected or changed.

No remote migration, deployment or commit was performed. `payment_events` remains
outside the GD4 publication. The next environment verification is to apply the
reviewed migration to an explicitly selected environment and test two authenticated
participants, an unrelated user, reconnect/resume and logout there.
