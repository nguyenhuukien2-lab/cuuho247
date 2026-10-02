-- Read-only inventory. Run in the SQL Editor of the selected DEVELOPMENT
-- project before approving the migration. No customer records or auth secrets.
select current_database() as database_name, current_user as database_role;

select n.nspname as schema_name, c.relname as table_name,
       c.relrowsecurity as rls_enabled, c.reltuples::bigint as estimated_rows
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind in ('r', 'p')
order by c.relname;

select schemaname, tablename, policyname, roles, cmd, qual, with_check
from pg_catalog.pg_policies where schemaname = 'public'
order by tablename, policyname;

select table_name, grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and grantee in ('anon', 'authenticated', 'PUBLIC')
order by table_name, grantee, privilege_type;

select n.nspname as schema_name, p.proname as function_name,
       pg_catalog.pg_get_function_identity_arguments(p.oid) as arguments,
       p.prosecdef as security_definer, p.proconfig as configuration,
       p.proacl as privileges
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('cuuho247_handle_new_customer',
                   'create_customer_rescue_request', 'cancel_own_rescue_request',
                   'cuuho247_validate_request_transition', 'cuuho247_record_request_status');

select t.tgname as trigger_name, pg_catalog.pg_get_triggerdef(t.oid) as definition
from pg_catalog.pg_trigger t
where t.tgrelid in ('auth.users'::regclass, to_regclass('public.rescue_requests'))
  and not t.tgisinternal;

select pubname, schemaname, tablename
from pg_catalog.pg_publication_tables
where pubname = 'supabase_realtime' and tablename = 'rescue_requests';
