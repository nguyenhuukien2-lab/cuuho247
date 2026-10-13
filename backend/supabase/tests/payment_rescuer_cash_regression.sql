-- PRIVILEGED DISPOSABLE LOCAL DB ONLY. Apply GD1 + GD2A + GD2B + GD3 first.
-- SET payment.test_mode='local_disposable' on this connection; psql -X -v ON_ERROR_STOP=1.
-- Fixtures/temporary fault injection roll back; sequence increments do not.
-- Single session: true two-connection concurrency requires a separate run.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
do $guard$
begin
  if current_setting('payment.test_mode',true) is distinct from 'local_disposable'
     or not exists(select 1 from pg_catalog.pg_roles where rolname=current_user and (rolsuper or rolbypassrls)) then
    raise exception 'PAYMENT_TEST_REFUSED: privileged local_disposable opt-in required';
  end if;
  if exists(select 1 from auth.users where id::text like '81000000-0000-4000-8000-%') then
    raise exception 'PAYMENT_TEST_REFUSED: fixture namespace occupied';
  end if;
end;
$guard$;
create temp table cash_results(label text primary key) on commit drop;
create temp table cash_fixtures(i integer primary key,request_id uuid,payment_id uuid,original jsonb) on commit drop;
create temp table cash_responses(label text primary key,response jsonb) on commit drop;
grant select,insert on pg_temp.cash_results,pg_temp.cash_responses to authenticated,anon;
grant select on pg_temp.cash_fixtures to authenticated,anon;
create function pg_temp.cash_assert(p_label text,p_ok boolean) returns void
language plpgsql security invoker as $$
begin
  if p_ok is distinct from true then raise exception 'TEST_FAIL: %',p_label; end if;
  insert into pg_temp.cash_results values(p_label);
end;
$$;
create function pg_temp.cash_error(p_label text,p_sql text,p_state text,p_message text default null)
returns void language plpgsql security invoker as $$
declare s text; m text; d text;
begin
  begin execute p_sql;
  exception when others then get stacked diagnostics s=returned_sqlstate,m=message_text,d=pg_exception_detail;
  end;
  if s is distinct from p_state or (p_message is not null and (m is distinct from p_message or coalesce(d,'')<>'')) then
    raise exception 'TEST_FAIL: %, expected % %, got % %',p_label,p_state,p_message,s,m;
  end if;
  perform pg_temp.cash_assert(p_label,true);
end;
$$;
-- Invoker wrappers; assertions always call the public RPC as authenticated.
create function pg_temp.cash_call(p_i integer,p_op uuid default '87000000-0000-4000-8000-000000000001',
 p_version bigint default 2,p_amount bigint default 100000) returns jsonb
language sql security invoker as $$
 select public.rescuer_confirm_cash_received(f.request_id,f.payment_id,p_amount,p_version,p_op)
 from pg_temp.cash_fixtures f where f.i=p_i;
$$;
create function pg_temp.cash_rpc_error(p_label text,p_i integer,p_op uuid,p_version bigint,p_amount bigint,p_state text,p_message text)
returns void language plpgsql security invoker as $$
begin
 perform pg_temp.cash_error(p_label,format('select pg_temp.cash_call(%L,%L::uuid,%L::bigint,%L::bigint)',p_i,p_op,p_version,p_amount),p_state,p_message);
