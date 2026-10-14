// Disposable PGlite/PostgreSQL regression. No remote database or credentials.
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const root = process.cwd();
const read = async path => (await readFile(resolve(root, path), 'utf8')).replace(/^\uFEFF/, '');
const dist = resolve(root, '.cache_rescuer/temp/payment-core-security/node_modules/@electric-sql/pglite/dist');
const { PGlite } = await import(pathToFileURL(resolve(dist, 'index.js')));
const { pgcrypto } = await import(pathToFileURL(resolve(dist, 'contrib/pgcrypto.js')));
const db = new PGlite({ extensions: { pgcrypto } });
const adminTest = 'backend/supabase/tests/admin_payment_read_api_regression.sql';
const hotfix = '202610130001_admin_payment_readonly_hotfix.sql';
const stageTests = new Map([
  ['202610100001_payment_core_security.sql', 'payment_core_security_regression.sql'],
  ['202610100002_payment_customer_prepare.sql', 'payment_customer_prepare_regression.sql'],
  ['202610100003_payment_customer_select_cash.sql', 'payment_customer_select_cash_regression.sql'],
  ['202610100004_payment_rescuer_cash.sql', 'payment_rescuer_cash_regression.sql'],
  ['202610100005_payment_realtime.sql', 'payment_realtime_regression.sql'],
  ['202610110001_payment_bank_foundation.sql', 'payment_bank_foundation_regression.sql'],
  ['202610110002_payment_bank_qr.sql', 'payment_bank_qr_regression.sql'],
  ['202610110003_payment_bank_verification.sql', 'payment_bank_verification_regression.sql'],
  ['202610130003_admin_payment_operations_v2.sql', 'admin_payment_operations_v2_regression.sql'],
]);

async function suite(path) {
  const out = await db.exec(await read(path));
  const result = out.flatMap(x => x.rows ?? []).find(x => typeof x.result === 'string' && x.result.endsWith('_PASS'));
  assert(result, `No PASS summary: ${path}`);
  console.log('PASS', path, result.assertions, 'assertions');
  return result;
}

try {
  await db.exec(`
    create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
    create schema auth; create schema storage;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',created_at timestamptz default now());
    create function auth.uid() returns uuid language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),
      nullif(current_setting('request.jwt.claims',true),'')::jsonb ->> 'sub')::uuid $$;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text,metadata jsonb);
    alter table storage.objects enable row level security;
    grant usage on schema public,auth,storage to anon,authenticated,service_role;
    grant select,insert,update,delete on storage.objects to authenticated;
    set payment.test_mode='local_disposable';`);

  const migrations = [];
  for (const dir of ['backend/supabase/migrations']) {
    for (const name of await readdir(resolve(root, dir))) {
      if (name.endsWith('.sql')) migrations.push(`${dir}/${name}`);
    }
  }
  migrations.sort((a, b) => a.split('/').at(-1).localeCompare(b.split('/').at(-1)));
  const signatures = [
    'public.admin_get_payment_overview(timestamptz,timestamptz,text)',
    'public.admin_list_payments(text,text,text,timestamptz,timestamptz,numeric,numeric,integer,jsonb)',
    'public.admin_get_payment_detail(uuid)',
    'public.admin_list_bank_transactions(text,text,text,text,timestamptz,timestamptz,numeric,numeric,integer,jsonb)',
  ];
  const calls = [
    "select public.admin_get_payment_overview(null,null,'day')",
    'select public.admin_list_payments(null,null,null,null,null,null,null,50,null)',
    "select public.admin_get_payment_detail('00000000-0000-0000-0000-000000000000'::uuid)",
    'select public.admin_list_bank_transactions(null,null,null,null,null,null,null,null,50,null)',
  ];
  const contractSql = `select proargtypes::text args,prorettype::regtype::text return_type,
    provolatile,prosecdef,proconfig,proacl from pg_proc where oid=$1::regprocedure`;
  let contractBefore;
  console.log('ENGINE', (await db.query('select version() v')).rows[0].v);
  for (const path of migrations) {
    if (path.endsWith(hotfix)) {
      contractBefore = await Promise.all(signatures.map(async sig => (await db.query(contractSql, [sig])).rows[0]));
      // PostgREST marks a STABLE RPC transaction read-only, even for HTTP POST.
      // The existing suite uses a writable fixture transaction, so reproduce that mode here.
      await db.exec(`insert into auth.users(id,email) values
        ('a1300000-0000-4000-8000-000000000001','readonly-admin-payment@example.invalid');
        insert into public.admin_profiles(id,full_name,role,status) values
        ('a1300000-0000-4000-8000-000000000001','Readonly admin payment','finance','active');`);
      await db.exec(`begin read only;
        select set_config('request.jwt.claim.sub','a1300000-0000-4000-8000-000000000001',true);
        set local role authenticated;`);
      try {
        await db.exec(calls[0]);
        assert.fail('Baseline overview unexpectedly succeeded');
      } catch (e) {
        assert.equal(e.code, '25006', `Baseline must reproduce read-only transaction error: ${e.message}`);
      }
      await db.exec('rollback');
      console.log('PASS baseline reproduces SQLSTATE 25006');
    }
    await db.exec(await read(path));
    console.log('PASS migration', path);
    const test = stageTests.get(path.split('/').at(-1));
    if (test) await suite(`backend/supabase/tests/${test}`);
  }

  for (const signature of signatures) {
    const { rows } = await db.query(`select provolatile, prosecdef, pg_get_functiondef(oid) definition
      from pg_proc where oid=$1::regprocedure`, [signature]);
    assert.equal(rows[0].provolatile, 's');
    assert.equal(rows[0].prosecdef, true);
    assert.match(rows[0].definition, /private\.admin_require_role_readonly\(/);
    assert.doesNotMatch(rows[0].definition, /perform private\.admin_require_role\(/);
  }
  const contractAfter = await Promise.all(signatures.map(async sig => (await db.query(contractSql, [sig])).rows[0]));
  assert.deepEqual(contractAfter, contractBefore, 'RPC signatures, volatility, security, settings and ACL must stay unchanged');
  const guard = await db.query(`select provolatile,pg_get_functiondef(oid) definition from pg_proc
    where oid='private.admin_require_role_readonly(text[])'::regprocedure`);
  assert.equal(guard.rows[0].provolatile, 's');
  assert.doesNotMatch(guard.rows[0].definition, /for share|for update|insert into|update public|delete from/i);
  const guardAcl = await db.query(`select has_function_privilege('anon','private.admin_require_role_readonly(text[])','execute') anon,
    has_function_privilege('authenticated','private.admin_require_role_readonly(text[])','execute') authenticated`);
  assert.equal(guardAcl.rows[0].anon, false);
  assert.equal(guardAcl.rows[0].authenticated, false);
  await suite(adminTest);
  await db.exec(`begin read only;
    select set_config('request.jwt.claim.sub','a1300000-0000-4000-8000-000000000001',true);
    set local role authenticated;`);
  for (const [i, sql] of calls.entries()) {
    const out = await db.exec(sql);
    assert(out[0].rows?.length === 1, `RPC ${signatures[i]} did not execute`);
    console.log('PASS read-only admin execution', signatures[i]);
  }
  await db.exec('rollback');
  console.log('PASS clean migration chain, Admin Payment and related payment regressions');
} catch (e) {
  console.error('FAIL', e.message, 'SQLSTATE', e.code, 'CONTEXT', e.where);
  process.exitCode = 1;
} finally {
  await db.close();
}
