param(
    [string]$Container = 'supabase_db_flutter_app',
    [string]$Database = 'flutter_app_security_audit',
    [string]$DatabaseUser = 'postgres'
)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$databasePattern = '^[a-z][a-z0-9_]{0,62}$'
if ($Database -notmatch $databasePattern) { throw 'Unsafe disposable database name.' }

function Invoke-DockerPsql {
    param([string[]]$Arguments)
    & docker exec $Container psql -X -q -v ON_ERROR_STOP=1 @Arguments
    if ($LASTEXITCODE -ne 0) { throw "psql failed with exit code $LASTEXITCODE" }
}

function Invoke-SqlFile {
    param(
        [string]$Path,
        [string[]]$PsqlArguments = @()
    )
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    if (-not $fullPath.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "SQL path escaped repository: $Path"
    }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw "Missing SQL file: $Path" }
    $containerPath = '/tmp/flutter_app_security_audit.sql'
    & docker cp $fullPath "${Container}:$containerPath"
    if ($LASTEXITCODE -ne 0) { throw "docker cp failed: $Path" }
    $arguments = @('-U', $DatabaseUser, '-d', $Database)
    $arguments += $PsqlArguments
    $arguments += @('-f', $containerPath)
    Invoke-DockerPsql -Arguments $arguments
}

& docker inspect -f '{{.State.Health.Status}}' $Container | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Native PostgreSQL container is unavailable: $Container" }

Write-Output "NATIVE CLEAN DATABASE: $Database"
Invoke-DockerPsql -Arguments @('-U', $DatabaseUser, '-d', 'postgres', '-c',
    "select pg_terminate_backend(pid) from pg_stat_activity where datname='$Database' and pid<>pg_backend_pid();")
Invoke-DockerPsql -Arguments @('-U', $DatabaseUser, '-d', 'postgres', '-c', "drop database if exists $Database;")
Invoke-DockerPsql -Arguments @('-U', $DatabaseUser, '-d', 'postgres', '-c', "create database $Database;")

$bootstrap = @'
create schema auth;
create schema storage;
create table auth.users(
  id uuid primary key,
  email text,
  raw_user_meta_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default clock_timestamp()
);
create function auth.uid() returns uuid language sql stable set search_path='' as $$
  select coalesce(
    nullif(pg_catalog.current_setting('request.jwt.claim.sub',true),''),
    nullif(nullif(pg_catalog.current_setting('request.jwt.claims',true),'')::jsonb->>'sub','')
  )::uuid
$$;
create table storage.buckets(
  id text primary key,
  name text not null,
  public boolean not null default false,
  file_size_limit bigint,
  allowed_mime_types text[]
);
create table storage.objects(
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id),
  name text not null,
  metadata jsonb
);
alter table storage.objects enable row level security;
grant usage on schema public,auth,storage to anon,authenticated,service_role;
grant select,insert,update,delete on storage.objects to authenticated;
'@
Invoke-DockerPsql -Arguments @('-U', $DatabaseUser, '-d', $Database, '-c', $bootstrap)

$stageTests = @{
    '202610020001_rescuer_backend_foundation.sql' = @(
        @{ Path = 'backend/supabase/tests/rescuer_local_regression.sql'; Args = @('-v', 'rescuer_local_test=1') }
    )
    '202610040001_admin_backend_foundation.sql' = @(
        @{ Path = 'admin_web/backend/supabase/tests/admin_backend_tests.sql'; Args = @('-c', "select set_config('admin.test_mode','local_disposable',false);") }
    )
    '202610050002_rescuer_manual_location_feed.sql' = @(
        @{ Path = 'backend/supabase/tests/rescuer_manual_location_regression.sql'; Args = @('-v', 'rescuer_local_test=1') }
    )
    '202610100001_payment_core_security.sql' = @(
        @{ Path = 'backend/supabase/tests/payment_core_security_regression.sql'; Args = @('-c', "set payment.test_mode='local_disposable';") }
    )
    '202610100002_payment_customer_prepare.sql' = @(
        @{ Path = 'backend/supabase/tests/payment_customer_prepare_regression.sql'; Args = @('-c', "set payment.test_mode='local_disposable';") }
    )
    '202610100003_payment_customer_select_cash.sql' = @(
        @{ Path = 'backend/supabase/tests/payment_customer_select_cash_regression.sql'; Args = @('-c', "set payment.test_mode='local_disposable';") }
    )
    '202610100004_payment_rescuer_cash.sql' = @(
        @{ Path = 'backend/supabase/tests/payment_rescuer_cash_regression.sql'; Args = @('-c', "set payment.test_mode='local_disposable';") }
    )
    '202610100005_payment_realtime.sql' = @(
        @{ Path = 'backend/supabase/tests/payment_realtime_regression.sql'; Args = @('-c', "set payment.test_mode='local_disposable';") }
    )
    '202610110001_payment_bank_foundation.sql' = @(
        @{ Path = 'backend/supabase/tests/payment_bank_foundation_regression.sql'; Args = @('-c', "set payment.test_mode='local_disposable';") }
    )
    '202610110002_payment_bank_qr.sql' = @(
        @{ Path = 'backend/supabase/tests/payment_bank_qr_regression.sql'; Args = @('-c', "set payment.test_mode='local_disposable';") }
    )
    '202610110003_payment_bank_verification.sql' = @(
        @{ Path = 'backend/supabase/tests/payment_bank_verification_regression.sql'; Args = @('-c', "set payment.test_mode='local_disposable';") }
    )
    '202610130001_admin_payment_readonly_hotfix.sql' = @(
        @{ Path = 'backend/supabase/tests/admin_payment_read_api_regression.sql'; Args = @('-c', "set payment.test_mode='local_disposable';") }
    )
    '202610130002_customer_bank_intent_regeneration.sql' = @(
        @{ Path = 'backend/supabase/tests/payment_bank_regeneration_regression.sql'; Args = @('-c', "set payment.test_mode='local_disposable';") }
    )
    '202610130003_admin_payment_operations_v2.sql' = @(
        @{ Path = 'backend/supabase/tests/admin_payment_operations_v2_regression.sql'; Args = @('-c', "set payment.test_mode='local_disposable';") }
    )
}

