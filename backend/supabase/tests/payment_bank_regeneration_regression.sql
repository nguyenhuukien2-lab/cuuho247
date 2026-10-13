-- PRIVILEGED DISPOSABLE DATABASE ONLY. GD1..GD6C + bank regeneration required.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
do $guard$
begin
  if current_setting('payment.test_mode',true) is distinct from 'local_disposable'
     or not exists(select 1 from pg_catalog.pg_roles where rolname=current_user and (rolsuper or rolbypassrls)) then
    raise exception 'PAYMENT_TEST_REFUSED: privileged local_disposable opt-in required';
  end if;
  if exists(select 1 from auth.users where id::text like '97100000-0000-4000-8000-%') then
    raise exception 'PAYMENT_TEST_REFUSED: fixture namespace occupied';
  end if;
end;
$guard$;

create temp table regen_results(label text primary key) on commit drop;
create temp table regen_fixtures(
  i integer primary key,
  customer_id uuid not null,
  request_id uuid not null,
  payment_id uuid not null,
  select_operation_id uuid not null,
  regenerate_operation_id uuid not null,
  old_intent_id uuid,
  old_intent_version bigint,
  old_reference text,
  old_transfer_content text
) on commit drop;
grant select,insert on pg_temp.regen_results to authenticated,anon;
grant select on pg_temp.regen_fixtures to authenticated,anon;

create function pg_temp.regen_assert(label text,ok boolean) returns void
language plpgsql security invoker as $$
begin
  if ok is distinct from true then raise exception 'TEST_FAIL: %',label; end if;
  insert into pg_temp.regen_results values(label);
end;
$$;
create function pg_temp.regen_error(label text,sql text,expected_state text,expected_message text default null)
returns void language plpgsql security invoker as $$
declare s text; m text;
begin
  begin execute sql;
  exception when others then get stacked diagnostics s=returned_sqlstate,m=message_text;
  end;
  if s is distinct from expected_state or (expected_message is not null and m is distinct from expected_message) then
    raise exception 'TEST_FAIL: %, expected % %, got % %',label,expected_state,expected_message,s,m;
  end if;
  perform pg_temp.regen_assert(label,true);
end;
$$;

select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);
insert into auth.users(id,email) values
 ('97100000-0000-4000-8000-000000000001','regen-owner@example.invalid'),
 ('97100000-0000-4000-8000-000000000002','regen-other@example.invalid'),
 ('97100000-0000-4000-8000-000000000003','regen-rescuer@example.invalid');
insert into public.rescuer_profiles(user_id,full_name,contact_phone,verification_status) values
 ('97100000-0000-4000-8000-000000000003','Regeneration rescuer','0900000973','approved');
insert into public.rescuer_vehicles(id,rescuer_id,kind,display_name,license_plate,verification_status) values
 ('97600000-0000-4000-8000-000000000003','97100000-0000-4000-8000-000000000003',
  'service_motorbike','Regeneration vehicle','REGENFIX','approved');

do $fixtures$
declare i integer; c uuid; r uuid; a uuid; q uuid; d jsonb; t timestamptz:=pg_catalog.clock_timestamp();
begin
  for i in 1..12 loop
    c:=case when i=2 then '97100000-0000-4000-8000-000000000002'::uuid
      else '97100000-0000-4000-8000-000000000001'::uuid end;
    r:=('97200000-0000-4000-8000-'||pg_catalog.lpad(i::text,12,'0'))::uuid;
    a:=('97300000-0000-4000-8000-'||pg_catalog.lpad(i::text,12,'0'))::uuid;
    q:=('97400000-0000-4000-8000-'||pg_catalog.lpad(i::text,12,'0'))::uuid;
    insert into public.rescue_requests(id,customer_id,client_request_id,vehicle_kind,service_code,
      location_text,location_confirmed,contact_name,contact_phone,status,provider_id)
    values(r,c,pg_catalog.gen_random_uuid(),'motorbike','tire','Regeneration fixture',true,
      'Fixture','0900000971','in_progress','97100000-0000-4000-8000-000000000003');
    insert into public.rescue_request_assignments(
      id,request_id,rescuer_id,vehicle_id,state,accepted_at,en_route_at,arrived_at,in_progress_at)
    values(a,r,'97100000-0000-4000-8000-000000000003','97600000-0000-4000-8000-000000000003',
      'in_progress',t,t,t,t);
    insert into public.rescue_quotes(id,assignment_id,request_id,rescuer_id,revision,total_vnd,items)
    values(q,a,r,'97100000-0000-4000-8000-000000000003',1,100000*i,
      pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'service_code','tire','quantity',1,'unit_price_vnd',100000*i)));
    update public.rescue_request_assignments set state='completed',completed_at=t,
      current_quote_id=q,completion_quote_id=q where id=a;
    update public.rescue_requests set status='completed',quoted_price=100000*i where id=r;
    perform pg_catalog.set_config('request.jwt.claim.sub',c::text,true);
    d:=public.customer_prepare_payment(r);
    insert into pg_temp.regen_fixtures(
      i,customer_id,request_id,payment_id,select_operation_id,regenerate_operation_id)
    values(i,c,r,(d->>'payment_id')::uuid,pg_catalog.gen_random_uuid(),pg_catalog.gen_random_uuid());
  end loop;
