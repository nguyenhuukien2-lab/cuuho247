// Run from the repo root with a disposable PGlite dependency:
// npm install --prefix .cache_display_codes --no-save --package-lock=false @electric-sql/pglite@0.5.8
// node admin_web/backend/supabase/tests/run_display_codes.mjs
// PostgreSQL runs in RAM. This runner never connects to a Supabase project.
import assert from 'node:assert/strict'
import { readFile, readdir } from 'node:fs/promises'
import { resolve, dirname } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..')
const packageRoot = resolve(root, process.argv[2] ?? '.cache_display_codes/node_modules/@electric-sql/pglite')
const { PGlite } = await import(pathToFileURL(resolve(packageRoot, 'dist/index.js')))
const { pgcrypto } = await import(pathToFileURL(resolve(packageRoot, 'dist/contrib/pgcrypto.js')))
const db = new PGlite({ extensions: { pgcrypto } })
const read = async (path) => (await readFile(resolve(root, path), 'utf8')).replace(/^\uFEFF/, '')
const execute = async (path) => {
  await db.exec(await read(path))
  console.log(`PASS ${path}`)
}
const migration = 'admin_web/backend/supabase/migrations/202610050001_display_codes.sql'
const entities = [
  ['customer_profiles', 'customer_code', 'customer_code_seq', 'KH', 'user_id'],
  ['rescuer_profiles', 'rescuer_code', 'rescuer_code_seq', 'DT', 'user_id'],
  ['rescue_requests', 'request_code', 'request_code_seq', 'CH', 'id'],
  ['rescue_quotes', 'quote_code', 'quote_code_seq', 'BG', 'id'],
  ['admin_profiles', 'admin_code', 'admin_code_seq', 'AD', 'id'],
]
const query = async (sql, args = []) => (await db.query(sql, args)).rows
const expectError = async (sql, state) => {
  await assert.rejects(db.exec(sql), (error) => error.code === state)
}
try {
  await db.exec(`
    create role anon nologin;
    create role authenticated nologin;
    create schema auth;
    create schema storage;
    create table auth.users(id uuid primary key, email text, raw_user_meta_data jsonb default '{}', created_at timestamptz default now());
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
    $$;
    create table storage.buckets(id text primary key, name text, public boolean, file_size_limit bigint, allowed_mime_types text[]);
    create table storage.objects(id uuid primary key default gen_random_uuid(), bucket_id text references storage.buckets(id), name text, metadata jsonb);
    alter table storage.objects enable row level security;
    grant usage on schema public,auth,storage to anon,authenticated;
    grant select,insert,update,delete on storage.objects to authenticated;
  `)
  for (const name of (await readdir(resolve(root, 'backend/supabase/migrations'))).filter((n) => n.endsWith('.sql')).sort()) {
    await execute(`backend/supabase/migrations/${name}`)
  }
  await execute('admin_web/backend/supabase/migrations/202610040001_admin_backend_foundation.sql')

  // Run the existing rescuer lifecycle on the disposable DB; retain its fixtures
  // for backfill verification (the original test file remains untouched).
  const rescuerRegression = (await read('backend/supabase/tests/rescuer_local_regression.sql'))
    .split('\n').filter((line) => !line.startsWith('\\')).join('\n')
    .replace(/rollback;\s*$/i, 'commit;')
  await db.exec(rescuerRegression)
  console.log('PASS existing rescuer lifecycle before migration / persisted backfill fixtures')
  await db.exec(`
    reset role;
    select set_config('request.jwt.claim.sub','',false);
    insert into auth.users(id,email) values('d0000000-0000-4000-8000-000000000001','admin-display-test@example.invalid');
    insert into public.admin_profiles(id,full_name,role) values('d0000000-0000-4000-8000-000000000001','Display code Admin','super_admin');
    -- Existing valid code and a partially initialized sequence must survive.
    alter table public.customer_profiles add column customer_code text;
    update public.customer_profiles set customer_code='KH-000100' where user_id='d0000000-0000-4000-8000-000000000001';
    create sequence public.customer_code_seq;
    select setval('public.customer_code_seq',50,true);
  `)
  const identities = new Map()
  for (const [table, , , , key] of entities) {
    identities.set(table, await query(`select ${key} as id from public.${table} order by ${key}`))
  }
  await execute(migration)
  const codes = new Map()
  for (const [table, column, sequence, prefix, key] of entities) {
    assert.deepEqual(await query(`select ${key} as id from public.${table} order by ${key}`), identities.get(table))
    const rows = await query(`select ${column} as code from public.${table} order by ${key}`)
    assert(rows.length > 0, `backfill fixture for ${table}`)
    assert(rows.every((r) => new RegExp(`^${prefix}-[0-9]{6,}$`).test(r.code)))
    assert.equal(new Set(rows.map((r) => r.code)).size, rows.length)
    codes.set(table, rows)
    const max = Math.max(...rows.map((r) => Number(r.code.slice(3))))
    assert(Number((await query(`select last_value from public.${sequence}`))[0].last_value) >= max)
  }
  assert.equal((await query(`select customer_code from public.customer_profiles where user_id='d0000000-0000-4000-8000-000000000001'`))[0].customer_code, 'KH-000100')
  console.log('PASS five-table backfill, existing codes, UUID preservation and sequence synchronization')
  await execute(migration)
  for (const [table, column, , , key] of entities) {
    assert.deepEqual(await query(`select ${column} as code from public.${table} order by ${key}`), codes.get(table))
  }
  assert.equal((await query(`select public.format_display_code('CH',1000000) as code`))[0].code, 'CH-1000000')
  console.log('PASS migration rerun and sequence growth beyond six digits')

  await db.exec(`insert into auth.users(id,email) values('d0000000-0000-4000-8000-000000000002','new-display-test@example.invalid')`)
  const newCustomer = (await query(`select customer_code from public.customer_profiles where user_id='d0000000-0000-4000-8000-000000000002'`))[0].customer_code
  assert(Number(newCustomer.slice(3)) > 100)
  await db.exec(`
    insert into public.rescuer_profiles(user_id,full_name,contact_phone) values('d0000000-0000-4000-8000-000000000002','New rescuer','0900000002');
    insert into public.admin_profiles(id,full_name) values('d0000000-0000-4000-8000-000000000002','New admin');
  `)
  assert.match((await query(`select rescuer_code from public.rescuer_profiles where user_id='d0000000-0000-4000-8000-000000000002'`))[0].rescuer_code, /^DT-\d{6,}$/)
  assert.match((await query(`select admin_code from public.admin_profiles where id='d0000000-0000-4000-8000-000000000002'`))[0].admin_code, /^AD-\d{6,}$/)
  await db.exec(`begin;
    insert into public.rescue_requests(customer_id,client_request_id,vehicle_kind,service_code,
      location_text,location_confirmed,contact_name,contact_phone)
    values('d0000000-0000-4000-8000-000000000002',gen_random_uuid(),'car','tire',
      'New display test location',true,'Test customer','0900000002');`)
  assert.match((await query(`select request_code from public.rescue_requests where customer_id='d0000000-0000-4000-8000-000000000002'`))[0].request_code, /^CH-\d{6,}$/)
  await db.exec('rollback;')
  const assignment = (await query(`select id,request_id,rescuer_id,
    (select coalesce(max(revision),0)+1 from public.rescue_quotes where assignment_id=a.id) as revision
    from public.rescue_request_assignments a limit 1`))[0]
  await db.exec('begin;')
  const newQuote = await query(`insert into public.rescue_quotes(assignment_id,request_id,rescuer_id,revision,
    status,total_vnd,items) values($1,$2,$3,$4,'superseded',100000,
    '[{"service_code":"tire","quantity":1,"unit_price_vnd":100000}]'::jsonb)
    returning id,quote_code`, [assignment.id, assignment.request_id, assignment.rescuer_id, assignment.revision])
  assert.match(newQuote[0].quote_code, /^BG-\d{6,}$/)
  assert.match(newQuote[0].id, /^[0-9a-f-]{36}$/)
  await db.exec('rollback;')
  await expectError(`update public.customer_profiles set customer_code='KH-999999' where user_id='d0000000-0000-4000-8000-000000000002'`, '22023')
  await expectError(`insert into public.customer_profiles(user_id,customer_code) values(gen_random_uuid(),'KH-000100')`, '23505')
  console.log('PASS all five insert triggers, code uniqueness and immutability')

  await db.exec(`set role authenticated; select set_config('request.jwt.claim.sub','d0000000-0000-4000-8000-000000000001',false)`)
  for (const [view, column] of [
    ['admin_customers_view','customer_code'], ['admin_rescuers_view','rescuer_code'],
    ['admin_rescue_requests_view','request_code'], ['admin_quotes_view','quote_code'],
  ]) {
    const rows = await query(`select ${column} as code from public.${view}`)
    assert(rows.length > 0 && rows.every((r) => /^[A-Z]{2}-\d{6,}$/.test(r.code)))
  }
  await expectError(`select nextval('public.customer_code_seq')`, '42501')
  await expectError(`select private.assign_display_code()`, '42501')
  await db.exec(`select set_config('request.jwt.claim.sub','f0000000-0000-4000-8000-000000000002',false)`)
  const ownIds = (await query('select id from public.rescue_requests')).map((r) => r.id)
  const result = await query('select * from public.customer_request_display_codes($1::uuid[])', [ownIds])
  assert.equal(result.length, ownIds.length)
  await db.exec(`select set_config('request.jwt.claim.sub','d0000000-0000-4000-8000-000000000002',false)`)
  assert.equal((await query('select * from public.customer_request_display_codes($1::uuid[])', [ownIds])).length, 0)
  await db.exec(`reset role; select set_config('request.jwt.claim.sub','f0000000-0000-4000-8000-000000000001',false)`)
  const assignmentDto = await query(`select private.rescuer_assignment_dto($1::uuid) as value`, [assignment.id])
  assert.match(assignmentDto[0].value.request_code, /^CH-\d{6,}$/)
  const availableDto = await query(`select private.rescuer_available_dto($1::uuid,10.77,106.69,'tire','car',2) as value`, [assignment.request_id])
  assert.equal(availableDto[0].value.request_code, assignmentDto[0].value.request_code)
  const existingQuote = (await query(`select id from public.rescue_quotes limit 1`))[0]
  assert.match((await query(`select private.rescuer_quote_dto($1::uuid) as value`, [existingQuote.id]))[0].value.quote_code, /^BG-\d{6,}$/)
  console.log('PASS Admin view codes, sequence ACL and customer ownership isolation')

  console.log('PASS display code PostgreSQL regression')
} catch (error) {
  console.error(error.message, error.code, error.detail ?? '', error.where ?? '')
  process.exitCode = 1
} finally {
  await db.close()
}