end;
$$;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);
insert into auth.users(id,email) select ('81000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 'cash-selection-'||i||'@example.invalid' from generate_series(1,5) i;
insert into public.rescuer_profiles(user_id,full_name,contact_phone,verification_status) values
 ('81000000-0000-4000-8000-000000000003','Cash fixture rescuer','0900000003','approved'),
 ('81000000-0000-4000-8000-000000000004','Other rescuer','0900000004','approved');
insert into public.rescuer_vehicles(id,rescuer_id,kind,display_name,license_plate,verification_status) values
 ('86000000-0000-4000-8000-000000000003','81000000-0000-4000-8000-000000000003','service_motorbike','Cash fixture','CASHFIXTURE','approved'),
 ('86000000-0000-4000-8000-000000000004','81000000-0000-4000-8000-000000000004','service_motorbike','Other vehicle','OTHERFIXTURE','approved');
do $fixtures$
declare i integer; c uuid; req uuid; a uuid; q uuid; t timestamptz:=clock_timestamp(); dto jsonb; rescuer uuid; vehicle uuid;
begin
 for i in 1..5 loop
   rescuer:=('81000000-0000-4000-8000-'||lpad((case when i=2 then 4 else 3 end)::text,12,'0'))::uuid;
   vehicle:=('86000000-0000-4000-8000-'||lpad((case when i=2 then 4 else 3 end)::text,12,'0'))::uuid;
   c:=('81000000-0000-4000-8000-'||lpad((case when i=2 then 2 else 1 end)::text,12,'0'))::uuid;
   req:=('82000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
   a:=('83000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
   q:=('84000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
   insert into public.rescue_requests(id,customer_id,client_request_id,vehicle_kind,service_code,
    location_text,location_confirmed,contact_name,contact_phone,status,provider_id)
   values(req,c,gen_random_uuid(),'motorbike','tire','Synthetic CASH fixture',true,'Fixture','0900000001','in_progress',
    rescuer);
   insert into public.rescue_request_assignments(id,request_id,rescuer_id,vehicle_id,state,accepted_at,en_route_at,arrived_at,in_progress_at)
   values(a,req,rescuer,vehicle,'in_progress',t,t,t,t);
   insert into public.rescue_quotes(id,assignment_id,request_id,rescuer_id,revision,total_vnd,items)
   values(q,a,req,rescuer,1,100000*i,
    jsonb_build_array(jsonb_build_object('service_code','tire','quantity',1,'unit_price_vnd',100000*i)));
   update public.rescue_request_assignments set state='completed',completed_at=t,current_quote_id=q,completion_quote_id=q where id=a;
   update public.rescue_requests set status='completed',quoted_price=100000*i where id=req;
   perform set_config('request.jwt.claim.sub',c::text,true);
   dto:=public.customer_prepare_payment(req);
   perform public.customer_select_payment_method(req,(dto->>'payment_id')::uuid,'cash',1,gen_random_uuid());
   insert into pg_temp.cash_fixtures select i,req,p.id,to_jsonb(p) from public.payments p where p.id=(dto->>'payment_id')::uuid;
 end loop;
end;
$fixtures$;
set constraints all immediate;
create temp table cash_parents on commit drop as
 select f.i,to_jsonb(r) as request_row,to_jsonb(a) as assignment_row
 from pg_temp.cash_fixtures f join public.rescue_requests r on r.id=f.request_id
 join public.rescue_request_assignments a on a.request_id=r.id;
select pg_temp.cash_assert('getter signature definer empty search_path stable',
 (select prosecdef and 'search_path=""'=any(proconfig) and provolatile='s' and pronargs=1
  from pg_proc where oid='public.rescuer_get_job_payment(uuid)'::regprocedure));
select pg_temp.cash_assert('confirm exact signature definer empty search_path',
 (select prosecdef and 'search_path=""'=any(proconfig) and pronargs=5 and proargtypes='2950 2950 20 20 2950'::oidvector
  and prorettype='jsonb'::regtype from pg_proc where oid='public.rescuer_confirm_cash_received(uuid,uuid,bigint,bigint,uuid)'::regprocedure));
do $acl$
declare f text; t text; r text;
begin
 foreach f in array array['public.rescuer_get_job_payment(uuid)','public.rescuer_confirm_cash_received(uuid,uuid,bigint,bigint,uuid)'] loop
  perform pg_temp.cash_assert('authenticated only execute '||f,
    has_function_privilege('authenticated',f,'EXECUTE') and not has_function_privilege('anon',f,'EXECUTE')
    and not exists(select 1 from pg_proc p,aclexplode(p.proacl) a where p.oid=f::regprocedure and a.grantee=0));
  if exists(select 1 from pg_roles where rolname='service_role') then
   perform pg_temp.cash_assert('service role no execute '||f,not has_function_privilege('service_role',f,'EXECUTE'));
  end if;
 end loop;
 foreach r in array array['authenticated','anon'] loop
  foreach t in array array['public.payments','public.payment_events','private.rescuer_rpc_receipts','private.payment_rpc_receipts'] loop
   perform pg_temp.cash_assert(r||' no direct DML '||t,not has_table_privilege(r,t,'INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER,REFERENCES'));
  end loop;
  perform pg_temp.cash_assert(r||' no raw events receipts',not has_table_privilege(r,'public.payment_events','SELECT')
   and not has_table_privilege(r,'private.rescuer_rpc_receipts','SELECT'));
 end loop;
end;
$acl$;
select pg_temp.cash_assert('RLS and SELECT policies preserved',
 (select count(*)=4 from pg_class where oid in ('public.payments'::regclass,'public.payment_events'::regclass,
 'private.rescuer_rpc_receipts'::regclass,'private.payment_rpc_receipts'::regclass) and relrowsecurity)
 and (select count(*)=2 and bool_and(cmd='SELECT' and roles=array['authenticated']::name[]) from pg_policies where schemaname='public' and tablename='payments')
 and not exists(select 1 from pg_policy where polrelid in ('public.payment_events'::regclass,'private.rescuer_rpc_receipts'::regclass,'private.payment_rpc_receipts'::regclass)));
select pg_temp.cash_assert('payment not published',not exists(select 1 from pg_publication_tables where tablename in ('payments','payment_events')));

set local role authenticated;
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);
insert into pg_temp.cash_responses values('get',public.rescuer_get_job_payment('82000000-0000-4000-8000-000000000001'));
select pg_temp.cash_assert('own getter completed offline no GPS success',
 (select response->>'status'='awaiting_payment' and response->>'amount_expected'='100000' from pg_temp.cash_responses where label='get'));
select pg_temp.cash_assert('exact safe 15-key DTO no customer identity or raw metadata',
 (select array_agg(k order by k)=array['amount_expected','amount_received','assignment_id','cash_received_at','created_at','currency','method','paid_at','payment_code','payment_id','quote_id','request_id','status','updated_at','version']::text[]
 from pg_temp.cash_responses r, jsonb_object_keys(r.response) k where r.label='get'));
select pg_temp.cash_error('rescuer A cannot get B', $$select public.rescuer_get_job_payment('82000000-0000-4000-8000-000000000002')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_error('missing payment get same opaque error', $$select public.rescuer_get_job_payment('82000000-0000-4000-8000-000000000099')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_error('NULL get same opaque error', $$select public.rescuer_get_job_payment(null)$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_rpc_error('wrong rescuer confirm',2,'87000000-0000-4000-8000-000000000001',2,200000,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_error('wrong request confirm', $$select public.rescuer_confirm_cash_received('82000000-0000-4000-8000-000000000099',payment_id,100000,2,gen_random_uuid()) from pg_temp.cash_fixtures where i=1$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_error('wrong payment confirm', $$select public.rescuer_confirm_cash_received(request_id,'85000000-0000-4000-8000-000000000099',100000,2,gen_random_uuid()) from pg_temp.cash_fixtures where i=1$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_error('mismatched owned IDs confirm', $$select public.rescuer_confirm_cash_received('82000000-0000-4000-8000-000000000003',payment_id,100000,2,gen_random_uuid()) from pg_temp.cash_fixtures where i=1$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_rpc_error('lower amount',1,gen_random_uuid(),2,99999,'P0001','PAYMENT_AMOUNT_MISMATCH');
select pg_temp.cash_rpc_error('higher amount',1,gen_random_uuid(),2,100001,'P0001','PAYMENT_AMOUNT_MISMATCH');
select pg_temp.cash_rpc_error('negative amount',1,gen_random_uuid(),2,-1,'P0001','PAYMENT_AMOUNT_MISMATCH');
select pg_temp.cash_rpc_error('NULL amount',1,gen_random_uuid(),2,null,'P0001','PAYMENT_AMOUNT_MISMATCH');
select pg_temp.cash_error('overflow rejected before call', $$select pg_temp.cash_call(1,gen_random_uuid(),2,'9223372036854775808'::bigint)$$,'22003');
select pg_temp.cash_error('bad amount type rejected before call', $$select pg_temp.cash_call(1,gen_random_uuid(),2,'invalid'::bigint)$$,'22P02');
select pg_temp.cash_error('fractional string rejected', $$select pg_temp.cash_call(1,gen_random_uuid(),2,'100000.5'::bigint)$$,'22P02');
select pg_temp.cash_rpc_error('stale version',1,gen_random_uuid(),1,100000,'P0001','VERSION_CONFLICT');
select pg_temp.cash_rpc_error('NULL version',1,gen_random_uuid(),null,100000,'22023','INVALID_EXPECTED_VERSION');
select pg_temp.cash_rpc_error('zero version',1,gen_random_uuid(),0,100000,'22023','INVALID_EXPECTED_VERSION');
select pg_temp.cash_rpc_error('NULL operation',1,null,2,100000,'22023','IDEMPOTENCY_KEY_REQUIRED');
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000001',true);
select pg_temp.cash_error('customer cannot use rescuer getter', $$select public.rescuer_get_job_payment('82000000-0000-4000-8000-000000000001')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_rpc_error('customer cannot confirm own payment',1,gen_random_uuid(),2,100000,'42501','PAYMENT_NOT_ACCESSIBLE');
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000005',true);
select pg_temp.cash_error('unrelated cannot get', $$select public.rescuer_get_job_payment('82000000-0000-4000-8000-000000000001')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_rpc_error('unrelated cannot confirm',1,gen_random_uuid(),2,100000,'42501','PAYMENT_NOT_ACCESSIBLE');
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);
select pg_temp.cash_error('unauthenticated get', $$select public.rescuer_get_job_payment(null)$$,'42501','AUTHENTICATION_REQUIRED');
select pg_temp.cash_rpc_error('unauthenticated confirm checked first',1,null,null,null,'42501','AUTHENTICATION_REQUIRED');
set local role anon;
select pg_temp.cash_error('anon cannot execute get', $$select public.rescuer_get_job_payment(null)$$,'42501');
select pg_temp.cash_error('anon cannot execute confirm', $$select pg_temp.cash_call(1)$$,'42501');
set local role authenticated;
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);
insert into pg_temp.cash_responses values('first',pg_temp.cash_call(1));
select pg_temp.cash_assert('happy path changed true',(select response->'changed'='true'::jsonb from pg_temp.cash_responses where label='first'));
select pg_temp.cash_assert('status paid',(select response#>>'{payment,status}'='paid' from pg_temp.cash_responses where label='first'));
select pg_temp.cash_assert('amount received expected',(select response#>>'{payment,amount_received}'='100000' from pg_temp.cash_responses where label='first'));
select pg_temp.cash_assert('version plus one',(select response#>>'{payment,version}'='3' from pg_temp.cash_responses where label='first'));
insert into pg_temp.cash_responses values('retry',pg_temp.cash_call(1));
select pg_temp.cash_assert('exact retry old version current payment changed false',
 (select response->'changed'='false'::jsonb and response->'payment'=(select response->'payment' from pg_temp.cash_responses where label='first') from pg_temp.cash_responses where label='retry'));
select pg_temp.cash_assert('double tap identical retry',pg_temp.cash_call(1)=(select response from pg_temp.cash_responses where label='retry'));
select pg_temp.cash_rpc_error('same operation different amount',1,'87000000-0000-4000-8000-000000000001',2,99999,'22023','IDEMPOTENCY_CONFLICT');
select pg_temp.cash_rpc_error('same operation different version',1,'87000000-0000-4000-8000-000000000001',3,100000,'22023','IDEMPOTENCY_CONFLICT');
select pg_temp.cash_rpc_error('same operation different owned resource',3,'87000000-0000-4000-8000-000000000001',2,300000,'22023','IDEMPOTENCY_CONFLICT');
select pg_temp.cash_rpc_error('receipt never bypasses ownership',2,'87000000-0000-4000-8000-000000000001',2,200000,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_rpc_error('new key already paid stale version',1,'87000000-0000-4000-8000-000000000002',2,100000,'P0001','VERSION_CONFLICT');
select pg_temp.cash_rpc_error('new key paid different amount settled',1,gen_random_uuid(),3,99999,'P0001','PAYMENT_ALREADY_SETTLED');
insert into pg_temp.cash_responses values('noop',pg_temp.cash_call(1,'87000000-0000-4000-8000-000000000002',3));
select pg_temp.cash_assert('new key paid current version safe no-op',(select response=(select response from pg_temp.cash_responses where label='retry') from pg_temp.cash_responses where label='noop'));
select pg_temp.cash_assert('no-op receipt exact replay',pg_temp.cash_call(1,'87000000-0000-4000-8000-000000000002',3)=(select response from pg_temp.cash_responses where label='noop'));
select pg_temp.cash_rpc_error('no-op receipt payload cannot change',1,'87000000-0000-4000-8000-000000000002',2,100000,'22023','IDEMPOTENCY_CONFLICT');
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000004',true);
select pg_temp.cash_rpc_error('other actor cannot replay receipt',1,'87000000-0000-4000-8000-000000000001',2,100000,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_assert('same key different actor namespace independent',pg_temp.cash_call(2,'87000000-0000-4000-8000-000000000001',2,200000)->'changed'='true'::jsonb);
reset role;

select pg_temp.cash_assert('cash_received_by caller',(select cash_received_by='81000000-0000-4000-8000-000000000003'::uuid from public.payments where request_id='82000000-0000-4000-8000-000000000001'));
select pg_temp.cash_assert('cash_received_at set',(select cash_received_at is not null from public.payments where request_id='82000000-0000-4000-8000-000000000001'));
select pg_temp.cash_assert('paid_at set',(select paid_at is not null from public.payments where request_id='82000000-0000-4000-8000-000000000001'));
select pg_temp.cash_assert('verified_at remains NULL',(select verified_at is null from public.payments where request_id='82000000-0000-4000-8000-000000000001'));
select pg_temp.cash_assert('immutable fields and all unrelated columns preserved',
 (select (to_jsonb(p)-array['status','version','amount_received','cash_received_by','cash_received_at','paid_at','updated_at'])=
 (f.original-array['status','version','amount_received','cash_received_by','cash_received_at','paid_at','updated_at']) from public.payments p join pg_temp.cash_fixtures f on f.payment_id=p.id where f.i=1));
select pg_temp.cash_assert('one cash_received per payment despite retries',(select count(*)=1 from public.payment_events where request_id='82000000-0000-4000-8000-000000000001' and event_type='cash_received'));
select pg_temp.cash_assert('event actor rescuer correct',(select bool_and(e.actor_type='rescuer' and e.actor_id=p.rescuer_id) from public.payment_events e join public.payments p on p.id=e.payment_id where e.event_type='cash_received'));
select pg_temp.cash_assert('event amount correct',(select bool_and(e.amount=p.amount_expected) from public.payment_events e join public.payments p on p.id=e.payment_id where e.event_type='cash_received'));
select pg_temp.cash_assert('event old new status correct',(select bool_and(old_status='awaiting_payment' and new_status='paid') from public.payment_events where event_type='cash_received'));
select pg_temp.cash_assert('single authoritative server timestamp fields and event',
 (select bool_and(p.updated_at=p.paid_at and p.paid_at=p.cash_received_at and e.created_at=p.paid_at and p.paid_at>=p.created_at)
 from public.payments p join public.payment_events e on e.payment_id=p.id where e.event_type='cash_received'));
select pg_temp.cash_assert('event version operation sequence metadata correct',
 (select bool_and(e.payment_version=3 and e.event_sequence=3 and e.operation_id='87000000-0000-4000-8000-000000000001'::uuid and e.metadata='{}'::jsonb)
 from public.payment_events e where event_type='cash_received'));
select pg_temp.cash_assert('receipt binds actor name canonical payload resource and server time',
 (select r.rescuer_id=p.rescuer_id and r.operation_name='rescuer_confirm_cash_received' and r.resource_id=p.id
 and r.payload_hash=encode(sha256(convert_to(jsonb_build_array('rescuer_confirm_cash_received',jsonb_build_array(p.request_id,p.id,100000,2))::text,'UTF8')),'hex')
 and r.committed_at>=p.paid_at from private.rescuer_rpc_receipts r join public.payments p on p.id=r.resource_id
 where r.rescuer_id='81000000-0000-4000-8000-000000000003' and r.operation_id='87000000-0000-4000-8000-000000000001'));
select pg_temp.cash_assert('two settlements and one no-op receipt only',(select count(*)=3 from private.rescuer_rpc_receipts where operation_name='rescuer_confirm_cash_received'));

-- Existing rescuer operations share the same actor/key namespace. A payment
-- key cannot alias another operation, even when the caller owns the resource.
do $namespace$
begin
 begin
  perform set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);
  perform private.rescuer_begin_operation('register_vehicle','87000000-0000-4000-8000-000000000010','[]');
  perform private.rescuer_commit_receipt('register_vehicle','87000000-0000-4000-8000-000000000010','[]',gen_random_uuid());
  set local role authenticated;
  perform pg_temp.cash_rpc_error('other operation key conflict',3,'87000000-0000-4000-8000-000000000010',2,300000,'22023','IDEMPOTENCY_CONFLICT');
  reset role;
  raise exception sqlstate 'Z0001';
 exception when sqlstate 'Z0001' then null;
 end;
 perform pg_temp.cash_assert('existing rescuer operation namespace cannot be reused',true);
end;
$namespace$;

-- A committed operation returns the current authorized payment, never a stale
-- response snapshot. This privileged timestamp-only update is rolled back.
do $current$
begin
 begin
  update public.payments set updated_at=clock_timestamp() where request_id='82000000-0000-4000-8000-000000000001';
  set local role authenticated;
  perform set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);
  perform pg_temp.cash_assert('current replay DTO',pg_temp.cash_call(1)->'payment'=public.rescuer_get_job_payment('82000000-0000-4000-8000-000000000001')
    and pg_temp.cash_call(1)->'payment'<>(select response->'payment' from pg_temp.cash_responses where label='first'));
  reset role;
  raise exception sqlstate 'Z0001';
 exception when sqlstate 'Z0001' then null;
 end;
 perform pg_temp.cash_assert('exact retry returns current DTO after later timestamp change',true);
end;
$current$;

-- Privileged synthetic unsupported states, confined to rollback subtransactions.
-- Re-enable the row guard BEFORE calling the public RPC as authenticated.
do $states$
declare st text; meth text; expected text;
begin
 foreach st in array array['pending','verifying','failed','cancelled','refunded','paid','awaiting_payment'] loop
  meth:=case when st='pending' then null when st in ('paid','awaiting_payment') then 'bank_transfer' else 'cash' end;
  expected:=case when st in ('paid','refunded') then 'PAYMENT_ALREADY_SETTLED' else 'PAYMENT_NOT_ELIGIBLE' end;
  begin
   alter table public.payments disable trigger payment_core_guard;
   update public.payments set status=st,method=meth where request_id='82000000-0000-4000-8000-000000000003';
   alter table public.payments enable trigger payment_core_guard;
   set local role authenticated;
   perform set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);
   perform pg_temp.cash_rpc_error('synthetic '||st,3,gen_random_uuid(),2,300000,'P0001',expected);
   reset role;
   raise exception sqlstate 'Z0001';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.cash_assert('reject state '||st||' method '||coalesce(meth,'NULL'),true);
 end loop;
end;
$states$;
do $parents$
declare target text;
begin
 foreach target in array array['request','assignment'] loop
  begin
   set constraints all deferred;
   if target='request' then
    alter table public.rescue_requests disable trigger cuuho247_request_transition;
    update public.rescue_requests set status='in_progress' where id='82000000-0000-4000-8000-000000000003';
    -- Deferred consistency events prevent ALTER TABLE until rollback. The
    -- subtransaction restores this request-only trigger; payment guards stay on.
   else
    update public.rescue_request_assignments set state='in_progress',completed_at=null,completion_quote_id=null
    where request_id='82000000-0000-4000-8000-000000000003';
   end if;
   set local role authenticated;
   perform set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);
   perform pg_temp.cash_rpc_error('parent fault',3,gen_random_uuid(),2,300000,'P0001','PAYMENT_NOT_ELIGIBLE');
   reset role;
   raise exception sqlstate 'Z0001';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.cash_assert(target||' not completed denied',true);
 end loop;
end;
$parents$;
do $approval$
declare st text;
begin
 foreach st in array array['draft','submitted','rejected','suspended'] loop
  begin
   update public.rescuer_profiles set verification_status=st where user_id='81000000-0000-4000-8000-000000000003';
   set local role authenticated;
   perform set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);
   perform pg_temp.cash_rpc_error('approval fault',3,gen_random_uuid(),2,300000,'42501',case when st='suspended' then 'PROFILE_SUSPENDED' else 'PROFILE_NOT_READY' end);
   perform pg_temp.cash_assert('read while unapproved',public.rescuer_get_job_payment('82000000-0000-4000-8000-000000000001')->>'status'='paid');
   perform pg_temp.cash_assert('retry while unapproved',pg_temp.cash_call(1)->'changed'='false'::jsonb);
   perform pg_temp.cash_rpc_error('new key paid still approval gate',1,gen_random_uuid(),3,100000,'42501',case when st='suspended' then 'PROFILE_SUSPENDED' else 'PROFILE_NOT_READY' end);
   reset role;
   raise exception sqlstate 'Z0001';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.cash_assert(st||' blocks new confirmation; getter and exact retry succeed',true);
 end loop;
end;
$approval$;

do $bounds$
declare kind text;
begin
 foreach kind in array array['zero','max_version'] loop
  begin
   alter table public.payments disable trigger payment_core_guard;
   if kind='zero' then
    update public.payments set amount_expected=0 where request_id='82000000-0000-4000-8000-000000000003';
   else
    update public.payments set version=9223372036854775807 where request_id='82000000-0000-4000-8000-000000000003';
   end if;
   alter table public.payments enable trigger payment_core_guard;
   set local role authenticated;
   perform set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);
   perform pg_temp.cash_rpc_error('bounds fault',3,gen_random_uuid(),
    case when kind='zero' then 2 else 9223372036854775807 end,
    case when kind='zero' then 0 else 300000 end,'P0001',
    case when kind='zero' then 'ZERO_AMOUNT_REQUIRES_POLICY' else 'PAYMENT_NOT_ELIGIBLE' end);
   reset role;
   raise exception sqlstate 'Z0001';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.cash_assert(kind||' fails closed without arithmetic overflow',true);
 end loop;
end;
$bounds$;

-- A failure in either audit or receipt must roll back the payment too.
do $atomic$
declare target text; before_payment jsonb; before_events bigint; before_receipts bigint;
begin
 foreach target in array array['event','receipt'] loop
  select to_jsonb(p) into before_payment from public.payments p where request_id='82000000-0000-4000-8000-000000000003';
  select count(*) into before_events from public.payment_events;
  select count(*) into before_receipts from private.rescuer_rpc_receipts;
  if target='event' then
   alter table public.payment_events add constraint gd3_fault check(event_type<>'cash_received') not valid;
  else
   alter table private.rescuer_rpc_receipts add constraint gd3_fault check(operation_name<>'rescuer_confirm_cash_received') not valid;
  end if;
  set local role authenticated;
  perform set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);
  perform pg_temp.cash_rpc_error(target||' failure sanitized',3,'87000000-0000-4000-8000-000000000003',2,300000,'P0001','PAYMENT_STATE_CONFLICT');
  reset role;
  perform pg_temp.cash_assert(target||' failure rolls back payment event receipt',
    (select to_jsonb(p)=before_payment from public.payments p where request_id='82000000-0000-4000-8000-000000000003')
    and (select count(*)=before_events from public.payment_events) and (select count(*)=before_receipts from private.rescuer_rpc_receipts));
  if target='event' then alter table public.payment_events drop constraint gd3_fault;
  else alter table private.rescuer_rpc_receipts drop constraint gd3_fault; end if;
 end loop;
end;
$atomic$;
set local role authenticated;
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);
select pg_temp.cash_assert('retry after rolled back failures succeeds same key',pg_temp.cash_call(3,'87000000-0000-4000-8000-000000000003',2,300000)->'changed'='true'::jsonb);
select pg_temp.cash_error('rescuer direct update denied', $$update public.payments set amount_received=amount_expected$$,'42501');
select pg_temp.cash_error('rescuer direct paid denied', $$update public.payments set status='paid'$$,'42501');
select pg_temp.cash_error('event SELECT denied','select * from public.payment_events','42501');
select pg_temp.cash_error('event INSERT denied','insert into public.payment_events default values','42501');
select pg_temp.cash_error('event UPDATE denied', $$update public.payment_events set amount=0$$,'42501');
select pg_temp.cash_error('event DELETE denied','delete from public.payment_events','42501');
select pg_temp.cash_error('receipt SELECT denied','select * from private.rescuer_rpc_receipts','42501');
select pg_temp.cash_error('receipt INSERT denied','insert into private.rescuer_rpc_receipts default values','42501');
select pg_temp.cash_error('receipt UPDATE denied', $$update private.rescuer_rpc_receipts set resource_id=gen_random_uuid()$$,'42501');
select pg_temp.cash_error('receipt DELETE denied','delete from private.rescuer_rpc_receipts','42501');
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000001',true);
select pg_temp.cash_error('customer direct paid denied', $$update public.payments set status='paid'$$,'42501');
select pg_temp.cash_assert('customer getter sees paid',public.customer_get_payment('82000000-0000-4000-8000-000000000001')->>'status'='paid');
select pg_temp.cash_assert('customer prepare preserves paid',public.customer_prepare_payment('82000000-0000-4000-8000-000000000001')=public.customer_get_payment('82000000-0000-4000-8000-000000000001'));
select pg_temp.cash_error('customer select cannot reset paid', $$select public.customer_select_payment_method(request_id,payment_id,'cash',3,gen_random_uuid()) from pg_temp.cash_fixtures where i=1$$,'P0001','PAYMENT_ALREADY_SETTLED');
reset role;
select pg_temp.cash_error('privileged customer cannot forge paid through guard',
 $$update public.payments set status='paid',amount_received=amount_expected,cash_received_by=rescuer_id,version=version+1 where request_id='82000000-0000-4000-8000-000000000004'$$,'23514','PAYMENT_MUTATION_NOT_ENABLED');
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);
select pg_temp.cash_error('guard blocks bank overwrite', $$update public.payments set method='bank_transfer' where request_id='82000000-0000-4000-8000-000000000001'$$,'23514','PAYMENT_MUTATION_NOT_ENABLED');
select pg_temp.cash_error('guard blocks amount snapshot edit', $$update public.payments set amount_expected=1 where request_id='82000000-0000-4000-8000-000000000001'$$,'23514','PAYMENT_SNAPSHOT_IMMUTABLE');
select pg_temp.cash_error('guard blocks incorrect received amount', $$update public.payments set status='paid',amount_received=1,cash_received_by=rescuer_id,version=version+1 where request_id='82000000-0000-4000-8000-000000000004'$$,'23514','PAYMENT_MUTATION_NOT_ENABLED');
select pg_temp.cash_error('guard blocks incorrect version increment', $$update public.payments set status='paid',amount_received=amount_expected,cash_received_by=rescuer_id,version=version+2 where request_id='82000000-0000-4000-8000-000000000004'$$,'23514','PAYMENT_MUTATION_NOT_ENABLED');
select pg_temp.cash_error('duplicate cash event index blocks second event',
 $$insert into public.payment_events(payment_id,request_id,event_type,actor_type,actor_id,old_status,new_status,amount,operation_id,payment_version,event_sequence)
 select id,request_id,'cash_received','rescuer',rescuer_id,'awaiting_payment','paid',amount_expected,gen_random_uuid(),version,4 from public.payments where request_id='82000000-0000-4000-8000-000000000001'$$,'23505');
select pg_temp.cash_assert('only one cash event per settled payment final',
 (select count(*)=3 and count(distinct payment_id)=3 from public.payment_events where event_type='cash_received'));
select pg_temp.cash_assert('request and assignment full rows unchanged by cash flow',
 (select bool_and(to_jsonb(r)=s.request_row and to_jsonb(a)=s.assignment_row)
 from pg_temp.cash_parents s join pg_temp.cash_fixtures f on f.i=s.i
 join public.rescue_requests r on r.id=f.request_id join public.rescue_request_assignments a on a.request_id=r.id));

-- Another active job must not remove access to an older completed payment.
do $active_job$
begin
 begin
  set constraints all deferred;
  insert into public.rescue_requests(id,customer_id,client_request_id,vehicle_kind,service_code,
    location_text,location_confirmed,contact_name,contact_phone,status,provider_id)
  values('82000000-0000-4000-8000-000000000006','81000000-0000-4000-8000-000000000005',gen_random_uuid(),
    'motorbike','tire','Synthetic active job',true,'Fixture','0900000005','accepted','81000000-0000-4000-8000-000000000003');
  insert into public.rescue_request_assignments(id,request_id,rescuer_id,vehicle_id,state)
  values('83000000-0000-4000-8000-000000000006','82000000-0000-4000-8000-000000000006',
    '81000000-0000-4000-8000-000000000003','86000000-0000-4000-8000-000000000003','accepted');
  set constraints all immediate;
  set local role authenticated;
  perform set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);
  perform pg_temp.cash_assert('get with active job',public.rescuer_get_job_payment('82000000-0000-4000-8000-000000000004')->>'status'='awaiting_payment');
  perform pg_temp.cash_assert('confirm with active job',pg_temp.cash_call(4,gen_random_uuid(),2,400000)->'changed'='true'::jsonb);
  reset role;
  raise exception sqlstate 'Z0001';
 exception when sqlstate 'Z0001' then null;
 end;
 perform pg_temp.cash_assert('new active job does not block old completed payment get or confirm',true);
end;
$active_job$;
select pg_temp.cash_assert('all guards restored',
 (select count(*)=3 and bool_and(tgenabled='O') from pg_trigger where
 (tgrelid='public.payments'::regclass and tgname='payment_core_guard') or
 (tgrelid='public.payment_events'::regclass and tgname='payment_event_core_guard') or
 (tgrelid='public.rescue_requests'::regclass and tgname='cuuho247_request_transition')));
set constraints all immediate;
select 'PAYMENT_RESCUER_CASH_PASS' as result,count(*) as assertions from pg_temp.cash_results;
rollback;