end;
$fixtures$;
select set_config('request.jwt.claim.sub','',true);

insert into private.payment_bank_config(
  bank_bin,bank_code,bank_name,account_number,account_name,enabled,
  verification_enabled,verification_provider,verification_scope)
values('970436','TESTBANK','Synthetic regeneration bank','123456789012','SYNTHETIC BENEFICIARY',true,
  true,'test_only','regeneration');

do $select_bank$
declare f record;
begin
  for f in select * from pg_temp.regen_fixtures loop
    perform pg_catalog.set_config('request.jwt.claim.sub',f.customer_id::text,true);
    perform public.customer_select_bank_transfer(
      f.request_id,f.payment_id,1,f.select_operation_id);
  end loop;
end;
$select_bank$;
update pg_temp.regen_fixtures f set
  old_intent_id=i.id,
  old_intent_version=i.version,
  old_reference=i.reference,
  old_transfer_content=s.transfer_content
from private.payment_bank_intents i
join private.payment_bank_qr_snapshots s on s.intent_id=i.id
where i.payment_id=f.payment_id;

-- Explicit disposable fault injection avoids wall-clock sleeps. Fixture 1 stays
-- unexpired; every other ready intent is expired by server data.
alter table private.payment_bank_intents disable trigger bank_intent_guard;
update private.payment_bank_intents set
  created_at=pg_catalog.clock_timestamp()-interval '2 hours',
  updated_at=pg_catalog.clock_timestamp(),
  expires_at=pg_catalog.clock_timestamp()-interval '1 hour'
where payment_id in (select payment_id from pg_temp.regen_fixtures where i<>1);
alter table private.payment_bank_intents enable trigger bank_intent_guard;

select set_config('request.jwt.claim.sub','97100000-0000-4000-8000-000000000001',true);
select pg_temp.regen_error('pre-expiry blocked',
 $$select public.customer_regenerate_bank_transfer(request_id,payment_id,2,old_intent_id,old_intent_version,regenerate_operation_id)
   from pg_temp.regen_fixtures where i=1$$,'P0001','BANK_INTENT_NOT_EXPIRED');
