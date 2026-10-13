-- PRIVILEGED DISPOSABLE LOCAL DB ONLY. Apply GD1 + GD2A + GD2B first.
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
  if exists(select 1 from auth.users where id::text like '91000000-0000-4000-8000-%') then
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
-- Invoker wrappers reduce fixture UUID repetition; never grant table DML.
create function pg_temp.cash_call(p_i integer,p_op uuid default '97000000-0000-4000-8000-000000000001',
 p_version bigint default 1,p_method text default 'cash') returns jsonb
language sql security invoker as $$
 select public.customer_select_payment_method(f.request_id,f.payment_id,p_method,p_version,p_op)
 from pg_temp.cash_fixtures f where f.i=p_i;
$$;
create function pg_temp.cash_rpc_error(p_label text,p_i integer,p_op uuid,p_version bigint,p_method text,p_state text,p_message text)
returns void language plpgsql security invoker as $$
begin
 perform pg_temp.cash_error(p_label,format('select pg_temp.cash_call(%L,%L::uuid,%L::bigint,%L)',p_i,p_op,p_version,p_method),p_state,p_message);
end;
$$;
select pg_temp.cash_assert('RPC exact five arguments; definer and empty search_path',
 (select prosecdef and 'search_path=""'=any(proconfig) and pronargs=5
   and proargtypes='2950 2950 25 20 2950'::oidvector and prorettype='jsonb'::regtype
  from pg_catalog.pg_proc where oid='public.customer_select_payment_method(uuid,uuid,text,bigint,uuid)'::regprocedure));
select pg_temp.cash_assert('only authenticated RPC EXECUTE; PUBLIC and anon denied',
 pg_catalog.has_function_privilege('authenticated','public.customer_select_payment_method(uuid,uuid,text,bigint,uuid)','EXECUTE')
 and not pg_catalog.has_function_privilege('anon','public.customer_select_payment_method(uuid,uuid,text,bigint,uuid)','EXECUTE')
 and not exists(select 1 from pg_catalog.pg_proc p,pg_catalog.aclexplode(p.proacl) a
   where p.oid='public.customer_select_payment_method(uuid,uuid,text,bigint,uuid)'::regprocedure and a.grantee=0));
select pg_temp.cash_assert('all three financial tables RLS enabled',
 (select count(*)=3 from pg_catalog.pg_class where oid in
 ('public.payments'::regclass,'public.payment_events'::regclass,'private.payment_rpc_receipts'::regclass) and relrowsecurity));
select pg_temp.cash_assert('no event/receipt policies or payment write policies',
 not exists(select 1 from pg_catalog.pg_policy where polrelid in
 ('public.payment_events'::regclass,'private.payment_rpc_receipts'::regclass))
 and (select count(*)=2 and bool_and(cmd='SELECT' and roles=array['authenticated']::name[])
 from pg_catalog.pg_policies where schemaname='public' and tablename='payments'));
do $acl$
declare r text; t text;
begin
 foreach r in array array['anon','authenticated'] loop
   foreach t in array array['public.payments','public.payment_events','private.payment_rpc_receipts'] loop
     perform pg_temp.cash_assert(r||' no direct DML '||t,
       not pg_catalog.has_table_privilege(r,t,'INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER,REFERENCES'));
   end loop;
   perform pg_temp.cash_assert(r||' no event/receipt SELECT or guard EXECUTE',
     not pg_catalog.has_table_privilege(r,'public.payment_events','SELECT')
     and not pg_catalog.has_table_privilege(r,'private.payment_rpc_receipts','SELECT')
     and not pg_catalog.has_function_privilege(r,'private.payment_receipt_guard()','EXECUTE')
     and not pg_catalog.has_function_privilege(r,'private.payment_core_guard()','EXECUTE'));
 end loop;
 if exists(select 1 from pg_catalog.pg_roles where rolname='service_role') then
   perform pg_temp.cash_assert('service role no new table or RPC privilege',
     not pg_catalog.has_table_privilege('service_role','private.payment_rpc_receipts','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER,REFERENCES')
     and not pg_catalog.has_function_privilege('service_role','public.customer_select_payment_method(uuid,uuid,text,bigint,uuid)','EXECUTE'));
 end if;
