-- DISPOSABLE LOCAL DATABASE ONLY. No production/linked Supabase execution.
-- Apply shared schema, GD1, then GD2A. Admin/display-code migrations optional.
-- Privileged connection: SET payment.test_mode='local_disposable';
-- psql: use -X -v ON_ERROR_STOP=1. Everything rolls back except sequence values.
-- This single-session suite does NOT prove two-connection concurrency.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
do $guard$
begin
  if current_setting('payment.test_mode',true) is distinct from 'local_disposable'
     or not exists (select 1 from pg_catalog.pg_roles where rolname=current_user and (rolsuper or rolbypassrls)) then
    raise exception 'PAYMENT_TEST_REFUSED: privileged local_disposable opt-in required';
  end if;
  if exists(select 1 from auth.users where id::text like '81000000-0000-4000-8000-%') then
    raise exception 'PAYMENT_TEST_REFUSED: fixture namespace occupied';
  end if;
end;
$guard$;
create temp table prepare_results(label text primary key) on commit drop;
create temp table prepare_dto(label text primary key, dto jsonb) on commit drop;
grant select,insert on pg_temp.prepare_results,pg_temp.prepare_dto to authenticated,anon;
create function pg_temp.prepare_assert(p_label text,p_ok boolean) returns void
language plpgsql security invoker as $$
begin
  if p_ok is distinct from true then raise exception 'TEST_FAIL: %',p_label; end if;
  insert into pg_temp.prepare_results values(p_label);
end;
$$;
create function pg_temp.prepare_error(p_label text,p_sql text,p_state text,p_message text default null)
returns void language plpgsql security invoker as $$
declare v_state text; v_message text; v_detail text;
begin
  begin execute p_sql;
  exception when others then
    get stacked diagnostics v_state=returned_sqlstate,v_message=message_text,v_detail=pg_exception_detail;
  end;
  perform pg_temp.prepare_assert(p_label,v_state is not distinct from p_state
    and (p_message is null or (v_message=p_message and coalesce(v_detail,'')='')));
end;
$$;

select pg_temp.prepare_assert('two exact UUID-only definer signatures with fixed search_path',
  (select count(*)=2 and bool_and(prosecdef and 'search_path=""'=any(proconfig)
    and pronargs=1 and proargtypes='2950'::oidvector and prorettype='jsonb'::regtype)
   from pg_catalog.pg_proc where oid in
   ('public.customer_prepare_payment(uuid)'::regprocedure,'public.customer_get_payment(uuid)'::regprocedure)));
select pg_temp.prepare_assert('authenticated EXECUTE; anon and PUBLIC denied',
  (select bool_and(pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE')
    and not pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE')
    and not exists(select 1 from pg_catalog.aclexplode(p.proacl) a where a.grantee=0 and a.privilege_type='EXECUTE'))
   from pg_catalog.pg_proc p where p.oid in
   ('public.customer_prepare_payment(uuid)'::regprocedure,'public.customer_get_payment(uuid)'::regprocedure)));
do $service_acl$
begin
  if exists(select 1 from pg_catalog.pg_roles where rolname='service_role') then
    perform pg_temp.prepare_assert('service role has no customer RPC EXECUTE',
      not pg_catalog.has_function_privilege('service_role','public.customer_prepare_payment(uuid)','EXECUTE')
      and not pg_catalog.has_function_privilege('service_role','public.customer_get_payment(uuid)','EXECUTE'));
  end if;
end;
$service_acl$;
select pg_temp.prepare_assert('RLS remains enabled; only two participant SELECT policies',
  (select count(*)=2 from pg_catalog.pg_class where oid in
    ('public.payments'::regclass,'public.payment_events'::regclass) and relrowsecurity)
  and (select count(*)=2 and bool_and(cmd='SELECT' and roles=array['authenticated']::name[])
    from pg_catalog.pg_policies where schemaname='public' and tablename='payments')
  and not exists(select 1 from pg_catalog.pg_policies where schemaname='public' and tablename='payment_events'));
select pg_temp.prepare_assert('no out-of-scope RPCs or realtime added',
  not exists(select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in
      ('customer_select_payment_method','rescuer_confirm_cash_received','internal_confirm_bank_payment','get_customer_payment_qr'))
  and not exists(select 1 from pg_catalog.pg_publication_tables
    where schemaname='public' and tablename in ('payments','payment_events')));