select pg_temp.regen_error('foreign owner denied',
 $$select public.customer_regenerate_bank_transfer(request_id,payment_id,2,old_intent_id,old_intent_version,regenerate_operation_id)
   from pg_temp.regen_fixtures where i=2$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.regen_error('authentication required',
 $$select public.customer_regenerate_bank_transfer(request_id,payment_id,2,old_intent_id,old_intent_version,regenerate_operation_id)
   from pg_temp.regen_fixtures where i=3$$,'42501','AUTHENTICATION_REQUIRED');

select set_config('request.jwt.claim.sub','97100000-0000-4000-8000-000000000001',true);
create temp table regen_output(value jsonb) on commit drop;
insert into regen_output select public.customer_regenerate_bank_transfer(
  request_id,payment_id,2,old_intent_id,old_intent_version,regenerate_operation_id)
from pg_temp.regen_fixtures where i=3;
select pg_temp.regen_assert('expired ready regeneration changed',
  (select value->>'changed'='true' from regen_output));
select pg_temp.regen_assert('payment remains bank awaiting and version increments',exists(
  select 1 from public.payments p join pg_temp.regen_fixtures f on f.payment_id=p.id
  where f.i=3 and p.method='bank_transfer' and p.status='awaiting_payment' and p.version=3
    and p.amount_received is null and p.paid_at is null and p.verified_at is null));
select pg_temp.regen_assert('old intent closed without expiry extension',exists(
  select 1 from private.payment_bank_intents b join pg_temp.regen_fixtures f on f.old_intent_id=b.id
  where f.i=3 and b.status='expired' and b.version=3
    and b.expires_at<pg_catalog.clock_timestamp() and b.reference=f.old_reference));
select pg_temp.regen_assert('new unique ready intent and snapshot',
  (select count(*)=2 and count(*) filter(where b.status='ready')=1
      and count(distinct b.reference)=2 and count(distinct s.transfer_content)=2
   from private.payment_bank_intents b
   join private.payment_bank_qr_snapshots s on s.intent_id=b.id
   join pg_temp.regen_fixtures f on f.payment_id=b.payment_id where f.i=3));
select pg_temp.regen_assert('only one active intent',
  (select count(*)=1 from private.payment_bank_intents b join pg_temp.regen_fixtures f on f.payment_id=b.payment_id
   where f.i=3 and b.status in ('created','ready','matched','verified')));
select pg_temp.regen_assert('old expiry and new readiness are audited',
  exists(select 1 from private.payment_bank_audit a join pg_temp.regen_fixtures f on f.old_intent_id=a.intent_id
    where f.i=3 and a.old_status='ready' and a.new_status='expired' and a.resource_version=3)
  and exists(select 1 from private.payment_bank_audit a join private.payment_bank_intents b on b.id=a.intent_id
    join pg_temp.regen_fixtures f on f.payment_id=b.payment_id
    where f.i=3 and b.status='ready' and a.old_status='created' and a.new_status='ready' and a.resource_version=2));
select pg_temp.regen_assert('renewal event and receipt atomic',
  (select count(*)=2 from public.payment_events e join pg_temp.regen_fixtures f on f.payment_id=e.payment_id
   where f.i=3 and e.event_type='bank_qr_created')
  and exists(select 1 from private.payment_rpc_receipts r join pg_temp.regen_fixtures f
    on f.regenerate_operation_id=r.operation_id where f.i=3 and r.operation_name='customer_regenerate_bank_transfer'));
select pg_temp.regen_assert('getter returns current intent and payment version',exists(
  select 1 from pg_temp.regen_fixtures f join private.payment_bank_intents b on b.payment_id=f.payment_id and b.status='ready'
  where f.i=3 and (public.customer_get_bank_payment(f.request_id)->>'bank_intent_id')::uuid=b.id
    and public.customer_get_bank_payment(f.request_id)->>'version'='3'));

select pg_temp.regen_assert('same operation exact replay unchanged',
  (select public.customer_regenerate_bank_transfer(
    request_id,payment_id,2,old_intent_id,old_intent_version,regenerate_operation_id)->>'changed'='false'
   from pg_temp.regen_fixtures where i=3));
select pg_temp.regen_assert('replay creates no extra intent',
  (select count(*)=2 from private.payment_bank_intents b join pg_temp.regen_fixtures f on f.payment_id=b.payment_id where f.i=3));
select pg_temp.regen_error('same operation changed payload conflicts',
 $$select public.customer_regenerate_bank_transfer(request_id,payment_id,3,old_intent_id,old_intent_version,regenerate_operation_id)
   from pg_temp.regen_fixtures where i=3$$,'22023','IDEMPOTENCY_CONFLICT');
select pg_temp.regen_error('old intent is no longer current',
 $$select public.customer_regenerate_bank_transfer(request_id,payment_id,3,old_intent_id,old_intent_version,gen_random_uuid())
   from pg_temp.regen_fixtures where i=3$$,'P0001','BANK_INTENT_UNAVAILABLE');

select pg_temp.regen_error('payment version conflict',
 $$select public.customer_regenerate_bank_transfer(request_id,payment_id,1,old_intent_id,old_intent_version,regenerate_operation_id)
   from pg_temp.regen_fixtures where i=4$$,'P0001','VERSION_CONFLICT');
select pg_temp.regen_error('intent version conflict',
 $$select public.customer_regenerate_bank_transfer(request_id,payment_id,2,old_intent_id,old_intent_version+1,regenerate_operation_id)
   from pg_temp.regen_fixtures where i=5$$,'P0001','BANK_INTENT_VERSION_CONFLICT');

-- A trusted inbound observation for the old exact code is terminally rejected
-- as expired, then regeneration must fail closed for reconciliation.
create temp table regen_bank_inputs(i integer primary key,n jsonb) on commit drop;
insert into regen_bank_inputs
select f.i,pg_catalog.jsonb_build_object(
  'provider','test_only','provider_scope','regeneration','provider_transaction_id','regen-tx-'||f.i,
  'provider_event_id','regen-event-'||f.i,'delivery_id','regen-delivery-'||f.i,
  'amount',p.amount_expected::text,'currency','VND','direction','credit',
  'transfer_reference',f.old_transfer_content,
  'occurred_at',pg_catalog.to_char(pg_catalog.clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  'beneficiary_bank_bin','970436','beneficiary_account_number','123456789012',
  'authentication_verified',true,'signature_verified',false,'authentication_method','token',
  'raw_payload_sha256',pg_catalog.encode(pg_catalog.sha256(
    pg_catalog.convert_to('regeneration-observation-'||f.i,'UTF8')),'hex'))
from pg_temp.regen_fixtures f join public.payments p on p.id=f.payment_id where f.i in (7,9);
select pg_temp.regen_assert('expired inbound is terminally recorded',
  (private.process_verified_bank_transaction((select n from regen_bank_inputs where i=7))->>'result')='intent_expired');
select pg_temp.regen_error('inbound old code requires reconciliation',
 $$select public.customer_regenerate_bank_transfer(request_id,payment_id,2,old_intent_id,old_intent_version,regenerate_operation_id)
   from pg_temp.regen_fixtures where i=7$$,'P0001','BANK_TRANSFER_RECONCILIATION_REQUIRED');
select pg_temp.regen_assert('reconciliation block leaves original state',exists(
  select 1 from public.payments p join pg_temp.regen_fixtures f on f.payment_id=p.id
  join private.payment_bank_intents b on b.id=f.old_intent_id
  where f.i=7 and p.version=2 and p.status='awaiting_payment' and b.status='ready' and b.version=2));

-- Event failure rolls back old close, new intent/snapshot, payment bump and receipt.
alter table public.payment_events add constraint regeneration_event_failure
  check(not (event_type='bank_qr_created' and metadata @> '{"regenerated":true}'::jsonb)) not valid;
select pg_temp.regen_error('regeneration event failure is atomic',
 $$select public.customer_regenerate_bank_transfer(request_id,payment_id,2,old_intent_id,old_intent_version,regenerate_operation_id)
   from pg_temp.regen_fixtures where i=8$$,'P0001','PAYMENT_STATE_CONFLICT');
alter table public.payment_events drop constraint regeneration_event_failure;
select pg_temp.regen_assert('failed regeneration leaves no orphan',exists(
  select 1 from public.payments p join pg_temp.regen_fixtures f on f.payment_id=p.id
  join private.payment_bank_intents b on b.id=f.old_intent_id
  where f.i=8 and p.version=2 and b.status='ready' and b.version=2)
  and (select count(*)=1 from private.payment_bank_intents b join pg_temp.regen_fixtures f on f.payment_id=b.payment_id where f.i=8)
  and not exists(select 1 from private.payment_rpc_receipts r join pg_temp.regen_fixtures f
    on f.regenerate_operation_id=r.operation_id where f.i=8));

-- Regenerate fixture 9, reject a late old-code transaction without touching the
-- new intent, then settle exactly once with the new code.
select public.customer_regenerate_bank_transfer(
  request_id,payment_id,2,old_intent_id,old_intent_version,regenerate_operation_id)
from pg_temp.regen_fixtures where i=9;
select pg_temp.regen_assert('late old webhook cannot settle new intent',
  (private.process_verified_bank_transaction((select n from regen_bank_inputs where i=9))->>'result')='intent_ineligible'
  and exists(select 1 from public.payments p join pg_temp.regen_fixtures f on f.payment_id=p.id
    where f.i=9 and p.status='awaiting_payment' and p.version=3 and p.amount_received is null));
insert into regen_bank_inputs
select 90,n||pg_catalog.jsonb_build_object(
  'provider_transaction_id','regen-new-tx-9','provider_event_id','regen-new-event-9',
  'delivery_id','regen-new-delivery-9','transfer_reference',s.transfer_content,
  'occurred_at',pg_catalog.to_char(pg_catalog.clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  'raw_payload_sha256',repeat('9',64))
from regen_bank_inputs x
join pg_temp.regen_fixtures f on f.i=9
join private.payment_bank_intents b on b.payment_id=f.payment_id and b.status='ready'
join private.payment_bank_qr_snapshots s on s.intent_id=b.id where x.i=9;
select pg_temp.regen_assert('new intent webhook settles once',
  (private.process_verified_bank_transaction((select n from regen_bank_inputs where i=90))->>'result')='paid');
select pg_temp.regen_assert('new webhook replay does not settle twice',
  (private.process_verified_bank_transaction((select n from regen_bank_inputs where i=90))->>'result')='duplicate_event'
  and exists(select 1 from public.payments p join pg_temp.regen_fixtures f on f.payment_id=p.id
    where f.i=9 and p.status='paid' and p.version=4 and p.amount_received=p.amount_expected)
  and (select count(*)=1 from public.payment_events e join pg_temp.regen_fixtures f on f.payment_id=e.payment_id
    where f.i=9 and e.event_type='bank_payment_verified'));

-- Terminal/non-bank payment states stay ineligible even with a historical intent.
alter table public.payments disable trigger payment_core_guard;
update public.payments set status='verifying' where id=(select payment_id from regen_fixtures where i=10);
update public.payments set status='paid',amount_received=amount_expected,paid_at=clock_timestamp(),verified_at=clock_timestamp()
  where id=(select payment_id from regen_fixtures where i=11);
update public.payments set method='cash' where id=(select payment_id from regen_fixtures where i=12);
alter table public.payments enable trigger payment_core_guard;
select pg_temp.regen_error('verifying payment blocked',
 $$select public.customer_regenerate_bank_transfer(request_id,payment_id,2,old_intent_id,old_intent_version,regenerate_operation_id)
   from regen_fixtures where i=10$$,'P0001','PAYMENT_NOT_ELIGIBLE');
select pg_temp.regen_error('paid payment blocked',
 $$select public.customer_regenerate_bank_transfer(request_id,payment_id,2,old_intent_id,old_intent_version,regenerate_operation_id)
   from regen_fixtures where i=11$$,'P0001','PAYMENT_ALREADY_SETTLED');
select pg_temp.regen_error('cash payment blocked',
 $$select public.customer_regenerate_bank_transfer(request_id,payment_id,2,old_intent_id,old_intent_version,regenerate_operation_id)
   from regen_fixtures where i=12$$,'P0001','PAYMENT_NOT_ELIGIBLE');

do $acl$
declare role_name text;
begin
  perform pg_temp.regen_assert('authenticated execute granted',
    pg_catalog.has_function_privilege('authenticated',
      'public.customer_regenerate_bank_transfer(uuid,uuid,bigint,uuid,bigint,uuid)','execute'));
  foreach role_name in array array['anon','service_role'] loop
    perform pg_temp.regen_assert(role_name||' execute denied',not pg_catalog.has_function_privilege(role_name,
      'public.customer_regenerate_bank_transfer(uuid,uuid,bigint,uuid,bigint,uuid)','execute'));
  end loop;
end;
$acl$;
set local role anon;
select pg_temp.regen_error('anon effective execute denied',
 $$select public.customer_regenerate_bank_transfer(request_id,payment_id,2,old_intent_id,old_intent_version,regenerate_operation_id)
   from pg_temp.regen_fixtures where i=4$$,'42501');
reset role;
select pg_temp.regen_assert('guards enabled',(select count(*)=3 from pg_catalog.pg_trigger where tgenabled='O'
  and tgname in ('payment_core_guard','bank_intent_guard','bank_qr_snapshot_guard')));
select pg_temp.regen_assert('private bank data remains unpublished',not exists(
  select 1 from pg_catalog.pg_publication_tables where schemaname='private'));

select 'PAYMENT_BANK_REGENERATION_PASS' result,count(*) assertions from pg_temp.regen_results;
rollback;