$migrationPaths = @()
foreach ($directory in @('backend/supabase/migrations')) {
    $migrationPaths += Get-ChildItem -LiteralPath (Join-Path $repoRoot $directory) -Filter '*.sql' -File |
        ForEach-Object { $_.FullName.Substring($repoRoot.Length + 1).Replace('\', '/') }
}
$migrationPaths = $migrationPaths | Sort-Object { [System.IO.Path]::GetFileName($_) }
foreach ($migration in $migrationPaths) {
    $name = [System.IO.Path]::GetFileName($migration)
    Invoke-SqlFile -Path $migration
    Write-Output "PASS MIGRATION $name"
    if ($stageTests.ContainsKey($name)) {
        foreach ($test in $stageTests[$name]) {
            Invoke-SqlFile -Path $test.Path -PsqlArguments $test.Args
            Write-Output "PASS REGRESSION $($test.Path)"
        }
    }
}

$catalogAudit = @'
do $audit$
begin
  if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','private') and c.relkind in ('r','p') and not c.relrowsecurity) then
    raise exception 'AUDIT_RLS_DISABLED';
  end if;
  if has_schema_privilege('anon','private','usage') or has_schema_privilege('authenticated','private','usage') then
    raise exception 'AUDIT_PRIVATE_SCHEMA_EXPOSED';
  end if;
  if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='private' and c.relkind in ('r','p','v','m') and
      (has_table_privilege('anon',c.oid,'select,insert,update,delete') or
       has_table_privilege('authenticated',c.oid,'select,insert,update,delete'))) then
    raise exception 'AUDIT_PRIVATE_TABLE_EXPOSED';
  end if;
  if has_table_privilege('anon','public.payments','insert,update,delete') or
     has_table_privilege('authenticated','public.payments','insert,update,delete') or
     has_table_privilege('anon','public.payment_events','insert,update,delete') or
     has_table_privilege('authenticated','public.payment_events','insert,update,delete') then
    raise exception 'AUDIT_PAYMENT_DIRECT_MUTATION';
  end if;
  if exists(select 1 from pg_publication_tables
    where schemaname='private' or (schemaname='public' and tablename='payment_events')) then
    raise exception 'AUDIT_PAYMENT_PUBLICATION_EXPOSURE';
  end if;
  if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','private') and p.prosecdef and
      has_function_privilege('public',p.oid,'execute')) then
    raise exception 'AUDIT_SECURITY_DEFINER_PUBLIC_EXECUTE';
  end if;
  if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','private') and p.prosecdef and not exists
      (select 1 from unnest(coalesce(p.proconfig,array[]::text[])) setting
       where setting like 'search_path=%')) then
    raise exception 'AUDIT_SECURITY_DEFINER_SEARCH_PATH_UNSET';
  end if;
end;
$audit$;
select 'NATIVE_CATALOG_SECURITY_PASS' result,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','private') and p.prosecdef) security_definer_functions,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','private') and p.prosecdef and
      p.proconfig @> array['search_path=""']) empty_search_path_functions,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','private') and p.prosecdef and
      p.proconfig @> array['search_path=public']) fixed_public_search_path_functions;
'@
Invoke-DockerPsql -Arguments @('-U', $DatabaseUser, '-d', $Database, '-c', $catalogAudit)
Write-Output 'PASS NATIVE CLEAN CHAIN AND CATALOG SECURITY AUDIT'