select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);
insert into auth.users(id,email)
select ('81000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
  'prepare-test-'||i::text||'@example.invalid' from generate_series(1,5) i;
insert into public.rescuer_profiles(user_id,full_name,contact_phone,verification_status) values
 ('81000000-0000-4000-8000-000000000003','Prepare rescuer A','0900000003','approved'),
 ('81000000-0000-4000-8000-000000000004','Prepare rescuer B','0900000004','approved');
insert into public.rescuer_vehicles(id,rescuer_id,kind,display_name,license_plate,verification_status) values
 ('86000000-0000-4000-8000-000000000003','81000000-0000-4000-8000-000000000003','service_motorbike','Fixture A','PREPAREA','approved'),
 ('86000000-0000-4000-8000-000000000004','81000000-0000-4000-8000-000000000004','service_motorbike','Fixture B','PREPAREB','approved');
do $fixtures$
declare i integer; c uuid; r uuid; v uuid; req uuid; a uuid; q uuid;
  t timestamptz:=clock_timestamp(); price integer;
begin
  for i in 1..5 loop
    c:=('81000000-0000-4000-8000-'||lpad((case when i=2 then 2 else 1 end)::text,12,'0'))::uuid;
    r:=('81000000-0000-4000-8000-'||lpad((case when i=2 then 4 else 3 end)::text,12,'0'))::uuid;
    v:=('86000000-0000-4000-8000-'||lpad((case when i=2 then 4 else 3 end)::text,12,'0'))::uuid;
    req:=('82000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
    a:=('83000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
    q:=('84000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
    price:=case when i=5 then 0 else 100000*i end;
    insert into public.rescue_requests(id,customer_id,client_request_id,vehicle_kind,service_code,
      location_text,location_confirmed,contact_name,contact_phone,status,provider_id)
    values(req,c,gen_random_uuid(),'motorbike','tire','Synthetic prepare fixture',true,'Fixture','0900000001','in_progress',r);
    insert into public.rescue_request_assignments(id,request_id,rescuer_id,vehicle_id,state,
      accepted_at,en_route_at,arrived_at,in_progress_at)
    values(a,req,r,v,'in_progress',t,t,t,t);
    insert into public.rescue_quotes(id,assignment_id,request_id,rescuer_id,revision,total_vnd,items)
    values(q,a,req,r,1,price,jsonb_build_array(jsonb_build_object('service_code','tire','quantity',1,'unit_price_vnd',price)));
    update public.rescue_request_assignments set current_quote_id=q,completion_quote_id=q,state='completed',completed_at=t where id=a;
    update public.rescue_requests set status='completed',quoted_price=price where id=req;
  end loop;
  insert into public.rescue_requests(id,customer_id,client_request_id,vehicle_kind,service_code,
    location_text,location_confirmed,contact_name,contact_phone,status)
  values('82000000-0000-4000-8000-000000000006',c,gen_random_uuid(),'motorbike','tire','Legacy no assignment',true,'Fixture','0900000001','completed');
end;
$fixtures$;
set constraints all immediate;
set constraints all deferred;

set local role authenticated;
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000001',true);
select pg_temp.prepare_assert('get absent owned payment is NULL',public.customer_get_payment('82000000-0000-4000-8000-000000000004') is null);
insert into pg_temp.prepare_dto values('first',public.customer_prepare_payment('82000000-0000-4000-8000-000000000001'));
select pg_temp.prepare_assert('own completed prepare succeeds',(select dto->>'payment_id' is not null from pg_temp.prepare_dto where label='first'));
select pg_temp.prepare_assert('new payment pending',(select dto->>'status'='pending' from pg_temp.prepare_dto where label='first'));
select pg_temp.prepare_assert('new method NULL',(select dto->'method'='null'::jsonb from pg_temp.prepare_dto where label='first'));
select pg_temp.prepare_assert('completion quote amount snapshot',(select dto->>'amount_expected'='100000' from pg_temp.prepare_dto where label='first'));
select pg_temp.prepare_assert('quote and assignment snapshot',
  (select dto->>'quote_id'='84000000-0000-4000-8000-000000000001'
    and dto->>'assignment_id'='83000000-0000-4000-8000-000000000001' from pg_temp.prepare_dto where label='first'));
select pg_temp.prepare_assert('TT generated by GD1',(select dto->>'payment_code' ~ '^TT-[0-9]{6,}$' from pg_temp.prepare_dto where label='first'));
select pg_temp.prepare_assert('money and version use lossless decimal strings',
  (select jsonb_typeof(dto->'amount_expected')='string' and dto->'version'='"1"'::jsonb
    and dto->'amount_received'='null'::jsonb from pg_temp.prepare_dto where label='first'));
select pg_temp.prepare_assert('exact safe 15-key DTO',
  (select array_agg(k order by k)=array['amount_expected','amount_received','assignment_id','cash_received_at',
    'created_at','currency','method','paid_at','payment_code','payment_id','quote_id','request_id','status','updated_at','version']::text[]
   from pg_temp.prepare_dto, jsonb_object_keys(dto) k where label='first'));
select pg_temp.prepare_assert('get own matches prepare',public.customer_get_payment('82000000-0000-4000-8000-000000000001')=
  (select dto from pg_temp.prepare_dto where label='first'));
select pg_temp.prepare_assert('second prepare identical with no timestamp or version reset',
  public.customer_prepare_payment('82000000-0000-4000-8000-000000000001')=(select dto from pg_temp.prepare_dto where label='first'));
select pg_temp.prepare_assert('third retry identical',
  public.customer_prepare_payment('82000000-0000-4000-8000-000000000001')=(select dto from pg_temp.prepare_dto where label='first'));
select pg_temp.prepare_error('foreign request prepare denied before payment exists',
 $$select public.customer_prepare_payment('82000000-0000-4000-8000-000000000002')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.prepare_error('foreign request get denied before payment exists',
 $$select public.customer_get_payment('82000000-0000-4000-8000-000000000002')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.prepare_error('unknown request prepare same error',
 $$select public.customer_prepare_payment('82000000-0000-4000-8000-000000000099')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.prepare_error('NULL request same error','select public.customer_prepare_payment(null)','42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.prepare_error('unknown request get same error',
 $$select public.customer_get_payment('82000000-0000-4000-8000-000000000099')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.prepare_error('zero amount needs explicit policy',
 $$select public.customer_prepare_payment('82000000-0000-4000-8000-000000000005')$$,'P0001','ZERO_AMOUNT_REQUIRES_POLICY');
select pg_temp.prepare_error('completed without assignment denied',
 $$select public.customer_prepare_payment('82000000-0000-4000-8000-000000000006')$$,'P0001','PAYMENT_NOT_ELIGIBLE');
select pg_temp.prepare_error('direct INSERT still denied','insert into public.payments default values','42501');
select pg_temp.prepare_error('direct UPDATE still denied', $$update public.payments set status='paid'$$,'42501');
select pg_temp.prepare_error('direct amount change denied','update public.payments set amount_expected=1','42501');
select pg_temp.prepare_error('direct DELETE still denied','delete from public.payments','42501');
select pg_temp.prepare_error('raw events SELECT still denied','select * from public.payment_events','42501');
select pg_temp.prepare_error('event INSERT denied','insert into public.payment_events default values','42501');
select pg_temp.prepare_error('event UPDATE denied', $$update public.payment_events set metadata='{}'$$,'42501');
select pg_temp.prepare_error('event DELETE denied','delete from public.payment_events','42501');
select pg_temp.prepare_error('no client TT sequence access', $$select nextval('public.payment_code_seq')$$,'42501');
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000002',true);
select pg_temp.prepare_assert('customer B creates own payment',public.customer_prepare_payment('82000000-0000-4000-8000-000000000002')->>'amount_expected'='200000');
select pg_temp.prepare_error('wrong customer cannot prepare existing A',
 $$select public.customer_prepare_payment('82000000-0000-4000-8000-000000000001')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.prepare_error('wrong customer cannot get existing A',
 $$select public.customer_get_payment('82000000-0000-4000-8000-000000000001')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.prepare_assert('RLS customer B sees only B',(select count(*)=1 and bool_and(customer_id=auth.uid()) from public.payments));
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000005',true);
select pg_temp.prepare_error('unrelated authenticated prepare denied',
 $$select public.customer_prepare_payment('82000000-0000-4000-8000-000000000001')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.prepare_error('unrelated authenticated get denied',
 $$select public.customer_get_payment('82000000-0000-4000-8000-000000000001')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.prepare_assert('unrelated RLS empty',not exists(select 1 from public.payments));
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);
select pg_temp.prepare_error('assigned rescuer cannot use customer prepare',
 $$select public.customer_prepare_payment('82000000-0000-4000-8000-000000000001')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.prepare_error('assigned rescuer cannot use customer getter',
 $$select public.customer_get_payment('82000000-0000-4000-8000-000000000001')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.prepare_assert('rescuer RLS sees own assignment only',(select count(*)=1 and bool_and(rescuer_id=auth.uid()) from public.payments));
select set_config('request.jwt.claim.sub','',true);
select pg_temp.prepare_error('missing principal prepare authentication first',
 $$select public.customer_prepare_payment('82000000-0000-4000-8000-000000000001')$$,'42501','AUTHENTICATION_REQUIRED');
select pg_temp.prepare_error('missing principal get authentication first',
 $$select public.customer_get_payment('82000000-0000-4000-8000-000000000001')$$,'42501','AUTHENTICATION_REQUIRED');
set local role anon;
select pg_temp.prepare_error('anon cannot execute prepare','select public.customer_prepare_payment(null)','42501');
select pg_temp.prepare_error('anon cannot execute get','select public.customer_get_payment(null)','42501');
select pg_temp.prepare_error('anon cannot SELECT payments','select * from public.payments','42501');
reset role;

select pg_temp.prepare_assert('exactly one payment per prepared request',(select count(*)=2 from public.payments));
select pg_temp.prepare_assert('customer snapshot from auth owner',(select customer_id='81000000-0000-4000-8000-000000000001' from public.payments where request_id='82000000-0000-4000-8000-000000000001'));
select pg_temp.prepare_assert('rescuer snapshot from assignment',(select rescuer_id='81000000-0000-4000-8000-000000000003' from public.payments where request_id='82000000-0000-4000-8000-000000000001'));
select pg_temp.prepare_assert('lifecycle NULL; VND; server timestamps',
 (select bool_and(amount_received is null and paid_at is null and cash_received_at is null
   and cash_received_by is null and verified_at is null and failed_at is null and cancelled_at is null
   and refunded_at is null and currency='VND' and created_at=updated_at and created_at>=transaction_timestamp()) from public.payments));
select pg_temp.prepare_assert('exactly one correct creation event per payment even after retries',
 (select count(*)=2 and bool_and(e.event_type='payment_created' and e.actor_type='customer'
   and e.actor_id=p.customer_id and e.old_status is null and e.new_status='pending'
   and e.amount=p.amount_expected and e.request_id=p.request_id and e.payment_version=p.version
   and e.event_sequence=1 and e.metadata='{}'::jsonb and e.operation_id is null and e.created_at>=p.created_at)
  from public.payment_events e join public.payments p on p.id=e.payment_id));
select pg_temp.prepare_assert('get and denied calls create no payments',
 not exists(select 1 from public.payments where request_id not in
 ('82000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000002')));

-- Fault injection is confined to a rollback-only subtransaction. This exercises
-- RPC defenses against corrupt/future privileged state that existing CHECK/FK
-- constraints normally prohibit. Never disable triggers or persist invalid data.
-- Statements below are constant test fixtures, not production dynamic SQL.
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000001',true);
create function pg_temp.prepare_fault(p_label text,p_setup text,p_message text,
 p_request uuid default '82000000-0000-4000-8000-000000000004') returns void
language plpgsql security invoker as $$
begin
  begin
    execute p_setup;
    execute 'set local role authenticated';
    perform pg_temp.prepare_error(p_label,
      format('select public.customer_prepare_payment(%L::uuid)',p_request),'P0001',p_message);
    raise exception using errcode='ZT001',message='ROLLBACK_SYNTHETIC_FAULT';
  exception when sqlstate 'ZT001' then null;
  end;
  perform pg_temp.prepare_assert(p_label,true);
end;
$$;
do $states$
declare s text;
begin
  foreach s in array array['searching','accepted','arriving','in_progress'] loop
    perform pg_temp.prepare_fault('request '||s||' denied',
      format($q$insert into public.rescue_requests(id,customer_id,client_request_id,vehicle_kind,service_code,
        location_text,location_confirmed,contact_name,contact_phone,status)
        values('82000000-0000-4000-8000-000000000007','81000000-0000-4000-8000-000000000001',
          gen_random_uuid(),'motorbike','tire','Synthetic state fixture',true,'Fixture','0900000001',%L)$q$,s),
      'PAYMENT_NOT_ELIGIBLE','82000000-0000-4000-8000-000000000007');
  end loop;
end;
$states$;
select pg_temp.prepare_fault('completed request with incomplete assignment denied',
 $$update public.rescue_request_assignments set state='in_progress',completed_at=null,completion_quote_id=null
   where id='83000000-0000-4000-8000-000000000004'$$,'PAYMENT_NOT_ELIGIBLE');
select pg_temp.prepare_fault('provider assignment mismatch denied',
 $$update public.rescue_requests set provider_id='81000000-0000-4000-8000-000000000004'
   where id='82000000-0000-4000-8000-000000000004'$$,'PAYMENT_NOT_ELIGIBLE');
select pg_temp.prepare_fault('completion quote absent denied',
 $setup$do $body$ declare c record; begin
   for c in select conname from pg_catalog.pg_constraint where conrelid='public.rescue_request_assignments'::regclass
     and contype='c' and pg_catalog.pg_get_constraintdef(oid) like '%completion_quote_id IS NOT NULL%' loop
     execute format('alter table public.rescue_request_assignments drop constraint %I',c.conname);
   end loop;
   update public.rescue_request_assignments set completion_quote_id=null where id='83000000-0000-4000-8000-000000000004';
 end; $body$ $setup$,'PAYMENT_NOT_ELIGIBLE');
select pg_temp.prepare_fault('completion quote from another assignment denied',
 $$alter table public.rescue_request_assignments alter constraint rescuer_completion_quote_fk deferrable initially deferred;
 update public.rescue_request_assignments set completion_quote_id='84000000-0000-4000-8000-000000000001'
   where id='83000000-0000-4000-8000-000000000004'$$,'QUOTE_SNAPSHOT_INCONSISTENT');
select pg_temp.prepare_fault('request quote amount mismatch denied',
 $$update public.rescue_requests set quoted_price=1 where id='82000000-0000-4000-8000-000000000004'$$,'QUOTE_SNAPSHOT_INCONSISTENT');
select pg_temp.prepare_fault('superseded completion quote denied',
 $$update public.rescue_quotes set status='superseded' where id='84000000-0000-4000-8000-000000000004'$$,'QUOTE_SNAPSHOT_INCONSISTENT');
select pg_temp.prepare_fault('current quote differs from completion denied',
 $$update public.rescue_request_assignments set current_quote_id=null where id='83000000-0000-4000-8000-000000000004'$$,'QUOTE_SNAPSHOT_INCONSISTENT');

-- Force an audit constraint failure: payment INSERT must roll back with it.
alter table public.payment_events add constraint prepare_test_event_failure
 check(request_id<>'82000000-0000-4000-8000-000000000003'::uuid);
set local role authenticated;
select pg_temp.prepare_error('audit failure sanitized',
 $$select public.customer_prepare_payment('82000000-0000-4000-8000-000000000003')$$,'P0001','QUOTE_SNAPSHOT_INCONSISTENT');
reset role;
select pg_temp.prepare_assert('audit failure leaves neither payment nor event',
 not exists(select 1 from public.payments where request_id='82000000-0000-4000-8000-000000000003')
 and not exists(select 1 from public.payment_events where request_id='82000000-0000-4000-8000-000000000003'));
alter table public.payment_events drop constraint prepare_test_event_failure;
set local role authenticated;
select pg_temp.prepare_assert('retry after audit failure succeeds',
 public.customer_prepare_payment('82000000-0000-4000-8000-000000000003')->>'status'='pending');
reset role;
select pg_temp.prepare_assert('recovered retry has one event',
 (select count(*)=1 from public.payment_events where request_id='82000000-0000-4000-8000-000000000003'));
select pg_temp.prepare_error('privileged snapshot mutation still blocked',
 $$update public.payments set amount_expected=1 where request_id='82000000-0000-4000-8000-000000000001'$$,'23514','PAYMENT_SNAPSHOT_IMMUTABLE');
select pg_temp.prepare_error('privileged audit deletion still blocked','delete from public.payment_events','23514','PAYMENT_EVENT_IMMUTABLE');
set constraints all immediate;
select pg_temp.prepare_assert('all constraints restored and validated',
 (select not condeferrable and convalidated from pg_catalog.pg_constraint
   where conrelid='public.rescue_request_assignments'::regclass and conname='rescuer_completion_quote_fk')
 and exists(select 1 from pg_catalog.pg_constraint where conrelid='public.rescue_request_assignments'::regclass
   and contype='c' and pg_catalog.pg_get_constraintdef(oid) like '%completion_quote_id IS NOT NULL%'));
select 'PAYMENT_CUSTOMER_PREPARE_PASS' as result,count(*) as assertions from pg_temp.prepare_results;
rollback;
