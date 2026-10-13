-- PRIVILEGED DISPOSABLE LOCAL DB ONLY. Apply GD1 through GD4 first.
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

select pg_temp.cash_assert('payments exactly once in realtime publication',
 (select count(*)=1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='payments'));
select pg_temp.cash_assert('raw events and all private tables unpublished',not exists(
 select 1 from pg_publication_tables where pubname='supabase_realtime' and
 (schemaname='private' or (schemaname='public' and tablename='payment_events'))));
select pg_temp.cash_assert('no FOR ALL TABLES publication',not exists(select 1 from pg_publication where pubname='supabase_realtime' and puballtables));
select pg_temp.cash_assert('payments RLS still enabled',(select relrowsecurity from pg_class where oid='public.payments'::regclass));
select pg_temp.cash_assert('only two participant SELECT policies',
 (select count(*)=2 and bool_and(cmd='SELECT' and roles=array['authenticated']::name[]) from pg_policies where schemaname='public' and tablename='payments'));
select pg_temp.cash_assert('no event policies',not exists(select 1 from pg_policy where polrelid='public.payment_events'::regclass));
select pg_temp.cash_assert('default replica identity retained',(select relreplident='d' from pg_class where oid='public.payments'::regclass));

set local role authenticated;
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000001',true);
select pg_temp.cash_assert('customer A broad SELECT contains only owned rows',
 (select count(*)=4 and bool_and(customer_id=auth.uid()) from public.payments));
select pg_temp.cash_assert('customer A cannot SELECT payment B',
 not exists(select 1 from public.payments where request_id='82000000-0000-4000-8000-000000000002'));
select pg_temp.cash_error('customer RPC B inaccessible',
 $$select public.customer_get_payment('82000000-0000-4000-8000-000000000002')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_error('customer direct UPDATE still denied', $$update public.payments set status='paid'$$,'42501');
select pg_temp.cash_error('raw event SELECT still denied','select * from public.payment_events','42501');
select pg_temp.cash_error('raw event INSERT still denied','insert into public.payment_events default values','42501');
select pg_temp.cash_error('raw event UPDATE still denied','update public.payment_events set amount=0','42501');
select pg_temp.cash_error('raw event DELETE still denied','delete from public.payment_events','42501');
select pg_temp.cash_error('private customer receipts unavailable','select * from private.payment_rpc_receipts','42501');
select pg_temp.cash_error('private rescuer receipts unavailable','select * from private.rescuer_rpc_receipts','42501');
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);
select pg_temp.cash_assert('rescuer A broad SELECT contains only assignment payment rows',
 (select count(*)=4 and bool_and(rescuer_id=auth.uid()) from public.payments));
select pg_temp.cash_assert('rescuer A cannot SELECT payment B',
 not exists(select 1 from public.payments where request_id='82000000-0000-4000-8000-000000000002'));
select pg_temp.cash_error('rescuer RPC B inaccessible',
 $$select public.rescuer_get_job_payment('82000000-0000-4000-8000-000000000002')$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.cash_error('rescuer direct UPDATE still denied', $$update public.payments set amount_received=amount_expected$$,'42501');
select pg_temp.cash_assert('GD3 cash mutation still succeeds',pg_temp.cash_call(1)->'changed'='true'::jsonb);
select pg_temp.cash_assert('rescuer authoritative getter observes paid',
 public.rescuer_get_job_payment('82000000-0000-4000-8000-000000000001')->>'status'='paid');
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000001',true);
select pg_temp.cash_assert('customer authoritative getter observes received amount and paid timestamp',
 public.customer_get_payment('82000000-0000-4000-8000-000000000001')->>'amount_received'='100000'
 and public.customer_get_payment('82000000-0000-4000-8000-000000000001')->>'paid_at' is not null);
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000005',true);
select pg_temp.cash_assert('unrelated authenticated broad SELECT empty',not exists(select 1 from public.payments));
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);
select pg_temp.cash_assert('missing principal SELECT empty',not exists(select 1 from public.payments));
set local role anon;
select pg_temp.cash_error('anon SELECT denied','select * from public.payments','42501');
reset role;
set constraints all immediate;
select 'PAYMENT_REALTIME_PASS' as result,count(*) as assertions from pg_temp.cash_results;
rollback;
