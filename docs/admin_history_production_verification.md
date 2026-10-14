# Production Admin migration history verification

Result: PASS. Production SELECT verification on 2026-10-14 returned 114/114 checks
(56 for 202610040001, 58 for 202610050001), with zero schema drift.

```text
040001_SCHEMA_MATCH = true
050001_SCHEMA_MATCH = true
```

The read-only catalog/history query found neither historical version recorded;
202610130003 is also absent from remote migration history. No history repair was
executed. No deploy, db push, application DML or migration source edit occurred.

Verifier: [verify_admin_history_readonly.sql](../backend/supabase/tests/verify_admin_history_readonly.sql).
It wraps a single comparison SELECT in a READ ONLY transaction and ROLLBACK. The
linked CLI Management API returns the last statement's results; for this execution
only that comparison SELECT was submitted. Its statement contained catalog reads
and fixed SELECT-only backfill/sequence-state queries, with no application RPC,
nextval, setval, DDL, DML or repair. The connection's transaction_read_only setting
was off; read-only behavior here is established by the submitted SQL itself.

The manifest compares exact function bodies via SHA256, signatures, argument
names/defaults, return types, language, volatility, security flags, search_path,
API EXECUTE and relation/column privileges. It checks all four Admin tables,
seven views, policies, constraints, indexes and enabled trigger identities;
five display-code columns/sequences/indexes/CHECKs/triggers; seed key mappings;
and backfill/sequence consistency without exposing row contents.

040001 originally creates eight admin_profiles columns. 050001 adds admin_code,
its index/constraint/sequence and third trigger; this verifies their combined
nine-column final contract. The five views replaced by 050001 use their final
source definitions. Trigger function names are resolved through pg_trigger.tgfoid
and rendered with the actual function schema: private.foo versus unqualified foo
is only a search_path display difference, while a public.foo target would fail.
BIGINT sequence parameters are strings in the manifest to retain full precision.

service_role EXECUTE is reported as context, not invented as a revoke obligation:
neither historical migration explicitly revokes service_role. PUBLIC/anon and
all authenticated grants/revokes specified by the source are gating checks.
Schema equivalence proves the required effects currently exist; it cannot prove
the original application timestamp or the operator who applied the SQL.

## History-only commands (provided, NOT executed)

Because both production schema-match results are true, run these from backend
for the same linked project after reviewing the report:

```powershell
cd D:\DAndroidStudioProjects\flutter_app\backend
supabase migration repair --status applied 202610040001
supabase migration repair --status applied 202610050001
supabase migration list
```

Do not include 202610130003 in repair or deployment. These commands only record
the two already-present historical schema versions; they do not replay their SQL.

## Per-object production results

