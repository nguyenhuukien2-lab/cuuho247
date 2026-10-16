// In-memory disposable PostgreSQL only. No remote URL, credentials or live writes.
// Run from repository root: node tools/check_vietinbank_sepay.mjs
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const root = process.cwd();
const staging = process.argv.includes('--staged') ? resolve(root, 'admin_web/.payment-sevqr-work') : root;
const read = async path => {
  try { return (await readFile(resolve(staging, path), 'utf8')).replace(/^\uFEFF/, ''); }
  catch (error) { if (error.code !== 'ENOENT') throw error; return (await readFile(resolve(root, path), 'utf8')).replace(/^\uFEFF/, ''); }
};
const dist = resolve(root, '.cache_rescuer/temp/payment-core-security/node_modules/@electric-sql/pglite/dist');
const { PGlite } = await import(pathToFileURL(resolve(dist, 'index.js')));
const { pgcrypto } = await import(pathToFileURL(resolve(dist, 'contrib/pgcrypto.js')));
const { createSePayAdapter } = await import(pathToFileURL(resolve(staging, 'backend/supabase/functions/bank-webhook/sepay.ts')));
const { createBankWebhookHandler } = await import(pathToFileURL(resolve(staging, 'backend/supabase/functions/bank-webhook/handler.ts')));
const db = new PGlite({ extensions: { pgcrypto } });
const migration = '202610150002_vietinbank_sepay_transfer_description.sql';
const suiteNames = new Map([
  ['202610100001_payment_core_security.sql', 'payment_core_security_regression.sql'],
  ['202610100002_payment_customer_prepare.sql', 'payment_customer_prepare_regression.sql'],
  ['202610100003_payment_customer_select_cash.sql', 'payment_customer_select_cash_regression.sql'],
  ['202610100004_payment_rescuer_cash.sql', 'payment_rescuer_cash_regression.sql'],
  ['202610100005_payment_realtime.sql', 'payment_realtime_regression.sql'],
  ['202610110001_payment_bank_foundation.sql', 'payment_bank_foundation_regression.sql'],
  ['202610110002_payment_bank_qr.sql', 'payment_bank_qr_regression.sql'],
  ['202610110003_payment_bank_verification.sql', 'payment_bank_verification_regression.sql'],
  ['202610130001_admin_payment_readonly_hotfix.sql', 'admin_payment_read_api_regression.sql'],
  ['202610130002_customer_bank_intent_regeneration.sql', 'payment_bank_regeneration_regression.sql'],
  ['202610130003_admin_payment_operations_v2.sql', 'admin_payment_operations_v2_regression.sql'],
  ['202610140001_system_configuration_security_v1.sql', 'system_configuration_security_v1_regression.sql'],
  ['202610150001_system_security_rpc_hardening.sql', 'system_security_rpc_hardening_regression.sql'],
]);
async function suite(name) {
  const results = await db.exec(await read('backend/supabase/tests/' + name));
  const summary = results.flatMap(result => result.rows ?? []).find(row => row.result?.endsWith('_PASS'));
  assert(summary, name);
  console.log('PASS', name, summary.assertions, 'assertions');
}
function tlv(value) {
  const result = {}; let cursor = 0;
  while (cursor < value.length) {
    const tag = value.slice(cursor, cursor + 2), length = value.slice(cursor + 2, cursor + 4);
    assert.match(tag, /^[0-9]{2}$/); assert.match(length, /^[0-9]{2}$/);
    assert(Number(length) > 0 && cursor + 4 + Number(length) <= value.length && !(tag in result));
    result[tag] = value.slice(cursor + 4, cursor + 4 + Number(length));
    cursor += 4 + Number(length);
  }
  assert.equal(cursor, value.length);
  return result;
}
function crc16(value) {
  let crc = 65535;
  for (const byte of Buffer.from(value, 'ascii')) {
    crc ^= byte << 8;
    for (let bit = 0; bit < 8; bit++) crc = crc & 32768 ? ((crc << 1) ^ 4129) & 65535 : (crc << 1) & 65535;
  }
  return crc.toString(16).toUpperCase().padStart(4, '0');
}
async function rejected(statement, params, expected) {
  await assert.rejects(db.query(statement, params), error => error.message === expected);
}
const contracts = `select p.oid,p.proowner,p.proacl,p.prosecdef,p.provolatile,p.proconfig,p.proargtypes::text,p.prorettype::text
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') order by p.oid`;
const snapshots = 'select to_jsonb(s) s from private.payment_bank_qr_snapshots s order by intent_id';
try {
  await db.exec(`create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
    create schema auth; create schema storage;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',created_at timestamptz default now());
    create function auth.uid() returns uuid language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid$$;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text,metadata jsonb);
    alter table storage.objects enable row level security;
    grant usage on schema public,auth,storage to anon,authenticated,service_role;
    grant select,insert,update,delete on storage.objects to authenticated;
    set payment.test_mode='local_disposable';`);
  const names = [...new Set([...(await readdir(resolve(root, 'backend/supabase/migrations'))), migration])].filter(name => name.endsWith('.sql')).sort();
  for (const name of names) {
    await db.exec(await read('backend/supabase/migrations/' + name));
    if (suiteNames.has(name)) await suite(suiteNames.get(name));
  }
  console.log('PASS clean migration chain:', names.length, 'migrations');
  for (const name of ['payment_bank_qr_regression.sql', 'payment_bank_verification_regression.sql',
    'payment_bank_regeneration_regression.sql', 'admin_payment_operations_v2_regression.sql',
    'system_configuration_security_v1_regression.sql', 'system_security_rpc_hardening_regression.sql']) await suite(name);

  // Simulate the real upgrade with existing immutable QR snapshots. Reinstall
  // only the previous three definitions inside this disposable RAM database.
  const previousQr = await read('backend/supabase/migrations/202610110002_payment_bank_qr.sql');
  const previousRegen = await read('backend/supabase/migrations/202610130002_customer_bank_intent_regeneration.sql');
  function definition(source, start) {
    const index = source.indexOf(start); assert(index >= 0);
    return source.slice(index, source.indexOf('$$;', index) + 3).replace('create function', 'create or replace function');
  }
  await db.exec(definition(previousQr, 'create function private.payment_bank_vietqr('));
  await db.exec(definition(previousRegen, 'create or replace function private.payment_bank_qr_snapshot_guard('));
  await db.exec(definition(previousRegen, 'create or replace function public.customer_get_bank_payment(')
    .replace(/\bbegin\b/i, 'begin if auth.uid() is not null then perform private.system_require_session(); end if;'));
  const fixtureSource = await read('backend/supabase/tests/payment_bank_verification_regression.sql');
  await db.exec(fixtureSource.split('do $select_bank$')[0]);
  const fixtures = (await db.query('select f.*,p.customer_id from bank_fixtures f join public.payments p on p.id=f.payment_id order by i')).rows;
  await db.exec(`update private.payment_bank_config set bank_bin='970415',bank_code='ICB',
    verification_enabled=true,verification_provider='sepay',verification_scope='production:local-fixture',require_beneficiary=true;`);
  const f = i => fixtures.find(row => row.i === i);
  async function selectBank(i) {
    const row = f(i);
    await db.query("select set_config('request.jwt.claim.sub',$1,false)", [row.customer_id]);
    await db.query('select public.customer_select_bank_transfer($1::uuid,$2::uuid,1,$3::uuid)', [row.request_id, row.payment_id, row.operation_id]);
    return (await db.query('select s.*,b.expires_at,b.id from private.payment_bank_qr_snapshots s join private.payment_bank_intents b on b.id=s.intent_id where b.payment_id=$1::uuid order by b.created_at desc limit 1', [row.payment_id])).rows[0];
  }
  await selectBank(1); const oldExpired = await selectBank(2);
  await db.exec('commit');
  const before = (await db.query(snapshots)).rows;
  assert(before.every(row => tlv(tlv(row.s.qr_payload)['62'])['08'] === row.s.transfer_content));
  const aclBefore = (await db.query(contracts)).rows;
  const configBefore = (await db.query('select to_jsonb(c) c from private.payment_bank_config c')).rows;
  const processorBefore = (await db.query("select pg_get_functiondef('private.process_verified_bank_transaction(jsonb)'::regprocedure) definition")).rows;
  await db.exec(await read('backend/supabase/migrations/' + migration));
  assert.deepEqual((await db.query(snapshots)).rows, before);
  assert.deepEqual((await db.query(contracts)).rows, aclBefore);
  assert.deepEqual((await db.query('select to_jsonb(c) c from private.payment_bank_config c')).rows, configBefore);
  assert.deepEqual((await db.query("select pg_get_functiondef('private.process_verified_bank_transaction(jsonb)'::regprocedure) definition")).rows, processorBefore);
  console.log('PASS upgrade leaves snapshots, config, settlement function, owners, signatures, ACL and security modes unchanged');
  const dto = async i => (await db.query('select public.customer_get_bank_payment($1::uuid) value', [f(i).request_id])).rows[0].value;
  await db.query("select set_config('request.jwt.claim.sub',$1,false)", [f(1).customer_id]);
  const oldDto = await dto(1);
  assert.equal(oldDto.transfer_description, oldDto.transfer_content);
  const ready = new Map();
  for (let i = 3; i <= 23; i++) ready.set(i, await selectBank(i));
  for (const row of ready.values()) {
    const qr = tlv(row.qr_payload);
    assert.match(row.transfer_content, /^BK[0-9]{19}$/); assert.equal(row.transfer_content.length, 21);
    assert.equal(tlv(qr['62'])['08'], 'SEVQR ' + row.transfer_content);
    assert.equal(qr['62'].length, 31); assert(row.qr_payload.length <= 512);
    assert.equal(qr['63'], crc16(row.qr_payload.slice(0, -4)));
  }
  const newDto = await dto(3);
  assert.equal(newDto.transfer_description, 'SEVQR ' + ready.get(3).transfer_content);
  assert.equal(newDto.transfer_content, ready.get(3).transfer_content);
  assert.equal(newDto.qr_payload, ready.get(3).qr_payload);
  console.log('PASS new VietinBank QR 62/08 memo, independent TLV/CRC and canonical 21-character reference');
  for (const content of ['A'.repeat(26), 'SEVQR BK000000000000000001', 'SEVQR BK00000000000000000010', 'SEVQR  BK0000000000000000001', 'SEVQR BK0000000000000000001\n', 'SEVQR BK000000000000000000é', 'A'.repeat(1000)]) {
    await rejected("select private.payment_bank_vietqr('970415','123456789012',100000,$1)", [content], 'BANK_QR_VALUE_INVALID');
  }
  await rejected("select private.payment_bank_vietqr('970436','123456789012',100000,'SEVQR BK0000000000000000001')", [], 'BANK_QR_VALUE_INVALID');
  await rejected("select private.payment_bank_tlv('08',repeat('A',100))", [], 'BANK_QR_VALUE_INVALID');
  await rejected("update private.payment_bank_qr_snapshots set transfer_content=transfer_content", [], 'BANK_QR_SNAPSHOT_IMMUTABLE');

  // Fault injection is restricted to this isolated test DB, never live data.
  async function expire(id) {
    await db.exec(`alter table private.payment_bank_intents disable trigger user;`);
    await db.query("update private.payment_bank_intents set created_at=clock_timestamp()-interval '1 hour',expires_at=clock_timestamp()-interval '1 second' where id=$1::uuid", [id]);
    await db.exec('alter table private.payment_bank_intents enable trigger user');
  }
  await expire(oldExpired.intent_id);
  await db.query("select set_config('request.jwt.claim.sub',$1,false)", [f(2).customer_id]);
  await db.query('select public.customer_regenerate_bank_transfer($1::uuid,$2::uuid,2,$3::uuid,2,gen_random_uuid())', [f(2).request_id, f(2).payment_id, oldExpired.intent_id]);
  const regenerated = await dto(2);
  assert.notEqual(regenerated.bank_intent_id, oldExpired.intent_id);
  assert.equal(tlv(tlv(regenerated.qr_payload)['62'])['08'], regenerated.transfer_description);
  assert.equal(regenerated.transfer_description, 'SEVQR ' + regenerated.transfer_content);
  assert.deepEqual((await db.query('select to_jsonb(s) s from private.payment_bank_qr_snapshots s where intent_id=$1::uuid', [oldExpired.intent_id])).rows[0], before.find(row => row.s.intent_id === oldExpired.intent_id));
  console.log('PASS expired historical QR regenerates to new SEVQR snapshot without rewriting history');

  // Signed provider payload -> real adapter -> unchanged SQL settlement function.
  await db.exec("select set_config('request.jwt.claim.sub','',false)");
  await new Promise(resolve => setTimeout(resolve, 1100)); // SePay timestamps have second precision.
  const secret = 'disposable-local-HMAC-only';
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  // A retry must retain the provider's original transaction timestamp. Rebuild
  // only the delivery signature; using clock_timestamp() per delivery makes
  // retries crossing a second boundary correctly fail as identity_conflict.
  const transactionTimes = new Map();
  let outcome;
  const store = {
    async processVerifiedTransaction(transaction) {
      outcome = (await db.query('select private.process_verified_bank_transaction($1::jsonb) value', [JSON.stringify(transaction)])).rows[0].value;
      return outcome;
    },
    async recordAuthenticationFailure() {},
  };
  async function deliver(i, expected, overrides = {}, options = {}, status = 200) {
    outcome = undefined;
    const row = ready.get(i);
    if (!transactionTimes.has(i)) {
      transactionTimes.set(i, (await db.query("select to_char(clock_timestamp() at time zone 'Asia/Ho_Chi_Minh','YYYY-MM-DD HH24:MI:SS') value")).rows[0].value);
    }
    const time = transactionTimes.get(i);
    const body = JSON.stringify({ id: 800000 + i, gateway: 'VietinBank', transactionDate: time,
      accountNumber: row.account_number, code: '', content: 'SEVQR ' + row.transfer_content,
      transferType: 'in', transferAmount: 100000 * i, ...overrides });
    const timestamp = String(Math.floor(Date.now() / 1000));
    const signature = Buffer.from(await crypto.subtle.sign('HMAC', key, encoder.encode(`${timestamp}.${body}`))).toString('hex');
    const adapter = createSePayAdapter({ secret, providerScope: 'production:local-fixture', beneficiaryBankBin: '970415', ...options });
    const response = await createBankWebhookHandler({ adapter, store })(new Request('https://local.invalid', {
      method: 'POST', body, headers: { 'content-type': 'application/json', 'x-sepay-timestamp': timestamp, 'x-sepay-signature': 'sha256=' + signature },
    }));
    assert.equal(response.status, status);
    if (expected) { assert.equal(outcome?.result, expected); assert.equal(outcome?.changed, expected === 'paid'); }
    console.log('PASS signed SePay -> SQL:', expected ?? `HTTP ${status}`);
  }
  await deliver(3, 'paid');
  await new Promise(resolve => setTimeout(resolve, 1100)); // Deliberately cross a second boundary on replay.
  await deliver(3, 'duplicate_event');
  await deliver(4, 'paid', { code: ready.get(4).transfer_content });
  await deliver(5, 'amount_mismatch', { transferAmount: 499999 });
  await deliver(6, 'reference_unmatched', { content: 'SEVQR BK9999999999999999999' });
  await deliver(7, 'beneficiary_mismatch', { accountNumber: '9999999999' });
  await deliver(8, 'beneficiary_mismatch', {}, { beneficiaryBankBin: '970436' });
  await expire(ready.get(9).intent_id);
  await deliver(9, 'intent_expired');
  await deliver(10, 'reference_unmatched', { content: `SEVQR ${ready.get(10).transfer_content} ${ready.get(11).transfer_content}` });
  await deliver(11, 'reference_unmatched', { content: 'SEVQR' });
  await deliver(12, 'reference_unmatched', { code: 'BK9999999999999999999' });
  await deliver(13, null, {}, { providerScope: 'sepay_test', testAccountNumber: ready.get(13).account_number }, 500);
  await deliver(14, null, { transferType: 'out' }, {}, 400);
  await deliver(15, 'paid', { code: null });
  await deliver(16, 'reference_unmatched', { content: 'SEVQR ' + ready.get(16).transfer_content + '0' });
  await deliver(17, null, {}, { providerScope: 'production:wrong-scope' }, 500);
  await deliver(3, 'identity_conflict', { transferAmount: 300001 });
  const counts = (await db.query("select (select count(*)::int from public.payments where status='paid') paid,(select count(*)::int from public.payment_events where event_type='bank_payment_verified') events")).rows[0];
  assert.deepEqual(counts, { paid: 3, events: 3 });
  console.log('PASS only three exact legitimate payments settled; mismatches/expiry/ambiguous/replay never settle');

  for (const [i, setting] of [[24, "verification_scope='sepay_test'"], [25, "verification_provider='other_provider',verification_scope='production:local-fixture'"], [26, "bank_bin='970436',verification_provider='sepay'"]]) {
    await db.exec('update private.payment_bank_config set ' + setting);
    const row = await selectBank(i);
    assert.equal(tlv(tlv(row.qr_payload)['62'])['08'], row.transfer_content);
    assert.equal((await dto(i)).transfer_description, row.transfer_content);
  }
  console.log('PASS Test Mode, other providers and other banks preserve legacy memo behavior');
  console.log('VIETINBANK_SEPAY_PASS (local only; no production claims)');
} catch (error) {
  console.error('FAIL', error.message, 'SQLSTATE', error.code, 'CONTEXT', error.where);
  process.exitCode = 1;
} finally { await db.close(); }