end;
$acl$;

select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);
insert into auth.users(id,email) select ('91000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 'cash-selection-'||i||'@example.invalid' from generate_series(1,5) i;
insert into public.rescuer_profiles(user_id,full_name,contact_phone,verification_status) values
 ('91000000-0000-4000-8000-000000000003','Cash fixture rescuer','0900000003','approved');
insert into public.rescuer_vehicles(id,rescuer_id,kind,display_name,license_plate,verification_status) values
 ('96000000-0000-4000-8000-000000000003','91000000-0000-4000-8000-000000000003','service_motorbike','Cash fixture','CASHFIXTURE','approved');
do $fixtures$
declare i integer; c uuid; req uuid; a uuid; q uuid; t timestamptz:=clock_timestamp(); dto jsonb;
begin
 for i in 1..5 loop
   c:=('91000000-0000-4000-8000-'||lpad((case when i=2 then 2 else 1 end)::text,12,'0'))::uuid;
   req:=('92000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
   a:=('93000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
   q:=('94000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
   insert into public.rescue_requests(id,customer_id,client_request_id,vehicle_kind,service_code,
    location_text,location_confirmed,contact_name,contact_phone,status,provider_id)
   values(req,c,gen_random_uuid(),'motorbike','tire','Synthetic CASH fixture',true,'Fixture','0900000001','in_progress',
    '91000000-0000-4000-8000-000000000003');
   insert into public.rescue_request_assignments(id,request_id,rescuer_id,vehicle_id,state,accepted_at,en_route_at,arrived_at,in_progress_at)
   values(a,req,'91000000-0000-4000-8000-000000000003','96000000-0000-4000-8000-000000000003','in_progress',t,t,t,t);
   insert into public.rescue_quotes(id,assignment_id,request_id,rescuer_id,revision,total_vnd,items)
   values(q,a,req,'91000000-0000-4000-8000-000000000003',1,100000*i,
    jsonb_build_array(jsonb_build_object('service_code','tire','quantity',1,'unit_price_vnd',100000*i)));
   update public.rescue_request_assignments set state='completed',completed_at=t,current_quote_id=q,completion_quote_id=q where id=a;
   update public.rescue_requests set status='completed',quoted_price=100000*i where id=req;
   perform set_config('request.jwt.claim.sub',c::text,true);
   dto:=public.customer_prepare_payment(req);
   insert into pg_temp.cash_fixtures select i,req,p.id,to_jsonb(p) from public.payments p where p.id=(dto->>'payment_id')::uuid;
 end loop;
end;
$fixtures$;
set constraints all immediate;

set local role authenticated;
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000001',true);
select pg_temp.cash_rpc_error('stale version pending denied',1,'97000000-0000-4000-8000-000000000001',2,'cash','P0001','VERSION_CONFLICT');
select pg_temp.cash_rpc_error('bank selection denied',1,'97000000-0000-4000-8000-000000000001',1,'bank_transfer','22023','METHOD_NOT_IMPLEMENTED');
select pg_temp.cash_rpc_error('NULL method denied',1,'97000000-0000-4000-8000-000000000001',1,null,'22023','METHOD_NOT_IMPLEMENTED');
select pg_temp.cash_rpc_error('nonexact method denied',1,'97000000-0000-4000-8000-000000000001',1,'CASH','22023','METHOD_NOT_IMPLEMENTED');
select pg_temp.cash_rpc_error('NULL version denied',1,'97000000-0000-4000-8000-000000000001',null,'cash','22023','INVALID_EXPECTED_VERSION');
select pg_temp.cash_rpc_error('zero version denied',1,'97000000-0000-4000-8000-000000000001',0,'cash','22023','INVALID_EXPECTED_VERSION');
select pg_temp.cash_rpc_error('NULL operation denied',1,null,1,'cash','22023','IDEMPOTENCY_KEY_REQUIRED');
insert into pg_temp.cash_responses values('first',pg_temp.cash_call(1));
select pg_temp.cash_assert('own pending success changed true',(select response->'changed'='true'::jsonb from pg_temp.cash_responses where label='first'));
select pg_temp.cash_assert('status awaiting payment',(select response#>>'{payment,status}'='awaiting_payment' from pg_temp.cash_responses where label='first'));
select pg_temp.cash_assert('method cash',(select response#>>'{payment,method}'='cash' from pg_temp.cash_responses where label='first'));
select pg_temp.cash_assert('version increments once',(select response#>>'{payment,version}'='2' from pg_temp.cash_responses where label='first'));
select pg_temp.cash_assert('expected amount unchanged',(select response#>>'{payment,amount_expected}'='100000' from pg_temp.cash_responses where label='first'));
select pg_temp.cash_assert('received amount NULL',(select response#>'{payment,amount_received}'='null'::jsonb from pg_temp.cash_responses where label='first'));
select pg_temp.cash_assert('paid_at NULL',(select response#>'{payment,paid_at}'='null'::jsonb from pg_temp.cash_responses where label='first'));
select pg_temp.cash_assert('cash_received_at NULL',(select response#>'{payment,cash_received_at}'='null'::jsonb from pg_temp.cash_responses where label='first'));
insert into pg_temp.cash_responses values('retry',pg_temp.cash_call(1));
select pg_temp.cash_assert('same operation old version replays before stale check',
 (select response->'changed'='false'::jsonb and response->'payment'=(select response->'payment' from pg_temp.cash_responses where label='first')
 from pg_temp.cash_responses where label='retry'));
select pg_temp.cash_rpc_error('same operation changed expected version conflicts',1,'97000000-0000-4000-8000-000000000001',2,'cash','22023','IDEMPOTENCY_CONFLICT');
select pg_temp.cash_rpc_error('same operation changed method conflicts',1,'97000000-0000-4000-8000-000000000001',1,'bank_transfer','22023','IDEMPOTENCY_CONFLICT');
select pg_temp.cash_rpc_error('same actor key another owned payment conflicts',3,'97000000-0000-4000-8000-000000000001',1,'cash','22023','IDEMPOTENCY_CONFLICT');
select pg_temp.cash_rpc_error('new key stale version does not bypass concurrency',1,'97000000-0000-4000-8000-000000000002',1,'cash','P0001','VERSION_CONFLICT');
insert into pg_temp.cash_responses values('noop',pg_temp.cash_call(1,'97000000-0000-4000-8000-000000000002',2));
select pg_temp.cash_assert('new key current version no-op has identical payment',
 (select response->'changed'='false'::jsonb and response->'payment'=(select response->'payment' from pg_temp.cash_responses where label='first')
 from pg_temp.cash_responses where label='noop'));
select pg_temp.cash_assert('no-op receipt also replays',pg_temp.cash_call(1,'97000000-0000-4000-8000-000000000002',2)=
 (select response from pg_temp.cash_responses where label='noop'));
select pg_temp.cash_assert('getter reads selected payment',public.customer_get_payment('92000000-0000-4000-8000-000000000001')=
 (select response->'payment' from pg_temp.cash_responses where label='first'));
select pg_temp.cash_assert('prepare preserves selected payment',public.customer_prepare_payment('92000000-0000-4000-8000-000000000001')=
 (select response->'payment' from pg_temp.cash_responses where label='first'));

select pg_temp.cash_rpc_error('wrong customer denied before receipt lookup',2,'97000000-0000-4000-8000-000000000001',1,'cash','42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_error('wrong payment UUID denied',
 $$select public.customer_select_payment_method('92000000-0000-4000-8000-000000000001','95000000-0000-4000-8000-000000000099','cash',1,'97000000-0000-4000-8000-000000000001')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_error('wrong request UUID denied',
 $$select public.customer_select_payment_method('92000000-0000-4000-8000-000000000099',payment_id,'cash',1,'97000000-0000-4000-8000-000000000001') from pg_temp.cash_fixtures where i=1$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_error('mismatched owned request and payment denied',
 $$select public.customer_select_payment_method('92000000-0000-4000-8000-000000000003',payment_id,'cash',1,'97000000-0000-4000-8000-000000000001') from pg_temp.cash_fixtures where i=1$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_error('NULL identity denied',
 $$select public.customer_select_payment_method(null,null,'cash',1,'97000000-0000-4000-8000-000000000001')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000002',true);
select pg_temp.cash_rpc_error('customer B cannot reuse A receipt',1,'97000000-0000-4000-8000-000000000001',1,'cash','42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_assert('same operation UUID different actor independent',pg_temp.cash_call(2)->'changed'='true'::jsonb);
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000005',true);
select pg_temp.cash_rpc_error('unrelated authenticated denied',1,'97000000-0000-4000-8000-000000000001',1,'cash','42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_assert('unrelated RLS remains empty',not exists(select 1 from public.payments));
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000003',true);
select pg_temp.cash_rpc_error('assigned rescuer cannot select method',1,'97000000-0000-4000-8000-000000000001',1,'cash','42501','PAYMENT_NOT_ACCESSIBLE');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.cash_rpc_error('unauthenticated principal denied first',1,null,null,null,'42501','AUTHENTICATION_REQUIRED');
set local role anon;
select pg_temp.cash_error('anon EXECUTE denied','select pg_temp.cash_call(1)','42501');
set local role authenticated;
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000001',true);
select pg_temp.cash_error('direct UPDATE method denied', $$update public.payments set method='cash',status='awaiting_payment',version=version+1$$,'42501');
select pg_temp.cash_error('customer cannot set paid', $$update public.payments set status='paid',paid_at=now()$$,'42501');
select pg_temp.cash_error('customer cannot change amount','update public.payments set amount_expected=1','42501');
select pg_temp.cash_error('customer cannot change identity', $$update public.payments set customer_id='91000000-0000-4000-8000-000000000005'$$,'42501');
select pg_temp.cash_error('direct INSERT denied','insert into public.payments default values','42501');
select pg_temp.cash_error('direct DELETE denied','delete from public.payments','42501');
select pg_temp.cash_error('raw event SELECT denied','select * from public.payment_events','42501');
select pg_temp.cash_error('event INSERT denied','insert into public.payment_events default values','42501');
select pg_temp.cash_error('event DELETE denied','delete from public.payment_events','42501');
select pg_temp.cash_error('receipt SELECT denied','select * from private.payment_rpc_receipts','42501');
select pg_temp.cash_error('receipt INSERT denied','insert into private.payment_rpc_receipts default values','42501');
select pg_temp.cash_error('receipt UPDATE denied', $$update private.payment_rpc_receipts set payload_hash=repeat('0',64)$$,'42501');
select pg_temp.cash_error('receipt DELETE denied','delete from private.payment_rpc_receipts','42501');
reset role;

select pg_temp.cash_assert('only allowed four fields changed',
 (select (to_jsonb(p)-array['method','status','version','updated_at'])=(f.original-array['method','status','version','updated_at'])
  from public.payments p join pg_temp.cash_fixtures f on f.payment_id=p.id where f.i=1));
select pg_temp.cash_assert('updated_at server generated',
 (select p.updated_at>=p.created_at and p.updated_at>=(f.original->>'updated_at')::timestamptz
  from public.payments p join pg_temp.cash_fixtures f on f.payment_id=p.id where f.i=1));
select pg_temp.cash_assert('one method event per selected payment',
 (select count(*)=2 and count(distinct payment_id)=2 from public.payment_events where event_type='payment_method_selected'));
select pg_temp.cash_assert('event actor identity',
 (select bool_and(e.actor_type='customer' and e.actor_id=p.customer_id) from public.payment_events e
  join public.payments p on p.id=e.payment_id where e.event_type='payment_method_selected'));
select pg_temp.cash_assert('event status amount version operation sequence metadata',
 (select bool_and(e.old_status='pending' and e.new_status='awaiting_payment' and e.amount=p.amount_expected
  and e.payment_version=2 and e.event_sequence=2 and e.request_id=p.request_id
  and e.operation_id='97000000-0000-4000-8000-000000000001'::uuid
  and e.metadata='{"old_method":null,"new_method":"cash"}'::jsonb and e.created_at>=p.updated_at)
  from public.payment_events e join public.payments p on p.id=e.payment_id where e.event_type='payment_method_selected'));
select pg_temp.cash_assert('three receipts for two mutations and one no-op',
 (select count(*)=3 from private.payment_rpc_receipts));
select pg_temp.cash_assert('receipt stores canonical payload hash and exact safe DTO',
 (select r.payload_hash=encode(sha256(convert_to(jsonb_build_array('customer_select_payment_method',f.request_id,f.payment_id,'cash',1)::text,'UTF8')),'hex')
   and r.response_payment=(select response->'payment' from pg_temp.cash_responses where label='first')
   and r.committed_at>=(r.response_payment->>'updated_at')::timestamptz
  from private.payment_rpc_receipts r join pg_temp.cash_fixtures f on f.payment_id=r.payment_id
  where f.i=1 and r.operation_id='97000000-0000-4000-8000-000000000001'));
select pg_temp.cash_error('privileged receipt modification rejected',
 $$update private.payment_rpc_receipts set payload_hash=repeat('0',64)$$,'23514','PAYMENT_RECEIPT_IMMUTABLE');
select pg_temp.cash_error('privileged receipt deletion rejected','delete from private.payment_rpc_receipts','23514','PAYMENT_RECEIPT_IMMUTABLE');
select pg_temp.cash_error('receipt TRUNCATE rejected','truncate private.payment_rpc_receipts','23514','PAYMENT_RECEIPT_IMMUTABLE');
select pg_temp.cash_error('privileged status paid rejected', $$update public.payments set status='paid' where request_id='92000000-0000-4000-8000-000000000003'$$,'23514','PAYMENT_MUTATION_NOT_ENABLED');
select pg_temp.cash_error('privileged bank transition rejected', $$update public.payments set method='bank_transfer',status='awaiting_payment',version=2 where request_id='92000000-0000-4000-8000-000000000003'$$,'23514','PAYMENT_MUTATION_NOT_ENABLED');
select pg_temp.cash_error('privileged skipped version rejected', $$update public.payments set method='cash',status='awaiting_payment',version=3 where request_id='92000000-0000-4000-8000-000000000003'$$,'23514','PAYMENT_MUTATION_NOT_ENABLED');
select pg_temp.cash_error('guard blocks collection fields in selection', $$update public.payments set method='cash',status='awaiting_payment',version=2,amount_received=amount_expected where request_id='92000000-0000-4000-8000-000000000003'$$,'23514','PAYMENT_MUTATION_NOT_ENABLED');
select pg_temp.cash_error('snapshot remains immutable', $$update public.payments set amount_expected=1 where request_id='92000000-0000-4000-8000-000000000003'$$,'23514','PAYMENT_SNAPSHOT_IMMUTABLE');

-- Local-only corruption fixtures for states GD1/GD2B intentionally cannot create.
-- Disable ONLY the core row guard during privileged fixture mutation; restore it
-- BEFORE exercising the RPC, then roll back the whole subtransaction each time.
do $forbidden_states$
declare s text;
begin
 foreach s in array array['paid','cancelled','refunded','verifying','failed'] loop
   begin
     alter table public.payments disable trigger payment_core_guard;
     update public.payments set status=s,method='cash' where request_id='92000000-0000-4000-8000-000000000004';
     alter table public.payments enable trigger payment_core_guard;
     set local role authenticated;
     perform pg_temp.cash_rpc_error('state '||s||' denied',4,'97000000-0000-4000-8000-000000000004',1,'cash','P0001',
       case when s in ('paid','refunded') then 'PAYMENT_ALREADY_SETTLED' else 'PAYMENT_NOT_ELIGIBLE' end);
     raise exception using errcode='ZT001',message='ROLLBACK_FAULT';
   exception when sqlstate 'ZT001' then null;
   end;
   perform pg_temp.cash_assert('state '||s||' denied',true);
 end loop;
end;
$forbidden_states$;

-- Event/receipt failures must undo the entire update/event/receipt triple.
alter table public.payment_events add constraint cash_test_audit_failure
 check(not(request_id='92000000-0000-4000-8000-000000000003'::uuid and event_type='payment_method_selected'));
set local role authenticated;
select pg_temp.cash_rpc_error('audit failure sanitized',3,'97000000-0000-4000-8000-000000000003',1,'cash','P0001','PAYMENT_STATE_CONFLICT');
reset role;
select pg_temp.cash_assert('audit failure rolls back all writes',
 (select to_jsonb(p)=f.original from public.payments p join pg_temp.cash_fixtures f on f.payment_id=p.id where f.i=3)
 and not exists(select 1 from private.payment_rpc_receipts where operation_id='97000000-0000-4000-8000-000000000003'));
alter table public.payment_events drop constraint cash_test_audit_failure;
alter table private.payment_rpc_receipts add constraint cash_test_receipt_failure
 check(operation_id<>'97000000-0000-4000-8000-000000000003'::uuid);
set local role authenticated;
select pg_temp.cash_rpc_error('receipt failure sanitized',3,'97000000-0000-4000-8000-000000000003',1,'cash','P0001','PAYMENT_STATE_CONFLICT');
reset role;
select pg_temp.cash_assert('receipt failure rolls back payment and event',
 (select to_jsonb(p)=f.original from public.payments p join pg_temp.cash_fixtures f on f.payment_id=p.id where f.i=3)
 and not exists(select 1 from public.payment_events where request_id='92000000-0000-4000-8000-000000000003' and event_type='payment_method_selected'));
alter table private.payment_rpc_receipts drop constraint cash_test_receipt_failure;
set local role authenticated;
select pg_temp.cash_assert('same key retry after rolled back failure succeeds',pg_temp.cash_call(3,'97000000-0000-4000-8000-000000000003')->'changed'='true'::jsonb);
reset role;
select pg_temp.cash_assert('recovery exactly one selected event',
 (select count(*)=1 from public.payment_events where request_id='92000000-0000-4000-8000-000000000003' and event_type='payment_method_selected'));
select pg_temp.cash_assert('unrelated pending fixtures untouched',
 (select bool_and(to_jsonb(p)=f.original) from public.payments p join pg_temp.cash_fixtures f on f.payment_id=p.id where f.i in (4,5)));
select pg_temp.cash_assert('core row guard enabled after all fault tests',
 exists(select 1 from pg_catalog.pg_trigger where tgrelid='public.payments'::regclass and tgname='payment_core_guard' and tgenabled='O'));
select pg_temp.cash_assert('no out of scope rescuer/bank RPC or realtime',
 not exists(select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
   and p.proname in ('rescuer_get_job_payment','rescuer_confirm_cash_received','get_customer_payment_qr','internal_confirm_bank_payment'))
 and not exists(select 1 from pg_catalog.pg_publication_tables where schemaname='public' and tablename in ('payments','payment_events')));
set constraints all immediate;
select 'PAYMENT_CUSTOMER_SELECT_CASH_PASS' as result,count(*) as assertions from pg_temp.cash_results;
rollback;
