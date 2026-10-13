// Native PostgreSQL multi-connection races, NEVER a production runner.
// Requires psql + GD6C_NATIVE_TEST_URL pointing to postgres on a loopback host.
// Creates its own randomly named database; never migrates the supplied database.
// Optional --gd6b-preflight-workaround patches the known typo IN MEMORY ONLY.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';

function runPsql(command, args, env, statement) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { env, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';
    const timer = setTimeout(() => child.kill(), 60000);
    child.stdout.on('data', chunk => { stdout += chunk; });
    child.stderr.on('data', chunk => { stderr += chunk; });
    child.on('error', reject);
    child.on('close', code => {
      clearTimeout(timer);
      if (code === 0) resolve({ stdout });
      else {
        const error = new Error(`psql exited with code ${code}`);
        error.stderr = stderr;
        reject(error);
      }
    });
    child.stdin.end(statement);
  });
}
const raw = process.env.GD6C_NATIVE_TEST_URL;
const dockerContainer = process.env.GD6C_PSQL_DOCKER_CONTAINER;
if (dockerContainer) {
  assert(/^[a-zA-Z0-9][a-zA-Z0-9_.-]*$/.test(dockerContainer), 'invalid Docker container name');
}
if (!raw) {
  console.log('NOT RUN: GD6C_NATIVE_TEST_URL + native psql required for real concurrent sessions.');
  process.exitCode = 2;
} else {
  const url = new URL(raw);
  assert(['postgres:', 'postgresql:'].includes(url.protocol));
  assert(['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname), 'loopback only');
  assert.equal(url.pathname, '/postgres', 'administrative postgres database only');
  assert.equal(url.search, '', 'URL query options are not accepted');
  const name = 'gd6c_test_' + randomBytes(8).toString('hex');
  assert(/^gd6c_test_[a-f0-9]{16}$/.test(name));
  const env = { ...process.env, PGHOST: url.hostname.replace(/^\[|\]$/g, ''), PGPORT: url.port || '5432',
    PGUSER: decodeURIComponent(url.username), PGPASSWORD: decodeURIComponent(url.password), PGCONNECT_TIMEOUT: '5' };
  async function sql(statement, database = name) {
    try {
      const psqlArgs = ['-X', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1', '-f', '-'];
      const command = dockerContainer ? 'docker' : 'psql';
      const args = dockerContainer
        ? ['exec', '-i', '-e', 'PGDATABASE', '-e', 'PGUSER', '-e', 'PGPASSWORD', dockerContainer,
            'psql', '-h', '127.0.0.1', '-p', '5432', ...psqlArgs]
        : psqlArgs;
      const { stdout } = await runPsql(command, args, { ...env, PGDATABASE: database }, statement);
      return stdout.trim();
    } catch (error) {
      if (process.env.GD6C_DEBUG_SQL === '1') console.error(String(error?.stderr ?? error?.message ?? error));
      throw new Error('Native SQL check failed (connection/SQL details suppressed).');
    }
  }
  assert(!process.argv.includes('--gd6b-preflight-workaround'), 'Removed workaround: run the actual migration source.');
  const read = async path => (await readFile(path, 'utf8')).replace(/^\uFEFF/, '');
  let created = false;
  try {
    assert.equal(await sql("select rolsuper and coalesce(inet_server_addr() in ('127.0.0.1'::inet,'::1'::inet),false) from pg_roles where rolname=current_user", 'postgres'), 't', 'local disposable superuser required');
    await sql(`create database ${name}`, 'postgres'); created = true;
    await sql(`do $$ begin
      if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
      if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
      if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role nologin bypassrls; end if;
      end $$;
      create schema auth; create schema storage;
      create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',created_at timestamptz default now());
      create function auth.uid() returns uuid language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),
        nullif(current_setting('request.jwt.claims',true),'')::jsonb ->> 'sub')::uuid $$;
      create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
      create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text,metadata jsonb);
      alter table storage.objects enable row level security;
      grant usage on schema public,auth,storage to anon,authenticated,service_role;
      grant select,insert,update,delete on storage.objects to authenticated;`);
    const dir = 'backend/supabase/migrations';
    for (const file of (await readdir(dir)).filter(f => f.endsWith('.sql') && f <= '202610130002_customer_bank_intent_regeneration.sql').sort()) {
      try {
        await sql(await read(`${dir}/${file}`));
      } catch {
        throw new Error(`Native migration failed: ${file}`);
      }
    }
    const fixture = (await read('backend/supabase/tests/payment_bank_verification_regression.sql'))
      .split("select pg_temp.bank_error('untrusted evidence rejected',")[0];
    await sql("set payment.test_mode='local_disposable';\n" + fixture + `
      create table private.gd6c_race_fixtures as select b.i,b.n,f.payment_id,f.request_id
      from bank_inputs b join bank_fixtures f using(i);
      create table private.gd6c_regen_race_fixtures as
      select b.i,b.n,f.payment_id,f.request_id,i.id intent_id,i.version intent_version,
        p.version payment_version,gen_random_uuid() operation_id
      from bank_inputs b join bank_fixtures f using(i)
      join public.payments p on p.id=f.payment_id
      join private.payment_bank_intents i on i.payment_id=p.id where b.i in (5,6);
      alter table private.payment_bank_intents disable trigger bank_intent_guard;
      update private.payment_bank_intents i set expires_at=clock_timestamp()-interval '1 second'
        from private.gd6c_regen_race_fixtures f where f.intent_id=i.id;
      alter table private.payment_bank_intents enable trigger bank_intent_guard;
      create function private.gd6c_try_regenerate(p_i integer) returns text language plpgsql as $$
      declare f private.gd6c_regen_race_fixtures;
      begin
        select * into f from private.gd6c_regen_race_fixtures where i=p_i;
        perform public.customer_regenerate_bank_transfer(f.request_id,f.payment_id,
          f.payment_version,f.intent_id,f.intent_version,f.operation_id);
        return 'ok';
      exception when others then return sqlerrm;
      end $$;
      commit;`);

    // First session holds the provider advisory lock AFTER writing its uncommitted
    // settlement. pg_stat_activity is the barrier; second session must block on
    // that lock, so this is a real overlap, not two sequential calls.
    async function awaitActivity(application, predicate) {
      const deadline = Date.now() + 10000;
      while (Date.now() < deadline) {
        if (await sql(`select exists(select 1 from pg_stat_activity where datname=current_database()
          and application_name='${application}' and ${predicate})`) === 't') return;
        await new Promise(resolve => setTimeout(resolve, 30));
      }
      throw new Error('Concurrency barrier not reached');
    }
    async function race(i, patch, expected) {
      const first = sql(`set application_name='gd6c_first'; begin;
        select private.process_verified_bank_transaction(n) from private.gd6c_race_fixtures where i=${i};
        select pg_sleep(3); commit;`);
      await awaitActivity('gd6c_first', "wait_event='PgSleep'");
      const second = sql(`set application_name='gd6c_second';
        select private.process_verified_bank_transaction(n || '${JSON.stringify(patch)}'::jsonb)->>'result'
        from private.gd6c_race_fixtures where i=${i};`);
      await awaitActivity('gd6c_second', "wait_event_type='Lock'");
      const results = await Promise.allSettled([first, second]);
      for (const result of results) if (result.status === 'rejected') throw result.reason;
      assert.equal(results[1].value, expected);
      assert.equal(await sql(`select p.version=3 and p.status='paid' and
        (select count(*) from private.bank_transactions t where t.matched_payment_id=p.id and t.status='verified')=1 and
        (select count(*) from public.payment_events e where e.payment_id=p.id and e.event_type='bank_payment_verified')=1
        from public.payments p join private.gd6c_race_fixtures f on f.payment_id=p.id where f.i=${i}`), 't');
    }
    await race(1, {}, 'duplicate_event');
    console.log('PASS concurrent identical delivery/event -> one settlement');
    await race(2, { provider_event_id: 'native-new-event', delivery_id: 'native-new-delivery' }, 'duplicate_transaction');
    console.log('PASS concurrent new delivery same transaction -> one settlement');
    await race(3, { provider_event_id: 'native-second-event', delivery_id: 'native-second-delivery', provider_transaction_id: 'native-second-transaction' }, 'already_paid');
    console.log('PASS competing transactions same payment -> one settlement');

    const pending = sql(`set application_name='gd6c_first'; begin;
      select private.process_verified_bank_transaction(n) from private.gd6c_race_fixtures where i=4;
      select pg_sleep(3); commit;`);
    await awaitActivity('gd6c_first', "wait_event='PgSleep'");
    const getter = `set request.jwt.claim.sub='91000000-0000-4000-8000-000000000001';
      select public.customer_get_payment(request_id)->>'status' from private.gd6c_race_fixtures where i=4;`;
    assert.equal(await sql(getter), 'awaiting_payment');
    await pending;
    assert.equal(await sql(getter), 'paid');
    console.log('PASS concurrent getter sees only committed authoritative payment');

    // Webhook first: regeneration waits on the shared provider/account advisory
    // lock and then fails closed after seeing the committed inbound observation.
    const webhookFirst = sql(`set application_name='gd6c_regen_webhook_first'; begin;
      select private.process_verified_bank_transaction(n) from private.gd6c_regen_race_fixtures where i=5;
      select pg_sleep(3); commit;`);
    await awaitActivity('gd6c_regen_webhook_first', "wait_event='PgSleep'");
    const regenSecond = sql(`set application_name='gd6c_regen_second';
      set request.jwt.claim.sub='91000000-0000-4000-8000-000000000001';
      select private.gd6c_try_regenerate(5);`);
    await awaitActivity('gd6c_regen_second', "wait_event_type='Lock'");
    const webhookFirstResults = await Promise.allSettled([webhookFirst, regenSecond]);
    for (const result of webhookFirstResults) if (result.status === 'rejected') throw result.reason;
    assert.equal(webhookFirstResults[1].value, 'BANK_TRANSFER_RECONCILIATION_REQUIRED');
    assert.equal(await sql(`select p.version=2 and p.status='awaiting_payment' and i.status='ready'
      and (select count(*) from private.payment_bank_intents x where x.payment_id=p.id
        and x.status in ('created','ready','matched','verified'))=1
      from private.gd6c_regen_race_fixtures f join public.payments p on p.id=f.payment_id
      join private.payment_bank_intents i on i.id=f.intent_id where f.i=5`), 't');
    console.log('PASS concurrent webhook first -> regeneration requires reconciliation');

    // Regeneration first: the old webhook waits, then is terminally rejected;
    // it cannot be redirected to or settle the newly active intent.
    const regenFirst = sql(`set application_name='gd6c_regen_first'; begin;
      set request.jwt.claim.sub='91000000-0000-4000-8000-000000000001';
      select private.gd6c_try_regenerate(6); select pg_sleep(3); commit;`);
    await awaitActivity('gd6c_regen_first', "wait_event='PgSleep'");
    const webhookSecond = sql(`set application_name='gd6c_regen_webhook_second';
      select private.process_verified_bank_transaction(n)->>'result'
      from private.gd6c_regen_race_fixtures where i=6;`);
    await awaitActivity('gd6c_regen_webhook_second', "wait_event_type='Lock'");
    const regenFirstResults = await Promise.allSettled([regenFirst, webhookSecond]);
    for (const result of regenFirstResults) if (result.status === 'rejected') throw result.reason;
    assert.equal(regenFirstResults[1].value, 'intent_ineligible');
    assert.equal(await sql(`select p.version=3 and p.status='awaiting_payment'
      and old_i.status='expired'
      and (select count(*) from private.payment_bank_intents x where x.payment_id=p.id and x.status='ready')=1
      and not exists(select 1 from private.bank_transactions t where t.matched_payment_id=p.id and t.status='verified')
      from private.gd6c_regen_race_fixtures f join public.payments p on p.id=f.payment_id
      join private.payment_bank_intents old_i on old_i.id=f.intent_id where f.i=6`), 't');
    console.log('PASS concurrent regeneration first -> late old webhook cannot settle new intent');
  } finally {
    // Only the freshly created, random name above can be removed. Never uses a
    // supplied database name, wildcard, or FORCE against unrelated sessions.
    if (created) await sql(`drop database ${name}`, 'postgres');
  }
}
