// Builds a standalone, read-only SQL verifier from the canonical clean LOCAL catalog.
// Reads local catalogs only; never connects to production or changes any database.
// Output is stdout, so the caller can review/apply_patch the generated artifact.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const container = process.argv[2] ?? 'supabase_db_backend';
assert.equal(container, 'supabase_db_backend', 'Only the known local Supabase container is accepted');
const versions = ['202610040001', '202610050001'];
const paths = ['backend/supabase/migrations/202610040001_admin_backend_foundation.sql',
  'backend/supabase/migrations/202610050001_display_codes.sql'];
const sources = await Promise.all(paths.map(async path => (await readFile(path, 'utf8')).replace(/^\uFEFF/, '').replace(/\r\n/g, '\n')));
const q = value => "'" + value.replace(/'/g, "''") + "'";
const functions = sources.flatMap((source, i) => [...source.matchAll(
  /create (?:or replace )?function\s+((?:public|private)\.\w+)\(([\s\S]*?)\)\s*returns[\s\S]*?\bas\s*\$\$([\s\S]*?)\$\$;/gi,
)].map(match => ({ version: versions[i], name: match[1], body: match[3] })));
assert.equal(functions.length, 24, 'All 17 Admin and 7 display-code functions must be included');
const adminTables = ['admin_profiles', 'admin_audit_logs', 'admin_notifications', 'admin_service_catalog'];
const views040 = ['admin_services_view', 'admin_rescuer_documents_view'];
const views050 = ['admin_rescue_requests_view', 'admin_customers_view', 'admin_rescuers_view', 'admin_quotes_view', 'admin_reviews_view'];
const relations = [...adminTables.map(name => [versions[0], name, true]),
  ...views040.map(name => [versions[0], name, false]), ...views050.map(name => [versions[1], name, false])];
const display = [
  ['customer_profiles', 'customer_code', 'customer_code_seq', 'KH'],
  ['rescuer_profiles', 'rescuer_code', 'rescuer_code_seq', 'DT'],
  ['rescue_requests', 'request_code', 'request_code_seq', 'CH'],
  ['rescue_quotes', 'quote_code', 'quote_code_seq', 'BG'],
  ['admin_profiles', 'admin_code', 'admin_code_seq', 'AD'],
];

// This query is also embedded verbatim in the production script. Missing objects
// produce [] / null observations instead of aborting the comparison.
const observation = `
with relations(version, name, is_table) as (values
  ${relations.map(([v, n, t]) => `(${q(v)}, ${q(n)}, ${t})`).join(',\n  ')}
), function_names(version, qualified_name) as (values
  ${functions.map(f => `(${q(f.version)}, ${q(f.name)})`).join(',\n  ')}
), display(table_name, column_name, sequence_name, prefix) as (values
  ${display.map(row => '(' + row.map(q).join(', ') + ')').join(',\n  ')}
), observations as (
select r.version, 'relation:public.'||r.name as object, (select jsonb_build_object(
  'kind',c.relkind,'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity,
  'options',coalesce(to_jsonb(c.reloptions),'[]'::jsonb),
  'trusted_owner',not exists(select 1 from pg_roles ro where ro.oid=c.relowner and ro.rolname in ('anon','authenticated','service_role')))
  from pg_class c where c.oid=to_regclass('public.'||r.name)) as actual from relations r
union all
select r.version, 'columns:public.'||r.name, (select coalesce(jsonb_agg(jsonb_build_object(
  'name',a.attname,'type',format_type(a.atttypid,a.atttypmod),'not_null',a.attnotnull,
  'default',pg_get_expr(d.adbin,d.adrelid),'identity',a.attidentity,'generated',a.attgenerated)
  order by a.attnum),'[]'::jsonb) from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum
  where a.attrelid=to_regclass('public.'||r.name) and a.attnum>0 and not a.attisdropped) from relations r
union all
select r.version, 'constraints:public.'||r.name, (select coalesce(jsonb_agg(jsonb_build_object(
  'name',c.conname,'type',c.contype,'definition',pg_get_constraintdef(c.oid,false),
  'validated',c.convalidated,'deferrable',c.condeferrable,'deferred',c.condeferred)
  order by c.conname),'[]'::jsonb) from pg_constraint c where c.conrelid=to_regclass('public.'||r.name))
  from relations r where r.is_table
union all
select r.version, 'indexes:public.'||r.name, (select coalesce(jsonb_agg(jsonb_build_object(
  'name',c.relname,'definition',pg_get_indexdef(i.indexrelid),'valid',i.indisvalid,
  'ready',i.indisready,'unique',i.indisunique,'primary',i.indisprimary)
  order by c.relname),'[]'::jsonb) from pg_index i join pg_class c on c.oid=i.indexrelid
  where i.indrelid=to_regclass('public.'||r.name)) from relations r where r.is_table
union all
select r.version, 'policies:public.'||r.name, (select coalesce(jsonb_agg(jsonb_build_object(
  'name',p.polname,'command',p.polcmd,'permissive',p.polpermissive,
  'roles',(select jsonb_agg(case when x=0 then 'PUBLIC' else pg_get_userbyid(x)::text end order by x)
    from unnest(p.polroles) x),'using',pg_get_expr(p.polqual,p.polrelid),
  'check',pg_get_expr(p.polwithcheck,p.polrelid)) order by p.polname),'[]'::jsonb)
  from pg_policy p where p.polrelid=to_regclass('public.'||r.name)) from relations r where r.is_table
union all
select '202610040001', 'policies:public.rescue_services:admin', (select coalesce(jsonb_agg(jsonb_build_object(
  'name',p.polname,'command',p.polcmd,'permissive',p.polpermissive,
  'roles',(select jsonb_agg(case when x=0 then 'PUBLIC' else pg_get_userbyid(x)::text end order by x)
    from unnest(p.polroles) x),'using',pg_get_expr(p.polqual,p.polrelid),
  'check',pg_get_expr(p.polwithcheck,p.polrelid)) order by p.polname),'[]'::jsonb)
  from pg_policy p where p.polrelid=to_regclass('public.rescue_services') and p.polname like 'admin\\_%' escape '\\')
union all
select r.version, 'triggers:public.'||r.name, (select coalesce(jsonb_agg(jsonb_build_object(
  'name',t.tgname,'definition',regexp_replace(pg_get_triggerdef(t.oid,false),'EXECUTE FUNCTION [^(]+',
    'EXECUTE FUNCTION '||(select format('%I.%I',n.nspname,p.proname) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.oid=t.tgfoid)),
  'enabled',t.tgenabled)
  order by t.tgname),'[]'::jsonb) from pg_trigger t where t.tgrelid=to_regclass('public.'||r.name) and not t.tgisinternal)
  from relations r where r.is_table
union all
select r.version, 'view:public.'||r.name, (select to_jsonb(pg_get_viewdef(c.oid,false))
  from pg_class c where c.oid=to_regclass('public.'||r.name) and c.relkind='v') from relations r where not r.is_table
union all
select r.version, 'acl:public.'||r.name, (select jsonb_build_object(
  'explicit_api_acl',(select coalesce(jsonb_agg(jsonb_build_object('role',case when e.grantee=0 then 'PUBLIC' else pg_get_userbyid(e.grantee)::text end,
    'privilege',e.privilege_type,'grantable',e.is_grantable) order by e.grantee,e.privilege_type),'[]'::jsonb)
    from aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) e
    where e.grantee=0 or e.grantee in (select oid from pg_roles where rolname in ('anon','authenticated'))),
  'column_api_acl',(select coalesce(jsonb_agg(jsonb_build_object('column',a.attname,
    'role',case when e.grantee=0 then 'PUBLIC' else pg_get_userbyid(e.grantee)::text end,
    'privilege',e.privilege_type,'grantable',e.is_grantable) order by a.attnum,e.grantee,e.privilege_type),'[]'::jsonb)
    from pg_attribute a cross join lateral aclexplode(a.attacl) e
    where a.attrelid=c.oid and not a.attisdropped and (e.grantee=0 or e.grantee in (select oid from pg_roles where rolname in ('anon','authenticated')))),
  'effective_api_acl',(select jsonb_agg(jsonb_build_object('role',ro.rolname,'privilege',pr,
    'allowed',has_table_privilege(ro.oid,c.oid,pr)) order by ro.rolname,pr)
    from pg_roles ro cross join unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) pr
    where ro.rolname in ('anon','authenticated')))
  from pg_class c where c.oid=to_regclass('public.'||r.name)) from relations r
union all
select f.version, 'function:'||f.qualified_name, (select coalesce(jsonb_agg(jsonb_build_object(
  'signature',n.nspname||'.'||p.proname||'('||oidvectortypes(p.proargtypes)||')',
  'arguments',pg_get_function_arguments(p.oid),'result',pg_get_function_result(p.oid),
  'language',l.lanname,'definer',p.prosecdef,'volatility',p.provolatile,'strict',p.proisstrict,
  'config',coalesce(to_jsonb(p.proconfig),'[]'::jsonb),'body_sha256',encode(sha256(convert_to(replace(p.prosrc,E'\\r\\n',E'\\n'),'UTF8')),'hex'),
  'trusted_owner',not exists(select 1 from pg_roles ro where ro.oid=p.proowner and ro.rolname in ('anon','authenticated','service_role')),
  'public_execute',exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) e where e.grantee=0 and e.privilege_type='EXECUTE'),
  'anon_execute',has_function_privilege((select oid from pg_roles where rolname='anon'),p.oid,'EXECUTE'),
  'authenticated_execute',has_function_privilege((select oid from pg_roles where rolname='authenticated'),p.oid,'EXECUTE'),
  'api_execute_grant_option',exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) e
    where e.is_grantable and (e.grantee=0 or e.grantee in (select oid from pg_roles where rolname in ('anon','authenticated')))))
  order by p.oid),'[]'::jsonb) from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
  where n.nspname||'.'||p.proname=f.qualified_name and p.prokind='f') from function_names f
union all
select '202610050001', 'display_column:public.'||x.table_name||'.'||x.column_name, (select jsonb_build_object(
  'type',format_type(a.atttypid,a.atttypmod),'not_null',a.attnotnull,'default',pg_get_expr(d.adbin,d.adrelid),
  'identity',a.attidentity,'generated',a.attgenerated) from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum
  where a.attrelid=to_regclass('public.'||x.table_name) and a.attname=x.column_name and not a.attisdropped) from display x
union all
select '202610050001', 'display_constraint:public.'||x.table_name, (select jsonb_build_object(
  'definition',pg_get_constraintdef(c.oid,false),'validated',c.convalidated)
  from pg_constraint c where c.conrelid=to_regclass('public.'||x.table_name) and c.conname=x.table_name||'_'||x.column_name||'_format') from display x
union all
select '202610050001', 'display_index:public.'||x.table_name, (select jsonb_build_object(
  'definition',pg_get_indexdef(i.indexrelid),'valid',i.indisvalid,'ready',i.indisready,'unique',i.indisunique)
  from pg_index i join pg_class c on c.oid=i.indexrelid
  where i.indrelid=to_regclass('public.'||x.table_name) and c.relname=x.table_name||'_'||x.column_name||'_uidx') from display x
union all
select '202610050001', 'display_trigger:public.'||x.table_name, (select jsonb_build_object(
  'definition',regexp_replace(pg_get_triggerdef(t.oid,false),'EXECUTE FUNCTION [^(]+',
    'EXECUTE FUNCTION '||(select format('%I.%I',n.nspname,p.proname) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.oid=t.tgfoid)),
  'enabled',t.tgenabled)
  from pg_trigger t where t.tgrelid=to_regclass('public.'||x.table_name) and t.tgname=x.table_name||'_display_code' and not t.tgisinternal) from display x
union all
select '202610050001', 'sequence:public.'||x.sequence_name, (select jsonb_build_object(
  'type',format_type(s.seqtypid,null),'start',s.seqstart::text,'increment',s.seqincrement::text,'min',s.seqmin::text,
  'max',s.seqmax::text,'cache',s.seqcache::text,'cycle',s.seqcycle,
  'api_acl',(select jsonb_agg(jsonb_build_object('role',ro.rolname,'privilege',pr,
    'allowed',has_sequence_privilege(ro.oid,s.seqrelid,pr)) order by ro.rolname,pr)
    from pg_roles ro cross join unnest(array['USAGE','SELECT','UPDATE']) pr where ro.rolname in ('anon','authenticated')),
  'public_acl',exists(select 1 from aclexplode(coalesce(c.relacl,acldefault('S',c.relowner))) e where e.grantee=0),
  'trusted_owner',not exists(select 1 from pg_roles ro where ro.oid=c.relowner and ro.rolname in ('anon','authenticated','service_role')))
  from pg_sequence s join pg_class c on c.oid=s.seqrelid where s.seqrelid=to_regclass('public.'||x.sequence_name)) from display x
)
select version, object, actual from observations`;

function localSql(sql) {
  const r = spawnSync('docker', ['exec', '-i', container, 'psql', '-X', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres', '-f', '-'],
    { input: `begin read only; set local search_path=pg_catalog,public,private;\n${sql};\nrollback;`, encoding: 'utf8', windowsHide: true, maxBuffer: 4 * 1024 * 1024 });
  assert.equal(r.status, 0, r.stderr);
  return r.stdout.trim();
}
const expected = JSON.parse(localSql(`select jsonb_agg(to_jsonb(o) order by version,object) from (${observation}) o`));
// Reject a dirty/unrelated baseline: every function body must match exact source.
for (const f of functions) {
  const actual = expected.find(x => x.object === 'function:' + f.name).actual;
  assert.equal(actual.length, 1, `Missing/overloaded local baseline: ${f.name}`);
  assert.equal(actual[0].body_sha256, createHash('sha256').update(f.body).digest('hex'), `Local function body differs from migration: ${f.name}`);
}
assert.equal(expected.find(x => x.object === 'columns:public.admin_profiles').actual.length, 9);
assert(expected.every(x => x.actual !== null), 'Local canonical baseline must contain every object');

const dataChecks = display.map(([table, column, sequence, prefix]) => {
  const codePattern = `'^${prefix}-[0-9]{6,}$'`;
  const dataQuery = `select jsonb_build_object('rows',count(*),'invalid',count(*) filter(where
    case when ${column} ~ ${codePattern} then substring(${column} from 4)::numeric < 1 else true end),
    'duplicates',count(*)-count(distinct ${column}),
    'maximum',coalesce(max(case when ${column} ~ ${codePattern} then substring(${column} from 4)::numeric else 0 end),0)) as result from public.${table}`;
  const seqQuery = `select jsonb_build_object('last_value',last_value,'is_called',is_called) as result from public.${sequence}`;
  return `select '202610050001'::text as version, 'backfill:public.${table}'::text as object,
    jsonb_build_object('invalid',0,'duplicates',0,'sequence_covers_existing_codes',true) as expected,
    case when exists(select 1 from pg_class where oid=to_regclass('public.${table}') and relkind in ('r','p'))
      and exists(select 1 from pg_class where oid=to_regclass('public.${sequence}') and relkind='S')
      and exists(select 1 from pg_attribute where attrelid=to_regclass('public.${table}') and attname=${q(column)}
        and atttypid='text'::regtype and not attisdropped)
    then (select jsonb_build_object('invalid',(d->>'invalid')::bigint,'duplicates',(d->>'duplicates')::bigint,
      'sequence_covers_existing_codes',(s->>'last_value')::numeric >= (d->>'maximum')::numeric
        and ((s->>'is_called')::boolean or (s->>'last_value')::numeric > (d->>'maximum')::numeric))
      from (select ((xpath('/row/result/text()',query_to_xml(${q(dataQuery)},false,true,'')))[1]::text)::jsonb d,
        ((xpath('/row/result/text()',query_to_xml(${q(seqQuery)},false,true,'')))[1]::text)::jsonb s) z)
    else null end as actual`;
});
const catalogDataQuery = `select jsonb_build_object('required_seed_mappings',not exists(
  select 1 from (values ('towing','SRV-TOW-01'),('battery','SRV-BAT-02'),('tire','SRV-TYR-03'),
    ('fuel','SRV-FUL-04'),('locksmith','SRV-LCK-05'),('mechanic','SRV-MEC-06')) e(service_code,admin_code)
  where not exists(select 1 from public.admin_service_catalog a where a.service_code=e.service_code and a.admin_code=e.admin_code)),
  'every_service_has_catalog_entry',not exists(select 1 from public.rescue_services s
    where not exists(select 1 from public.admin_service_catalog a where a.service_code=s.code))) as result`;
const sql = `-- READ-ONLY production verification of Admin migration effects.
-- Generated from exact canonical SQL, validated against a clean Supabase LOCAL catalog.
-- Source SHA256 (UTF-8 LF):
${paths.map((p, i) => '-- ' + p + ' ' + createHash('sha256').update(sources[i]).digest('hex')).join('\n')}
-- 040001 creates 8 admin_profiles columns; 050001 adds admin_code (9 total).
-- 050001 replaces 5 foundation views; compare their final definitions.
-- No application RPC is executed. No CREATE/TEMP/DML/nextval/setval/repair occurs.
-- Exact body/view text is deliberately fail-closed; formatting/version differences
-- must be reviewed, never silently waived. Expected/actual values identify drift.
-- Trigger function names are schema-qualified using pg_trigger.tgfoid, so a
-- different search_path cannot cause a false match or a cosmetic mismatch.
-- service_role grants were NOT revoked by these historical migrations; inspect
-- their effective EXECUTE separately below instead of inventing new semantics.
-- Run as SQL Editor / trusted owner with BYPASSRLS; all statements are read-only.
begin transaction isolation level repeatable read read only;
set local search_path=pg_catalog,public,private;
set local statement_timeout='60s';
set local lock_timeout='5s';

with expected as (
  select x->>'version' as version, x->>'object' as object, x->'actual' as expected
  from jsonb_array_elements($manifest$${JSON.stringify(expected, null, 2)}$manifest$::jsonb) x
), actual as (${observation}), comparisons as (
  select e.version,e.object,e.expected,a.actual from expected e left join actual a using(version,object)
  union all
  ${dataChecks.join('\n  union all\n  ')}
  union all
  select '202610040001','catalog_seed_mappings',
    '{"required_seed_mappings":true,"every_service_has_catalog_entry":true}'::jsonb,
    case when exists(select 1 from pg_class where oid=to_regclass('public.admin_service_catalog') and relkind='r')
      and exists(select 1 from pg_class where oid=to_regclass('public.rescue_services') and relkind='r')
      and (select count(*) from pg_attribute where attrelid=to_regclass('public.admin_service_catalog')
        and attname in ('service_code','admin_code') and atttypid='text'::regtype and not attisdropped)=2
      and exists(select 1 from pg_attribute where attrelid=to_regclass('public.rescue_services')
        and attname='code' and atttypid='text'::regtype and not attisdropped)
    then ((xpath('/row/result/text()',query_to_xml(${q(catalogDataQuery)},false,true,'')))[1]::text)::jsonb else null end
  union all
  select v,'verification_role:catalog_and_data_visibility','true'::jsonb,
    to_jsonb(exists(select 1 from pg_roles where rolname=current_user and (rolsuper or rolbypassrls)))
    from unnest(array['202610040001','202610050001']) v
), checks as (
  select *,expected is not distinct from actual as passed from comparisons
), summary as (
  select coalesce(bool_and(passed) filter(where version='202610040001'),false) as match040,
    coalesce(bool_and(passed) filter(where version='202610050001'),false) as match050,
    count(*) as checks,count(*) filter(where not passed) as failures from checks
)
select row_kind,version,object,result,passed,details from (
  select 1 as sort,'OBJECT'::text as row_kind,version,object,case when passed then 'PASS' else 'FAIL' end as result,passed,
    case when passed then '{}'::jsonb else jsonb_build_object('expected',expected,'actual',actual) end as details from checks
  union all
  select 2,'SUMMARY','202610040001','040001_SCHEMA_MATCH',match040::text,match040,'{}'::jsonb from summary
  union all
  select 2,'SUMMARY','202610050001','050001_SCHEMA_MATCH',match050::text,match050,'{}'::jsonb from summary
  union all
  select 3,'OVERALL',null,'HISTORY_SCHEMA_VERIFICATION',case when match040 and match050 then 'PASS' else 'FAIL' end,
    match040 and match050,jsonb_build_object('checks',checks,'failures',failures,
      'history_repair_commands',case when match040 and match050 then jsonb_build_array(
        'supabase migration repair --status applied 202610040001',
        'supabase migration repair --status applied 202610050001') else '[]'::jsonb end,
      'commands_executed',false) from summary
  union all
  select 0,'CONTEXT',null,'database_and_read_only_transaction','INFO',null,
    jsonb_build_object('database',current_database(),'server_version',current_setting('server_version'),
      'read_only',current_setting('transaction_read_only'),'schema_check_is_not_proof_of_application_timestamp',true)
  union all
  select 0,'CONTEXT',null,'recorded_migration_history','INFO',null,
    coalesce((select jsonb_agg(jsonb_build_object('version',version,'name',name) order by version)
      from supabase_migrations.schema_migrations where version in ('202610040001','202610050001','202610130003')),'[]'::jsonb)
  union all
  select 0,'CONTEXT',null,'service_role_execute_not_revoked_by_original_migrations','INFO',null,
    coalesce((select jsonb_agg(jsonb_build_object('signature',n.nspname||'.'||p.proname||'('||oidvectortypes(p.proargtypes)||')',
      'execute',has_function_privilege(r.oid,p.oid,'EXECUTE')) order by n.nspname,p.proname)
      from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join pg_roles r
      where r.rolname='service_role' and n.nspname||'.'||p.proname in (
        ${functions.map(f => q(f.name)).join(',\n        ')})),'[]'::jsonb)
) report order by sort,version,object;
rollback;
`;
process.stdout.write(sql);
