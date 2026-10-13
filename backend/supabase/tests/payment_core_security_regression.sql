-- LOCAL DISPOSABLE DATABASE ONLY. Never run on production/linked Supabase.
-- Apply shared migrations + payment core first; Admin/display codes optional.
-- Privileged setup creates synthetic fixtures. Participant checks use SET ROLE.
-- Enable explicitly on the SAME connection: SET payment.test_mode='local_disposable';
-- psql callers must use -X -v ON_ERROR_STOP=1. Fixtures/helpers roll back.
-- Sequence calls (including the >999999 test) are NOT rolled back: disposable DB only.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
do $guard$
begin
  if current_setting('payment.test_mode', true) is distinct from 'local_disposable' then
    raise exception 'PAYMENT_TEST_REFUSED: local_disposable opt-in required';
  end if;
  if not exists (select 1 from pg_catalog.pg_roles where rolname = current_user and (rolsuper or rolbypassrls)) then
    raise exception 'PAYMENT_TEST_REFUSED: privileged disposable setup required';
  end if;
  if exists (select 1 from auth.users where id::text like '71000000-0000-4000-8000-%') then
    raise exception 'PAYMENT_TEST_REFUSED: fixture namespace already occupied';
  end if;
end;
$guard$;

create temp table payment_test_results (label text primary key) on commit drop;
grant select, insert on pg_temp.payment_test_results to authenticated, anon;
-- Test helpers run with the caller's privileges, including the statements
-- supplied as constant test cases. They create no production RPC or grant.
create function pg_temp.payment_assert(p_label text, p_condition boolean) returns void
language plpgsql security invoker as $$
begin
  if p_condition is distinct from true then raise exception 'TEST_FAIL: %', p_label; end if;
  insert into pg_temp.payment_test_results values (p_label);
end;
$$;
create function pg_temp.payment_expect_error(p_label text, p_sql text, p_state text, p_constraint text default null)
returns void language plpgsql security invoker as $$
declare v_state text; v_constraint text;
begin
  begin
    execute p_sql;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_constraint = constraint_name;
  end;
  if v_state is distinct from p_state or (p_constraint is not null and v_constraint is distinct from p_constraint) then
    raise exception 'TEST_FAIL: %, expected % / %, got % / %', p_label, p_state, p_constraint, v_state, v_constraint;
  end if;
  perform pg_temp.payment_assert(p_label,
    v_state = p_state and (p_constraint is null or v_constraint = p_constraint));
end;
$$;

select pg_temp.payment_assert('RLS enabled on both tables',
  (select count(*) = 2 from pg_catalog.pg_class
    where oid in ('public.payments'::regclass, 'public.payment_events'::regclass) and relrowsecurity));
select pg_temp.payment_assert('only two participant SELECT policies; no write/event policies',
  (select count(*) = 2 and bool_and(cmd = 'SELECT' and roles = array['authenticated']::name[])
    from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'payments')
  and not exists (select 1 from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'payment_events'));
select pg_temp.payment_assert('all financial FKs RESTRICT and validated',
  (select count(*) = 8 and bool_and(confdeltype = 'r' and convalidated and not condeferrable)
    from pg_catalog.pg_constraint where contype = 'f'
      and conrelid in ('public.payments'::regclass, 'public.payment_events'::regclass)));
select pg_temp.payment_assert('three explicit query indexes',
  (select count(*) = 3 from pg_catalog.pg_indexes where schemaname = 'public'
    and indexname in ('payments_customer_created_idx', 'payments_rescuer_created_idx', 'payments_status_created_idx')));
select pg_temp.payment_assert('helpers are invoker and fixed search_path',
  (select count(*) = 2 and bool_and(not prosecdef and 'search_path=""' = any(proconfig))
    from pg_catalog.pg_proc where oid in
      ('private.payment_core_guard()'::regprocedure, 'private.payment_event_core_guard()'::regprocedure)));
select pg_temp.payment_assert('no realtime publication added',
  not exists (select 1 from pg_catalog.pg_publication_tables
    where schemaname = 'public' and tablename in ('payments', 'payment_events')));
select pg_temp.payment_assert('no payment mutation RPCs',
  to_regprocedure('public.customer_prepare_payment(uuid)') is null
  and not exists (select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in
      ('customer_select_payment_method', 'rescuer_confirm_cash_received', 'internal_confirm_bank_payment')));

