# Clean Supabase migration chain

All executable migrations now live in `backend/supabase/migrations`, which is the
directory Supabase CLI reads when run from `backend`. Admin tests, seeds and
historical design documentation remain under `admin_web/backend/supabase`.

## Root cause and restored contract

The Admin foundation (`202610040001`) and display codes (`202610050001`) were
originally stored under `admin_web/backend/supabase/migrations`. Git commit
`670f3cf` introduced the Admin foundation; `17335aa` introduced display codes.
Payment test runners merged both directories, while Supabase CLI only read the
shared directory. A real clean start therefore failed at `202610120001` with
`ADMIN_PAYMENT_MISSING_PREREQUISITE: public.admin_profiles`.

Both original SQL files were relocated without changing their SQL, filenames or
version IDs. No baseline, replacement schema, conditional skip or weakened
prerequisite was introduced. There is one executable definition of each version.
The full foundation is restored, including Admin tables, views, RPCs, grants,
policies and audit triggers, followed by the original display code migration.

`public.admin_profiles` has the original nine columns: `id uuid` (PK and FK to
`auth.users`, ON DELETE CASCADE), `full_name text NOT NULL` (trimmed length 1..150),
`role text NOT NULL DEFAULT 'operator'` (super_admin/operator/support/
partner_reviewer/finance), `status text NOT NULL DEFAULT 'active'` (active/blocked),
nullable `phone text` and `avatar_url text`, `created_at` and `updated_at`
`timestamptz NOT NULL DEFAULT now()`, and `admin_code text NOT NULL` added by
display codes. `admin_code` uses `public.admin_code_seq`, a unique index and the
original positive `AD-[0-9]{6,}` format constraint. Profile guard/audit and display
code triggers remain the original definitions. RLS permits active Admin reads
and super_admin inserts/updates, with column grants and no client DELETE.
`private.admin_require_role(text[])` locks active membership FOR SHARE;
`is_admin()` and `has_admin_role(text[])` use Auth UUID membership, never metadata.

These files establish the repository origin of production's Admin contract.
The repository does not prove which operator applied them or whether production
recorded their versions. No production connection, schema mutation or history
repair is part of this change.

Native Supabase regression also exposed that V2's three receipt hashes assumed
pgcrypto lived in `public`, while Supabase installs it in `extensions`. V2 now
uses built-in `pg_catalog.sha256(bytea)` over the identical UTF-8 bytes. The
hash algorithm, request serialization and receipts remain identical; no deployed
payment/SePay migration or processor is changed.

## Production history before a future rollout

Use a read-only inventory first:

```sql
select version, name
from supabase_migrations.schema_migrations
where version in ('202610040001', '202610050001')
order by version;
```

If both versions were already recorded, relocation requires no history repair:
the CLI keys history by version, not the old repository path. If the SQL was
applied manually and versions are absent, verify the complete live schema against
these original migrations and all later changes before a separately authorized
history-only repair. Never replay the Admin foundation against existing Admin
objects; its existing preflight deliberately rejects that operation. Do not use
`db push --include-all` to force the missing historical files onto live tables.
The exact history-only commands, after that verification and authorization, are:

```powershell
supabase migration repair 202610040001 202610050001 --status applied --linked
```

Record only versions actually proved applied. This command is documentation,
not an operation performed by the local bootstrap fix.

## Local verification

Run from `backend`: `supabase stop`, `supabase start`, `supabase db reset --local`.
The reset includes `202610130003_admin_payment_operations_v2.sql`. Regression
runners now consume the same canonical migration directory. The optional legacy
`--shared-only` bank runner mode explicitly excludes the two Admin versions.
Native SQL fixtures require `payment.test_mode=local_disposable` and are rolled
back. The concurrency runner additionally requires a loopback PostgreSQL URL,
creates a random disposable database and only removes that database afterward.

Verified locally on 14/10/2026:

- Actual `supabase start` and `supabase db reset --local`: 23 migrations, through V2.
- `check_admin_payment_readonly.mjs`: 958 SQL assertions (including 86 V2).
- `check_payment_bank_verification.mjs`: 1,526 SQL assertion executions.
- V2 on the actual reset Supabase database: 86 assertions, fixtures rolled back.
- Native stage runner: 992 payment/Admin assertions, original Admin foundation
  and rescuer regressions, plus catalog security audit; all passed. Earlier-stage
  suites run at their original migration stages (for example core security expects
  no payment Realtime publication before the later Realtime migration).
- Native concurrency: seven scenarios passed, including a real overlapping
  two-connection Admin V2 race with exactly one resolution and unchanged payment.
- Display-code PostgreSQL regression and 67 SePay webhook tests passed.

For the local Supabase container, native concurrency used
`GD6C_PSQL_DOCKER_CONTAINER=supabase_db_backend` and a loopback URL with the local
`supabase_admin` role. Supabase's local `postgres` role is not a superuser and the
runner correctly refuses it; the superuser safety check was not weakened.
Only disposable test databases were removed. No production history repair,
deployment, db push or commit was performed.
