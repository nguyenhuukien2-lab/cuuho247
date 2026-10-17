// Local, disposable PostgreSQL only. No credentials or production connections.
// Run: node scripts/check-monitoring-readonly.mjs
import assert from 'node:assert/strict'
import { readFile, readdir } from 'node:fs/promises'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { resolve } from 'node:path'

const root = fileURLToPath(new URL('../../', import.meta.url))
const dist = resolve(root, '.cache_rescuer/temp/payment-core-security/node_modules/@electric-sql/pglite/dist')
const { PGlite } = await import(pathToFileURL(resolve(dist, 'index.js')))
const { pgcrypto } = await import(pathToFileURL(resolve(dist, 'contrib/pgcrypto.js')))
const db = new PGlite({ extensions: { pgcrypto } })
const migrationDir = resolve(root, 'backend/supabase/migrations')
const rpc = 'public.admin_get_system_monitoring(integer,integer)'
const uid = (index) => `b1600000-0000-4000-8000-${String(index).padStart(12, '0')}`

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
    set payment.test_mode='local_disposable';`)
  for (const name of (await readdir(migrationDir)).filter((name) => name.endsWith('.sql')).sort()) {
    await db.exec((await readFile(resolve(migrationDir, name), 'utf8')).replace(/^\uFEFF/, ''))
  }
  const contract = (await db.query(`select proargnames,pronargdefaults,prorettype::regtype::text return_type,
    provolatile,prosecdef,proconfig from pg_proc where oid=$1::regprocedure`, [rpc])).rows[0]
  assert.deepEqual(contract, { proargnames: ['p_window_hours', 'p_limit'], pronargdefaults: 2,
    return_type: 'jsonb', provolatile: 's', prosecdef: true, proconfig: ['search_path=""'] })
  const grants = (await db.query(`select has_function_privilege('anon',$1,'EXECUTE') anon,
    has_function_privilege('authenticated',$1,'EXECUTE') authenticated,
    has_function_privilege('service_role',$1,'EXECUTE') service_role`, [rpc])).rows[0]
  assert.deepEqual(grants, { anon: false, authenticated: true, service_role: false })
  console.log('PASS exact named signature, jsonb, STABLE, SECURITY DEFINER, empty search_path, explicit EXECUTE grants')

  const cases = [
    { label: 'anon', role: 'anon', allowed: false },
    { label: 'customer', allowed: false }, { label: 'rescuer', allowed: false },
    { label: 'support', admin: 'support', allowed: false },
    { label: 'partner_reviewer', admin: 'partner_reviewer', allowed: false },
    { label: 'blocked super admin', admin: 'super_admin', blocked: true, allowed: false },
    { label: 'finance', admin: 'finance', allowed: true },
    { label: 'operator', admin: 'operator', allowed: true },
    { label: 'super admin', admin: 'super_admin', allowed: true },
  ]
  for (const [index, fixture] of cases.entries()) {
    await db.query('insert into auth.users(id,email) values($1,$2)', [uid(index), `monitor-${index}@example.invalid`])
    if (fixture.admin) await db.query('insert into public.admin_profiles(id,full_name,role,status) values($1,$2,$3,$4)',
      [uid(index), fixture.label, fixture.admin, fixture.blocked ? 'blocked' : 'active'])
    if (fixture.label === 'rescuer') await db.query(`insert into public.rescuer_profiles(user_id,full_name,contact_phone,verification_status)
      values($1,'Monitor rescuer','0900000161','approved')`, [uid(index)])
    await db.exec('begin read only')
    try {
      await db.query("select set_config('request.jwt.claim.sub',$1,true)", [fixture.role === 'anon' ? '' : uid(index)])
      await db.exec(`set local role ${fixture.role ?? 'authenticated'}`)
      const read = () => db.query('select public.admin_get_system_monitoring(p_limit => 100, p_window_hours => 24) snapshot')
      if (fixture.allowed) {
        const snapshot = (await read()).rows[0].snapshot
        assert.equal(snapshot.window_hours, 24)
        assert.equal(snapshot.can_acknowledge, fixture.admin !== 'finance')
        assert(Number.isFinite(Date.parse(snapshot.generated_at)))
        for (const key of ['alerts', 'payment_events', 'webhook_events', 'rescue_events', 'security_events', 'delivery_channels']) assert(Array.isArray(snapshot[key]), key)
        assert(['healthy', 'degraded', 'critical'].includes(snapshot.summary.overall_status))
        assert(['healthy', 'degraded', 'critical'].includes(snapshot.summary.webhook_status))
        for (const [key, value] of Object.entries(snapshot.summary)) if (!key.endsWith('_status')) assert(Number.isSafeInteger(value) && value >= 0, key)
        assert.doesNotMatch(JSON.stringify(snapshot), /body_sha256|raw_body|account_number|webhook_secret/)
      } else {
        await assert.rejects(read, (error) => error.code === '42501')
      }
      console.log(`PASS READ ONLY ${fixture.label}: ${fixture.allowed ? 'allowed, valid DTO' : 'denied 42501'}`)
    } finally { await db.exec('rollback') }
  }
  console.log('MONITORING_READONLY_PASS: no STABLE/read-only conflict; RBAC preserved')
} catch (error) {
  console.error('FAIL', error.message, 'SQLSTATE', error.code)
  process.exitCode = 1
} finally { await db.close() }