do $acl$
declare v_role text; v_table text; v_privilege text;
begin
  foreach v_role in array array['anon', 'authenticated'] loop
    foreach v_table in array array['public.payments', 'public.payment_events'] loop
      foreach v_privilege in array array['INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'] loop
        perform pg_temp.payment_assert(v_role || ' no ' || v_privilege || ' on ' || v_table,
          not pg_catalog.has_table_privilege(v_role, v_table, v_privilege));
      end loop;
    end loop;
    perform pg_temp.payment_assert(v_role || ' no raw event SELECT',
      not pg_catalog.has_table_privilege(v_role, 'public.payment_events', 'SELECT'));
    perform pg_temp.payment_assert(v_role || ' no sequence access',
      not pg_catalog.has_sequence_privilege(v_role, 'public.payment_code_seq', 'USAGE,SELECT,UPDATE'));
    perform pg_temp.payment_assert(v_role || ' no helper EXECUTE',
      not pg_catalog.has_function_privilege(v_role, 'private.payment_core_guard()', 'EXECUTE')
      and not pg_catalog.has_function_privilege(v_role, 'private.payment_event_core_guard()', 'EXECUTE'));
  end loop;
  perform pg_temp.payment_assert('authenticated SELECT grant present',
    pg_catalog.has_table_privilege('authenticated', 'public.payments', 'SELECT'));
  perform pg_temp.payment_assert('anon SELECT absent',
    not pg_catalog.has_table_privilege('anon', 'public.payments', 'SELECT'));
  if exists (select 1 from pg_catalog.pg_roles where rolname = 'service_role') then
    perform pg_temp.payment_assert('service_role has no core table/sequence/helper ACL',
      not pg_catalog.has_table_privilege('service_role', 'public.payments', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
      and not pg_catalog.has_table_privilege('service_role', 'public.payment_events', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
      and not pg_catalog.has_sequence_privilege('service_role', 'public.payment_code_seq', 'USAGE,SELECT,UPDATE')
      and not pg_catalog.has_function_privilege('service_role', 'private.payment_core_guard()', 'EXECUTE')
      and not pg_catalog.has_function_privilege('service_role', 'private.payment_event_core_guard()', 'EXECUTE'));
  end if;
end;
$acl$;

select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{}', true);
insert into auth.users(id, email)
select ('71000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
  'payment-core-' || i::text || '@example.invalid' from generate_series(1, 6) i;
do $admin_fixture$
begin
  if to_regclass('public.admin_profiles') is not null then
    insert into public.admin_profiles(id,full_name,role)
      values('71000000-0000-4000-8000-000000000006','Payment fixture admin','super_admin');
  end if;
end;
$admin_fixture$;
insert into public.rescuer_profiles(user_id, full_name, contact_phone, verification_status) values
  ('71000000-0000-4000-8000-000000000003', 'Payment fixture rescuer A', '0900000003', 'approved'),
  ('71000000-0000-4000-8000-000000000004', 'Payment fixture rescuer B', '0900000004', 'approved');
insert into public.rescuer_vehicles(id, rescuer_id, kind, display_name, license_plate, verification_status) values
  ('76000000-0000-4000-8000-000000000003', '71000000-0000-4000-8000-000000000003', 'service_motorbike', 'Fixture A', 'PAYTESTA', 'approved'),
  ('76000000-0000-4000-8000-000000000004', '71000000-0000-4000-8000-000000000004', 'service_motorbike', 'Fixture B', 'PAYTESTB', 'approved');

-- Direct privileged fixture setup preserves existing deferred consistency
-- triggers; no disabled triggers, client grants, or payment business RPCs.
do $fixtures$
declare i integer; v_customer uuid; v_rescuer uuid; v_request uuid; v_assignment uuid;
  v_quote uuid; v_vehicle uuid; v_now timestamptz := clock_timestamp();
begin
  for i in 1..4 loop
    v_customer := ('71000000-0000-4000-8000-' || lpad((case when i % 2 = 1 then 1 else 2 end)::text, 12, '0'))::uuid;
    v_rescuer := ('71000000-0000-4000-8000-' || lpad((case when i % 2 = 1 then 3 else 4 end)::text, 12, '0'))::uuid;
    v_vehicle := ('76000000-0000-4000-8000-' || lpad((case when i % 2 = 1 then 3 else 4 end)::text, 12, '0'))::uuid;
    v_request := ('72000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid;
    v_assignment := ('73000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid;
    v_quote := ('74000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid;
    insert into public.rescue_requests(id, customer_id, client_request_id, vehicle_kind, service_code,
      location_text, location_confirmed, contact_name, contact_phone, status, provider_id)
    values(v_request, v_customer, gen_random_uuid(), 'motorbike', 'tire', 'Synthetic payment test', true,
      'Synthetic customer', '0900000001', 'in_progress', v_rescuer);
    insert into public.rescue_request_assignments(id, request_id, rescuer_id, vehicle_id, state,
      accepted_at, en_route_at, arrived_at, in_progress_at)
    values(v_assignment, v_request, v_rescuer, v_vehicle, 'in_progress', v_now, v_now, v_now, v_now);
    insert into public.rescue_quotes(id, assignment_id, request_id, rescuer_id, revision, total_vnd, items)
    values(v_quote, v_assignment, v_request, v_rescuer, 1, 100000 * i,
      jsonb_build_array(jsonb_build_object('service_code', 'tire', 'quantity', 1, 'unit_price_vnd', 100000 * i)));
    update public.rescue_request_assignments set current_quote_id = v_quote,
      state = case when i < 4 then 'completed' else 'in_progress' end,
      completion_quote_id = case when i < 4 then v_quote end,
      completed_at = case when i < 4 then v_now end where id = v_assignment;
    update public.rescue_requests set quoted_price = 100000 * i,
      status = case when i < 4 then 'completed' else 'in_progress' end where id = v_request;
    if i < 3 then
      insert into public.payments(id, request_id, assignment_id, customer_id, rescuer_id, quote_id,
        amount_expected, created_at, updated_at)
      values(('75000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        v_request, v_assignment, v_customer, v_rescuer, v_quote, 100000 * i, '2000-01-01', '2000-01-01');
    end if;
  end loop;
end;
$fixtures$;
set constraints all immediate;

insert into public.payment_events(payment_id, request_id, event_type, actor_type, new_status,
  amount, payment_version, event_sequence, created_at)
select id, request_id, 'payment_created', 'system', 'pending', amount_expected, version, 1, '2000-01-01'
from public.payments where id in ('75000000-0000-4000-8000-000000000001', '75000000-0000-4000-8000-000000000002');
select pg_temp.payment_assert('server timestamps override supplied values',
  (select bool_and(created_at > '2000-01-02' and created_at = updated_at) from public.payments)
  and (select bool_and(created_at > '2000-01-02') from public.payment_events));

set local role authenticated;
select set_config('request.jwt.claim.sub', '71000000-0000-4000-8000-000000000001', true);
select pg_temp.payment_assert('01 customer A sees payment A',
  (select count(*) = 1 from public.payments where id = '75000000-0000-4000-8000-000000000001'));
select pg_temp.payment_assert('02 customer A cannot see payment B',
  not exists(select 1 from public.payments where id = '75000000-0000-4000-8000-000000000002'));
select pg_temp.payment_assert('customer broad SELECT still only one row', (select count(*) = 1 from public.payments));
select pg_temp.payment_expect_error('07 authenticated INSERT denied', 'insert into public.payments default values', '42501');
select pg_temp.payment_expect_error('08 authenticated UPDATE denied', 'update public.payments set updated_at=now()', '42501');
select pg_temp.payment_expect_error('09 authenticated DELETE denied', 'delete from public.payments', '42501');
select pg_temp.payment_expect_error('10 amount tampering denied', 'update public.payments set amount_expected=1', '42501');
select pg_temp.payment_expect_error('11a customer identity tampering denied',
  $$update public.payments set customer_id='71000000-0000-4000-8000-000000000002'$$, '42501');
select pg_temp.payment_expect_error('11b rescuer identity tampering denied',
  $$update public.payments set rescuer_id='71000000-0000-4000-8000-000000000004'$$, '42501');
select pg_temp.payment_expect_error('12 status tampering denied', $$update public.payments set status='paid'$$, '42501');
select pg_temp.payment_expect_error('13 client event INSERT denied', 'insert into public.payment_events default values', '42501');
select pg_temp.payment_expect_error('14 client event UPDATE denied', $$update public.payment_events set metadata='{}'$$, '42501');
select pg_temp.payment_expect_error('15 client event DELETE denied', 'delete from public.payment_events', '42501');
select pg_temp.payment_expect_error('raw event SELECT denied', 'select * from public.payment_events', '42501');
select pg_temp.payment_expect_error('client sequence nextval denied', $$select nextval('public.payment_code_seq')$$, '42501');
select pg_temp.payment_expect_error('client helper invocation denied', 'select private.payment_core_guard()', '42501');
select pg_temp.payment_expect_error('client TRUNCATE payment denied', 'truncate public.payments cascade', '42501');
select pg_temp.payment_expect_error('client TRUNCATE events denied', 'truncate public.payment_events', '42501');
set local row_security = off;
select pg_temp.payment_expect_error('row_security off cannot bypass RLS', 'select * from public.payments', '42501');
set local row_security = on;

select set_config('request.jwt.claim.sub', '71000000-0000-4000-8000-000000000002', true);
select pg_temp.payment_assert('customer B sees only B',
  (select count(*) = 1 and bool_and(id = '75000000-0000-4000-8000-000000000002') from public.payments));
select set_config('request.jwt.claim.sub', '71000000-0000-4000-8000-000000000003', true);
select pg_temp.payment_assert('03 rescuer A sees A',
  exists(select 1 from public.payments where id = '75000000-0000-4000-8000-000000000001'));
select pg_temp.payment_assert('04 rescuer A cannot see B',
  not exists(select 1 from public.payments where id = '75000000-0000-4000-8000-000000000002'));
select pg_temp.payment_assert('rescuer broad SELECT only its assignment', (select count(*) = 1 from public.payments));
select pg_temp.payment_expect_error('rescuer direct paid denied', $$update public.payments set status='paid'$$, '42501');
select pg_temp.payment_expect_error('rescuer raw event SELECT denied', 'select * from public.payment_events', '42501');
select set_config('request.jwt.claim.sub', '71000000-0000-4000-8000-000000000004', true);
select pg_temp.payment_assert('rescuer B sees only B',
  (select count(*) = 1 and bool_and(id = '75000000-0000-4000-8000-000000000002') from public.payments));
select set_config('request.jwt.claim.sub', '71000000-0000-4000-8000-000000000005', true);
select pg_temp.payment_assert('05 unrelated authenticated sees nothing', not exists(select 1 from public.payments));
select set_config('request.jwt.claims', '{"role":"service_role","user_metadata":{"role":"super_admin"}}', true);
select pg_temp.payment_assert('forged role metadata does not authorize SELECT', not exists(select 1 from public.payments));
select pg_temp.payment_expect_error('forged role metadata does not authorize UPDATE', $$update public.payments set status='paid'$$, '42501');
select set_config('request.jwt.claim.sub', '71000000-0000-4000-8000-000000000006', true);
select pg_temp.payment_assert('admin has no financial read override in core phase', not exists(select 1 from public.payments));
select pg_temp.payment_expect_error('admin cannot read raw events in core phase', 'select * from public.payment_events', '42501');
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{}', true);
select pg_temp.payment_assert('missing UID fails closed', not exists(select 1 from public.payments));
set local role anon;
select pg_temp.payment_expect_error('06 anon SELECT denied', 'select * from public.payments', '42501');
select pg_temp.payment_expect_error('anon event SELECT denied', 'select * from public.payment_events', '42501');
reset role;

-- Candidate request 3 has a valid completed quote and no payment yet.
create temp view payment_test_candidate as
select r.id as request_id, a.id as assignment_id, r.customer_id, a.rescuer_id,
  q.id as quote_id, q.total_vnd::bigint as amount_expected
from public.rescue_requests r join public.rescue_request_assignments a on a.request_id = r.id
join public.rescue_quotes q on q.id = a.current_quote_id
where r.id = '72000000-0000-4000-8000-000000000003';

select pg_temp.payment_expect_error('16a request/customer composite FK rejects mismatch',
  $$insert into public.payments(request_id,assignment_id,customer_id,rescuer_id,quote_id,amount_expected)
    select request_id,assignment_id,'71000000-0000-4000-8000-000000000002',rescuer_id,quote_id,amount_expected
    from pg_temp.payment_test_candidate$$, '23503', 'payments_request_customer_fk');
select pg_temp.payment_expect_error('16b assignment/rescuer composite FK rejects mismatch',
  $$insert into public.payments(request_id,assignment_id,customer_id,rescuer_id,quote_id,amount_expected)
    select request_id,assignment_id,customer_id,'71000000-0000-4000-8000-000000000004',quote_id,amount_expected
    from pg_temp.payment_test_candidate$$, '23503', 'payments_assignment_identity_fk');
select pg_temp.payment_expect_error('16c assignment/request composite FK rejects mismatch',
  $$insert into public.payments(request_id,assignment_id,customer_id,rescuer_id,quote_id,amount_expected)
    select request_id,'73000000-0000-4000-8000-000000000001',customer_id,rescuer_id,
      '74000000-0000-4000-8000-000000000001',amount_expected from pg_temp.payment_test_candidate$$,
  '23503', 'payments_assignment_identity_fk');
select pg_temp.payment_expect_error('16d quote/assignment composite FK rejects mismatch',
  $$insert into public.payments(request_id,assignment_id,customer_id,rescuer_id,quote_id,amount_expected)
    select request_id,assignment_id,customer_id,rescuer_id,'74000000-0000-4000-8000-000000000001',amount_expected
    from pg_temp.payment_test_candidate$$, '23503', 'payments_quote_assignment_fk');
select pg_temp.payment_expect_error('17 event request mismatch rejected',
  $$insert into public.payment_events(payment_id,request_id,event_type,actor_type,new_status,payment_version,event_sequence)
    values('75000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000002',
      'payment_created','system','pending',1,2)$$, '23503', 'payment_events_payment_request_fk');
select pg_temp.payment_expect_error('18 duplicate request payment rejected',
  $$insert into public.payments(request_id,assignment_id,customer_id,rescuer_id,quote_id,amount_expected)
    select request_id,assignment_id,customer_id,rescuer_id,quote_id,amount_expected
    from public.payments where id='75000000-0000-4000-8000-000000000001'$$,
  '23505', 'payments_request_id_key');

-- Explicit codes are forbidden, including privileged imports. Exercise the
-- UNIQUE index itself by simulating sequence drift only in this disposable DB.
select pg_temp.payment_expect_error('caller-supplied payment code rejected',
  $$insert into public.payments(payment_code,request_id,assignment_id,customer_id,rescuer_id,quote_id,amount_expected)
    select 'TT-000001',request_id,assignment_id,customer_id,rescuer_id,quote_id,amount_expected
    from pg_temp.payment_test_candidate$$, '23514');
do $duplicate_code$
declare v_last bigint; v_existing bigint;
begin
  select last_value into v_last from public.payment_code_seq;
  select substring(payment_code from 4)::bigint into v_existing from public.payments
    where id = '75000000-0000-4000-8000-000000000001';
  perform setval('public.payment_code_seq', v_existing, false);
  perform pg_temp.payment_expect_error('19 duplicate generated payment code rejected',
    'insert into public.payments(request_id,assignment_id,customer_id,rescuer_id,quote_id,amount_expected)
     select * from pg_temp.payment_test_candidate', '23505', 'payments_payment_code_key');
  perform setval('public.payment_code_seq', greatest(v_last, v_existing), true);
end;
$duplicate_code$;

do $immutable$
declare v_set text;
begin
  foreach v_set in array array[
    $$id=gen_random_uuid()$$, $$payment_code='TT-123456'$$,
    $$request_id='72000000-0000-4000-8000-000000000003'$$,
    $$assignment_id='73000000-0000-4000-8000-000000000003'$$,
    $$customer_id='71000000-0000-4000-8000-000000000002'$$,
    $$rescuer_id='71000000-0000-4000-8000-000000000004'$$,
    $$quote_id='74000000-0000-4000-8000-000000000003'$$,
    $$amount_expected=1$$, $$currency='USD'$$, $$created_at='2000-01-01'$$
  ] loop
    perform pg_temp.payment_expect_error('privileged snapshot immutable: ' || v_set,
      'update public.payments set ' || v_set || $$ where id='75000000-0000-4000-8000-000000000001'$$, '23514');
  end loop;
end;
$immutable$;
select pg_temp.payment_expect_error('privileged state mutation disabled', $$update public.payments set status='paid'$$, '23514');
select pg_temp.payment_expect_error('privileged method mutation disabled', $$update public.payments set method='cash'$$, '23514');
select pg_temp.payment_expect_error('privileged received amount mutation disabled', $$update public.payments set amount_received=100000$$, '23514');
select pg_temp.payment_expect_error('privileged DELETE payments forbidden', 'delete from public.payments', '23514');
select pg_temp.payment_expect_error('privileged TRUNCATE payments forbidden', 'truncate public.payments cascade', '23514');
select pg_temp.payment_expect_error('privileged UPDATE events forbidden', $$update public.payment_events set metadata='{"edited":true}'$$, '23514');
select pg_temp.payment_expect_error('privileged DELETE events forbidden', 'delete from public.payment_events', '23514');
select pg_temp.payment_expect_error('privileged TRUNCATE events forbidden', 'truncate public.payment_events', '23514');
select pg_temp.payment_expect_error('request owner cannot drift after snapshot',
  $$update public.rescue_requests set customer_id='71000000-0000-4000-8000-000000000005'
    where id='72000000-0000-4000-8000-000000000001'$$, '23503', 'payments_request_customer_fk');
select pg_temp.payment_expect_error('parent request deletion cannot cascade ledger',
  $$delete from public.rescue_requests where id='72000000-0000-4000-8000-000000000001'$$, '23001');
select pg_temp.payment_expect_error('negative/snapshot amount insert rejected',
  $$insert into public.payments(request_id,assignment_id,customer_id,rescuer_id,quote_id,amount_expected)
    select request_id,assignment_id,customer_id,rescuer_id,quote_id,-1 from pg_temp.payment_test_candidate$$, '23514');
select pg_temp.payment_expect_error('positive amount different from quote rejected',
  $$insert into public.payments(request_id,assignment_id,customer_id,rescuer_id,quote_id,amount_expected)
    select request_id,assignment_id,customer_id,rescuer_id,quote_id,1 from pg_temp.payment_test_candidate$$, '23514');
select pg_temp.payment_expect_error('uncompleted request snapshot rejected',
  $$insert into public.payments(request_id,assignment_id,customer_id,rescuer_id,quote_id,amount_expected)
    select r.id,a.id,r.customer_id,a.rescuer_id,q.id,q.total_vnd from public.rescue_requests r
    join public.rescue_request_assignments a on a.request_id=r.id join public.rescue_quotes q on q.id=a.current_quote_id
    where r.id='72000000-0000-4000-8000-000000000004'$$, '23514');
select pg_temp.payment_expect_error('reserved paid status cannot be inserted without a flow',
  $$insert into public.payments(request_id,assignment_id,customer_id,rescuer_id,quote_id,amount_expected,status)
    select request_id,assignment_id,customer_id,rescuer_id,quote_id,amount_expected,'paid' from pg_temp.payment_test_candidate$$, '23514');
select pg_temp.payment_expect_error('duplicate event sequence rejected',
  $$insert into public.payment_events(payment_id,request_id,event_type,actor_type,payment_version,event_sequence)
    select payment_id,request_id,event_type,actor_type,payment_version,event_sequence from public.payment_events limit 1$$,
  '23505', 'payment_events_sequence_key');
select pg_temp.payment_expect_error('event version mismatch rejected',
  $$insert into public.payment_events(payment_id,request_id,event_type,actor_type,payment_version,event_sequence)
    select payment_id,request_id,event_type,actor_type,2,2 from public.payment_events limit 1$$, '23514');
select pg_temp.payment_expect_error('event metadata must be an object',
  $$insert into public.payment_events(payment_id,request_id,event_type,actor_type,payment_version,event_sequence,metadata)
    select payment_id,request_id,event_type,actor_type,payment_version,2,'[]' from public.payment_events limit 1$$, '23514');
select pg_temp.payment_expect_error('event amount cannot be negative',
  $$insert into public.payment_events(payment_id,request_id,event_type,actor_type,payment_version,event_sequence,amount)
    select payment_id,request_id,event_type,actor_type,payment_version,2,-1 from public.payment_events limit 1$$, '23514');
select pg_temp.payment_expect_error('event actor cannot be forged by a trusted writer',
  $$insert into public.payment_events(payment_id,request_id,event_type,actor_type,actor_id,payment_version,event_sequence)
    select payment_id,request_id,event_type,'customer','71000000-0000-4000-8000-000000000002',payment_version,2
    from public.payment_events limit 1$$, '23514');

update public.payments set updated_at = '2000-01-01' where id = '75000000-0000-4000-8000-000000000001';
select pg_temp.payment_assert('updated_at is server managed on no-op privileged update',
  (select updated_at >= created_at and updated_at > '2000-01-02' and version = 1
    from public.payments where id = '75000000-0000-4000-8000-000000000001'));
do $code_growth$
declare v_last bigint; v_code text;
begin
  select last_value into v_last from public.payment_code_seq;
  perform setval('public.payment_code_seq', greatest(v_last, 999999), true);
  insert into public.payments(request_id,assignment_id,customer_id,rescuer_id,quote_id,amount_expected)
    select * from pg_temp.payment_test_candidate returning payment_code into v_code;
  perform pg_temp.payment_assert('TT code does not truncate after 999999',
    v_code = 'TT-' || (greatest(v_last, 999999) + 1)::text);
end;
$code_growth$;

set constraints all immediate;
select 'PAYMENT_CORE_SECURITY_PASS' as result, count(*) as assertions from pg_temp.payment_test_results;
rollback;