| Version | Object | Result |
|---|---|---|
| 202610040001 | acl:public.admin_audit_logs | PASS |
| 202610040001 | acl:public.admin_notifications | PASS |
| 202610040001 | acl:public.admin_profiles | PASS |
| 202610040001 | acl:public.admin_rescuer_documents_view | PASS |
| 202610040001 | acl:public.admin_service_catalog | PASS |
| 202610040001 | acl:public.admin_services_view | PASS |
| 202610040001 | catalog_seed_mappings | PASS |
| 202610040001 | columns:public.admin_audit_logs | PASS |
| 202610040001 | columns:public.admin_notifications | PASS |
| 202610040001 | columns:public.admin_profiles | PASS |
| 202610040001 | columns:public.admin_rescuer_documents_view | PASS |
| 202610040001 | columns:public.admin_service_catalog | PASS |
| 202610040001 | columns:public.admin_services_view | PASS |
| 202610040001 | constraints:public.admin_audit_logs | PASS |
| 202610040001 | constraints:public.admin_notifications | PASS |
| 202610040001 | constraints:public.admin_profiles | PASS |
| 202610040001 | constraints:public.admin_service_catalog | PASS |
| 202610040001 | function:private.admin_catalog_audit | PASS |
| 202610040001 | function:private.admin_catalog_guard | PASS |
| 202610040001 | function:private.admin_change_rescuer | PASS |
| 202610040001 | function:private.admin_notification_audit | PASS |
| 202610040001 | function:private.admin_notification_guard | PASS |
| 202610040001 | function:private.admin_profile_audit | PASS |
| 202610040001 | function:private.admin_profile_guard | PASS |
| 202610040001 | function:private.admin_require_role | PASS |
| 202610040001 | function:public.admin_approve_rescuer | PASS |
| 202610040001 | function:public.admin_block_rescuer | PASS |
| 202610040001 | function:public.admin_cancel_request | PASS |
| 202610040001 | function:public.admin_get_dashboard_stats | PASS |
| 202610040001 | function:public.admin_log_action | PASS |
| 202610040001 | function:public.admin_reject_rescuer | PASS |
| 202610040001 | function:public.admin_toggle_service | PASS |
| 202610040001 | function:public.has_admin_role | PASS |
| 202610040001 | function:public.is_admin | PASS |
| 202610040001 | indexes:public.admin_audit_logs | PASS |
| 202610040001 | indexes:public.admin_notifications | PASS |
| 202610040001 | indexes:public.admin_profiles | PASS |
| 202610040001 | indexes:public.admin_service_catalog | PASS |
| 202610040001 | policies:public.admin_audit_logs | PASS |
| 202610040001 | policies:public.admin_notifications | PASS |
| 202610040001 | policies:public.admin_profiles | PASS |
| 202610040001 | policies:public.admin_service_catalog | PASS |
| 202610040001 | policies:public.rescue_services:admin | PASS |
| 202610040001 | relation:public.admin_audit_logs | PASS |
| 202610040001 | relation:public.admin_notifications | PASS |
| 202610040001 | relation:public.admin_profiles | PASS |
| 202610040001 | relation:public.admin_rescuer_documents_view | PASS |
| 202610040001 | relation:public.admin_service_catalog | PASS |
| 202610040001 | relation:public.admin_services_view | PASS |
| 202610040001 | triggers:public.admin_audit_logs | PASS |
| 202610040001 | triggers:public.admin_notifications | PASS |
| 202610040001 | triggers:public.admin_profiles | PASS |
| 202610040001 | triggers:public.admin_service_catalog | PASS |
| 202610040001 | verification_role:catalog_and_data_visibility | PASS |
| 202610040001 | view:public.admin_rescuer_documents_view | PASS |
| 202610040001 | view:public.admin_services_view | PASS |
| 202610050001 | acl:public.admin_customers_view | PASS |
| 202610050001 | acl:public.admin_quotes_view | PASS |
| 202610050001 | acl:public.admin_rescue_requests_view | PASS |
| 202610050001 | acl:public.admin_rescuers_view | PASS |
| 202610050001 | acl:public.admin_reviews_view | PASS |
| 202610050001 | backfill:public.admin_profiles | PASS |
| 202610050001 | backfill:public.customer_profiles | PASS |
| 202610050001 | backfill:public.rescue_quotes | PASS |
| 202610050001 | backfill:public.rescue_requests | PASS |
| 202610050001 | backfill:public.rescuer_profiles | PASS |
| 202610050001 | columns:public.admin_customers_view | PASS |
| 202610050001 | columns:public.admin_quotes_view | PASS |
| 202610050001 | columns:public.admin_rescue_requests_view | PASS |
| 202610050001 | columns:public.admin_rescuers_view | PASS |
| 202610050001 | columns:public.admin_reviews_view | PASS |
| 202610050001 | display_column:public.admin_profiles.admin_code | PASS |
| 202610050001 | display_column:public.customer_profiles.customer_code | PASS |
| 202610050001 | display_column:public.rescue_quotes.quote_code | PASS |
| 202610050001 | display_column:public.rescue_requests.request_code | PASS |
| 202610050001 | display_column:public.rescuer_profiles.rescuer_code | PASS |
| 202610050001 | display_constraint:public.admin_profiles | PASS |
| 202610050001 | display_constraint:public.customer_profiles | PASS |
| 202610050001 | display_constraint:public.rescue_quotes | PASS |
| 202610050001 | display_constraint:public.rescue_requests | PASS |
| 202610050001 | display_constraint:public.rescuer_profiles | PASS |
| 202610050001 | display_index:public.admin_profiles | PASS |
| 202610050001 | display_index:public.customer_profiles | PASS |
| 202610050001 | display_index:public.rescue_quotes | PASS |
| 202610050001 | display_index:public.rescue_requests | PASS |
| 202610050001 | display_index:public.rescuer_profiles | PASS |
| 202610050001 | display_trigger:public.admin_profiles | PASS |
| 202610050001 | display_trigger:public.customer_profiles | PASS |
| 202610050001 | display_trigger:public.rescue_quotes | PASS |
| 202610050001 | display_trigger:public.rescue_requests | PASS |
| 202610050001 | display_trigger:public.rescuer_profiles | PASS |
| 202610050001 | function:private.assign_display_code | PASS |
| 202610050001 | function:private.rescuer_assignment_dto | PASS |
| 202610050001 | function:private.rescuer_available_dto | PASS |
| 202610050001 | function:private.rescuer_profile_dto | PASS |
| 202610050001 | function:private.rescuer_quote_dto | PASS |
| 202610050001 | function:public.customer_request_display_codes | PASS |
| 202610050001 | function:public.format_display_code | PASS |
| 202610050001 | relation:public.admin_customers_view | PASS |
| 202610050001 | relation:public.admin_quotes_view | PASS |
| 202610050001 | relation:public.admin_rescue_requests_view | PASS |
| 202610050001 | relation:public.admin_rescuers_view | PASS |
| 202610050001 | relation:public.admin_reviews_view | PASS |
| 202610050001 | sequence:public.admin_code_seq | PASS |
| 202610050001 | sequence:public.customer_code_seq | PASS |
| 202610050001 | sequence:public.quote_code_seq | PASS |
| 202610050001 | sequence:public.request_code_seq | PASS |
| 202610050001 | sequence:public.rescuer_code_seq | PASS |
| 202610050001 | verification_role:catalog_and_data_visibility | PASS |
| 202610050001 | view:public.admin_customers_view | PASS |
| 202610050001 | view:public.admin_quotes_view | PASS |
| 202610050001 | view:public.admin_rescue_requests_view | PASS |
| 202610050001 | view:public.admin_rescuers_view | PASS |
| 202610050001 | view:public.admin_reviews_view | PASS |
