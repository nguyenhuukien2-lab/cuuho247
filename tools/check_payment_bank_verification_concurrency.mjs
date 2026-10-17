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
    const migrationPaths = [];
    for (const dir of ['backend/supabase/migrations']) {
      for (const file of await readdir(dir)) {
        if (file.endsWith('.sql')) {
          migrationPaths.push(`${dir}/${file}`);
        }
      }
    }
    migrationPaths.sort((a, b) => a.split('/').at(-1).localeCompare(b.split('/').at(-1)));
    for (const path of migrationPaths) {
      try {
        await sql(await read(path));
      } catch {
        throw new Error(`Native migration failed: ${path}`);
      }
    }
    await sql("set payment.test_mode='local_disposable';" + await read('backend/supabase/tests/system_configuration_security_v1_regression.sql'));
    console.log('PASS native system configuration/security SQL regression');
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
      update private.payment_bank_intents i set created_at=clock_timestamp()-interval '2 hours',
        updated_at=clock_timestamp(),expires_at=clock_timestamp()-interval '1 hour'
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

      insert into auth.users(id,email) values
        ('a1490000-0000-4000-8000-000000000001','native-ops-finance-one@example.invalid'),
        ('a1490000-0000-4000-8000-000000000002','native-ops-finance-two@example.invalid');
      insert into public.admin_profiles(id,full_name,role,status) values
        ('a1490000-0000-4000-8000-000000000001','Native Ops Finance One','finance','active'),
        ('a1490000-0000-4000-8000-000000000002','Native Ops Finance Two','finance','active');
      alter table private.payment_bank_intents disable trigger bank_intent_guard;
      update private.payment_bank_intents i set created_at=clock_timestamp()-interval '2 hours',
        updated_at=clock_timestamp(),expires_at=clock_timestamp()-interval '1 hour'
        from private.gd6c_race_fixtures f where f.i=7 and f.payment_id=i.payment_id;
      alter table private.payment_bank_intents enable trigger bank_intent_guard;
      do $$
      declare v_result jsonb;
      begin
        select private.process_verified_bank_transaction(n) into v_result
          from private.gd6c_race_fixtures where i=7;
        if v_result->>'result' is distinct from 'intent_expired' then
          raise exception 'ADMIN_OPS_RACE_FIXTURE_INVALID';
        end if;
      end $$;
      create table private.admin_ops_race_fixture as
      select t.id transaction_id,t.version transaction_version,p.id payment_id,
        p.version payment_version,p.status payment_status,p.amount_received,p.paid_at,p.verified_at,
        (select count(*) from public.payment_events e where e.payment_id=p.id) payment_event_count
      from private.gd6c_race_fixtures f
      join public.payments p on p.id=f.payment_id
      join private.bank_transactions t on t.external_transaction_id='tx-7'
      where f.i=7 and t.status='rejected' and t.rejection_code='intent_expired';
      create function public.gd6c_try_admin_reconcile(
        p_transaction_id uuid,p_transaction_version bigint,p_operation_id uuid
      ) returns text language plpgsql security invoker set search_path='' as $$
      begin
        perform public.admin_resolve_late_payment(p_transaction_id,p_transaction_version,null,
          'refund_required','late_payment_return',p_operation_id);
        return 'ok';
      exception when others then
        return sqlstate||':'||sqlerrm;
      end $$;
      revoke all on function public.gd6c_try_admin_reconcile(uuid,bigint,uuid) from public,anon,service_role;
      grant execute on function public.gd6c_try_admin_reconcile(uuid,bigint,uuid) to authenticated;
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

    const adminOpsFixture = await sql(`select transaction_id::text||'|'||transaction_version::text
      from private.admin_ops_race_fixture`);
    assert.match(adminOpsFixture, /^[0-9a-f-]{36}\|[1-9][0-9]*$/);
    const [adminTransactionId, adminTransactionVersion] = adminOpsFixture.split('|');
    const reconcileFirst = sql(`set application_name='admin_ops_reconcile_first';
      set request.jwt.claim.sub='a1490000-0000-4000-8000-000000000001';
      set role authenticated; begin;
      select public.gd6c_try_admin_reconcile('${adminTransactionId}'::uuid,${adminTransactionVersion},
        'a1480000-0000-4000-8000-000000000011'::uuid);
      select pg_sleep(3); commit;`);
    await awaitActivity('admin_ops_reconcile_first', "wait_event='PgSleep'");
    const reconcileSecond = sql(`set application_name='admin_ops_reconcile_second';
      set request.jwt.claim.sub='a1490000-0000-4000-8000-000000000002';
      set role authenticated;
      select public.gd6c_try_admin_reconcile('${adminTransactionId}'::uuid,${adminTransactionVersion},
        'a1480000-0000-4000-8000-000000000012'::uuid);`);
    await awaitActivity('admin_ops_reconcile_second', "wait_event_type='Lock'");
    const reconcileResults = await Promise.allSettled([reconcileFirst, reconcileSecond]);
    for (const result of reconcileResults) if (result.status === 'rejected') throw result.reason;
    assert.equal(reconcileResults[0].value, 'ok');
    assert.equal(reconcileResults[1].value, '40001:STALE_VERSION');
    assert.equal(await sql(`select
      (select count(*) from private.payment_reconciliation_cases c
        where c.bank_transaction_id=f.transaction_id)=1
      and (select count(*) from private.payment_operations_audit a
        where a.bank_transaction_id=f.transaction_id and a.event_type='late_payment_refund_required')=1
      and (select count(*) from private.payment_admin_operation_receipts r
        where r.operation_kind='resolve_late_payment')=1
      and (select count(*) from private.payment_refunds r
        where r.bank_transaction_id=f.transaction_id)=0
      and p.version=f.payment_version and p.status=f.payment_status
      and p.amount_received is not distinct from f.amount_received
      and p.paid_at is not distinct from f.paid_at
      and p.verified_at is not distinct from f.verified_at
      and (select count(*) from public.payment_events e where e.payment_id=p.id)=f.payment_event_count
      and t.status='rejected' and t.rejection_code='intent_expired' and t.matched_payment_id is null
      from private.admin_ops_race_fixture f
      join public.payments p on p.id=f.payment_id
      join private.bank_transactions t on t.id=f.transaction_id`), 't');
    console.log('PASS concurrent Admin V2 reconciliation -> one immutable resolution, payment unchanged');

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

    // Reconciliation uses untouched fixture rows so the existing webhook races
    // above retain their original provider/configuration assumptions.
    await sql(`insert into auth.users(id,email) values
      ('a1710000-0000-4000-8000-000000000001','reconcile-race-super@example.invalid'),
      ('a1710000-0000-4000-8000-000000000002','reconcile-race-operator-one@example.invalid'),
      ('a1710000-0000-4000-8000-000000000003','reconcile-race-operator-two@example.invalid');
      insert into public.admin_profiles(id,full_name,role,status) values
      ('a1710000-0000-4000-8000-000000000001','Reconcile race super','super_admin','active'),
      ('a1710000-0000-4000-8000-000000000002','Reconcile race operator one','operator','active'),
      ('a1710000-0000-4000-8000-000000000003','Reconcile race operator two','operator','active');
      set request.jwt.claim.sub='a1710000-0000-4000-8000-000000000001'; set role authenticated;
      select public.admin_set_payment_reconcile_permission('a1710000-0000-4000-8000-000000000002',true,0,'native reconciliation race grant');
      select public.admin_set_payment_reconcile_permission('a1710000-0000-4000-8000-000000000003',true,0,'native reconciliation race grant');
      reset role; set request.jwt.claim.sub='';
      update private.payment_bank_config set verification_enabled=true,verification_provider='sepay',verification_scope='sepay_live';
      alter table private.payment_bank_intents disable trigger bank_intent_guard;
      update private.payment_bank_intents i set created_at=clock_timestamp()-interval '5 minutes',updated_at=clock_timestamp()
        from private.gd6c_race_fixtures f where f.i in (9,10,11) and f.payment_id=i.payment_id;
      alter table private.payment_bank_intents enable trigger bank_intent_guard;
      update private.gd6c_race_fixtures set n=n||jsonb_build_object(
        'provider','sepay','provider_scope','sepay_live','authentication_method','signature','signature_verified',true,
        'transfer_reference','SEVQR '||(n->>'transfer_reference'),
        'occurred_at',to_char((clock_timestamp()-interval '1 minute') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'))
        where i in (9,10,11);
      select private.process_verified_bank_transaction(n) from private.gd6c_race_fixtures where i in (9,10,11);
      select private.process_verified_bank_transaction(n||'{"provider_transaction_id":"tx-10-reconcile-second","provider_event_id":"event-10-reconcile-second","delivery_id":"delivery-10-reconcile-second"}')
        from private.gd6c_race_fixtures where i=10;
      create table private.reconciliation_race_fixtures as
      select f.i,t.id transaction_id,t.version transaction_version,p.id payment_id,p.version payment_version,
        i.id intent_id,i.version intent_version,t.external_transaction_id
      from private.gd6c_race_fixtures f join public.payments p on p.id=f.payment_id
      join private.payment_bank_intents i on i.payment_id=p.id
      join private.bank_transactions t on t.external_transaction_id='tx-'||f.i
        or (f.i=10 and t.external_transaction_id='tx-10-reconcile-second')
      where f.i in (9,10,11);
      create function public.gd6c_try_payment_reconcile(
        p_i integer,p_external_transaction_id text,p_operation_id uuid
      ) returns text language plpgsql security definer set search_path='' as $$
      declare f private.reconciliation_race_fixtures;
      begin
        select * into f from private.reconciliation_race_fixtures
          where i=p_i and (p_external_transaction_id is null or external_transaction_id=p_external_transaction_id);
        perform public.admin_reconcile_bank_transaction(f.transaction_id,f.payment_id,f.transaction_version,
          f.payment_version,f.intent_version,'native verified reconciliation evidence',p_operation_id);
        return 'ok';
      exception when others then return sqlstate||':'||sqlerrm;
      end $$;
      revoke all on function public.gd6c_try_payment_reconcile(integer,text,uuid) from public,anon,service_role;
      grant execute on function public.gd6c_try_payment_reconcile(integer,text,uuid) to authenticated;`);

    async function reconciliationCall(application, actor, fixtureI, externalTransactionId, operation, hold = false) {
      return sql(`set application_name='${application}'; set request.jwt.claim.sub='${actor}'; set role authenticated;
        ${hold ? 'begin;' : ''}
        select public.gd6c_try_payment_reconcile(${fixtureI},${externalTransactionId == null ? 'null' : `'${externalTransactionId}'`},'${operation}'::uuid);
        ${hold ? 'select pg_sleep(3); commit;' : ''}`);
    }

    const sameTransactionFirst = reconciliationCall('reconcile_same_first','a1710000-0000-4000-8000-000000000002',
      9,null,'a1711000-0000-4000-8000-000000000001',true);
    await awaitActivity('reconcile_same_first', "wait_event='PgSleep'");
    const sameTransactionSecond = reconciliationCall('reconcile_same_second','a1710000-0000-4000-8000-000000000003',
      9,null,'a1711000-0000-4000-8000-000000000002');
    await awaitActivity('reconcile_same_second', "wait_event_type='Lock'");
    const sameTransactionRace = await Promise.all([sameTransactionFirst, sameTransactionSecond]);
    assert.equal(sameTransactionRace[0], 'ok');
    assert.equal(sameTransactionRace[1], '40001:STALE_VERSION');
    assert.equal(await sql(`select p.status||'|'||count(s.id)::text||'|'||
      (select count(*) from public.payment_events e where e.payment_id=p.id and e.event_type='bank_payment_verified')::text
      from private.reconciliation_race_fixtures f join public.payments p on p.id=f.payment_id
      left join private.payment_reconciliation_settlements s on s.payment_id=p.id where f.i=9 group by p.id`), 'paid|1|1');
    console.log('PASS concurrent reconciliation same transaction -> one immutable settlement');

    const competingFirst = reconciliationCall('reconcile_payment_first','a1710000-0000-4000-8000-000000000002',
      10,'tx-10','a1711000-0000-4000-8000-000000000003',true);
    await awaitActivity('reconcile_payment_first', "wait_event='PgSleep'");
    const competingSecond = reconciliationCall('reconcile_payment_second','a1710000-0000-4000-8000-000000000003',
      10,'tx-10-reconcile-second','a1711000-0000-4000-8000-000000000004');
    await awaitActivity('reconcile_payment_second', "wait_event_type='Lock'");
    const competingRace = await Promise.all([competingFirst, competingSecond]);
    assert.equal(competingRace[0], 'ok');
    assert.equal(competingRace[1], '40001:STALE_VERSION');
    assert.equal(await sql(`select p.status='paid'
      and (select count(*) from private.payment_reconciliation_settlements s where s.payment_id=p.id)=1
      and (select count(*) from private.bank_transactions t where t.matched_payment_id=p.id and t.status='verified')=1
      and (select count(*) from private.bank_transactions t where t.external_transaction_id in ('tx-10','tx-10-reconcile-second') and t.status='rejected')=1
      from private.gd6c_race_fixtures f join public.payments p on p.id=f.payment_id where f.i=10`), 't');
    console.log('PASS concurrent reconciliation competing transactions -> one payment settlement');

    const revokeReconcile = sql(`set application_name='reconcile_permission_revoke'; begin;
      set local request.jwt.claim.sub='a1710000-0000-4000-8000-000000000001'; set local role authenticated;
      select public.admin_set_payment_reconcile_permission('a1710000-0000-4000-8000-000000000002',false,1,'native concurrent permission revocation');
      select pg_sleep(3); commit;`);
    await awaitActivity('reconcile_permission_revoke', "wait_event='PgSleep'");
    const revokedOperator = reconciliationCall('reconcile_permission_waiter','a1710000-0000-4000-8000-000000000002',
      11,null,'a1711000-0000-4000-8000-000000000005');
    await awaitActivity('reconcile_permission_waiter', "wait_event_type='Lock'");
    const revocationRace = await Promise.all([revokeReconcile, revokedOperator]);
    assert.equal(revocationRace[1], '42501:PAYMENT_RECONCILE_FORBIDDEN');
    assert.equal(await sql(`select not g.enabled and g.version=2
      and (select count(*) from private.payment_reconcile_permission_audit a where a.admin_id=g.admin_id)=2
      and p.status='awaiting_payment' and t.status='rejected'
      and not exists(select 1 from private.payment_reconciliation_settlements s where s.payment_id=p.id)
      from private.payment_reconcile_permissions g cross join private.reconciliation_race_fixtures f
      join public.payments p on p.id=f.payment_id join private.bank_transactions t on t.id=f.transaction_id
      where g.admin_id='a1710000-0000-4000-8000-000000000002' and f.i=11`), 't');
    console.log('PASS concurrent reconciliation permission revocation -> waiting operator denied');

    await sql(`insert into auth.users(id,email) values
      ('a1600000-0000-4000-8000-000000000001','system-race-super@example.invalid'),
      ('a1600000-0000-4000-8000-000000000002','system-race-operator@example.invalid');
      insert into public.admin_profiles(id,full_name,role,status) values
      ('a1600000-0000-4000-8000-000000000001','System race super','super_admin','active'),
      ('a1600000-0000-4000-8000-000000000002','System race operator','operator','active');`);
    const tryPatch = `create function pg_temp.try_system_patch(p_patch jsonb,p_version bigint) returns text language plpgsql as $$
      begin perform public.admin_apply_system_config(p_patch,p_version,'native concurrent regression',true); return 'OK';
      exception when others then return SQLSTATE||':'||SQLERRM; end $$;`;
    const firstConfig = sql(`set application_name='system_config_first'; begin;
      set local request.jwt.claim.sub='a1600000-0000-4000-8000-000000000001'; set local role authenticated;
      select public.admin_apply_system_config('{"customer.banner":"first writer"}',1,'native concurrent regression',true)->>'version';
      select pg_sleep(3); commit;`);
    await awaitActivity('system_config_first', "wait_event='PgSleep'");
    const secondConfig = sql(`${tryPatch} set application_name='system_config_second';
      set request.jwt.claim.sub='a1600000-0000-4000-8000-000000000001'; set role authenticated;
      select pg_temp.try_system_patch('{"customer.banner":"second writer"}',1);`);
    await awaitActivity('system_config_second', "wait_event_type='Lock'");
    const configRace = await Promise.all([firstConfig, secondConfig]);
    assert.equal(configRace[1], '40001:SYSTEM_CONFIG_VERSION_CONFLICT');
    assert.equal(await sql(`select version=2 and values->>'customer.banner'='first writer'
      and (select count(*) from private.system_config_audit)=1 from private.system_config`), 't');
    console.log('PASS concurrent system config -> one update, one version conflict, one audit');

    // A waiting operator must use the committed, locked permission matrix, not an old STABLE snapshot.
    const revokePermission = sql(`set application_name='system_config_revoke'; begin;
      set local request.jwt.claim.sub='a1600000-0000-4000-8000-000000000001'; set local role authenticated;
      select public.admin_apply_system_config('{"security.role_permissions":{"customer":["super_admin"],"rescuer":["super_admin","operator"],"payment":["super_admin","finance"],"security":["super_admin"]}}',2,'native revoke permission',true)->>'version';
      select pg_sleep(3); commit;`);
    await awaitActivity('system_config_revoke', "wait_event='PgSleep'");
    const waitingOperator = sql(`${tryPatch} set application_name='system_config_operator';
      set request.jwt.claim.sub='a1600000-0000-4000-8000-000000000002'; set role authenticated;
      select pg_temp.try_system_patch('{"customer.banner":"unauthorized"}',3);`);
    await awaitActivity('system_config_operator', "wait_event_type='Lock'");
    const permissionRace = await Promise.all([revokePermission, waitingOperator]);
    assert.equal(permissionRace[1], '42501:SYSTEM_CONFIG_FORBIDDEN');
    assert.equal(await sql(`select version=3 and values->>'customer.banner'='first writer'
      and (select count(*) from private.system_config_audit)=2 from private.system_config`), 't');
    console.log('PASS concurrent permission revocation -> waiting operator denied, no unauthorized audit');
    const firstAccount = sql(`set application_name='system_account_first'; begin;
      set local request.jwt.claim.sub='a1600000-0000-4000-8000-000000000001'; set local role authenticated;
      select public.admin_apply_system_account_control('a1600000-0000-4000-8000-000000000002','suspended',null,false,0,'native account race',true)->>'version';
      select pg_sleep(3); commit;`);
    await awaitActivity('system_account_first', "wait_event='PgSleep'");
    const secondAccount = sql(`create function pg_temp.try_system_account() returns text language plpgsql as $$
      begin perform public.admin_apply_system_account_control('a1600000-0000-4000-8000-000000000002','active',null,false,0,'native account race',true); return 'OK';
      exception when others then return SQLSTATE||':'||SQLERRM; end $$;
      set application_name='system_account_second'; set request.jwt.claim.sub='a1600000-0000-4000-8000-000000000001'; set role authenticated;
      select pg_temp.try_system_account();`);
    await awaitActivity('system_account_second', "wait_event_type='Lock'");
    const accountRace = await Promise.all([firstAccount, secondAccount]);
    assert.equal(accountRace[1], '40001:SYSTEM_CONFIG_VERSION_CONFLICT');
    assert.equal(await sql(`select status='suspended' and version=1 from private.system_account_controls
      where user_id='a1600000-0000-4000-8000-000000000002'`), 't');
    console.log('PASS concurrent initial account control -> one insert, one version conflict');
  } finally {
    // Only the freshly created, random name above can be removed. Never uses a
    // supplied database name, wildcard, or FORCE against unrelated sessions.
    if (created) await sql(`drop database ${name}`, 'postgres');
  }
}
