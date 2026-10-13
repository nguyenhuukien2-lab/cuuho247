-- PRIVILEGED DISPOSABLE DATABASE ONLY. GD1..GD4 + GD6A + GD6B required.
-- psql -X -v ON_ERROR_STOP=1, SET payment.test_mode='local_disposable'.
-- Every fixture and fault injection rolls back; sequence advances do not.
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
create temp table bank_results(label text primary key) on commit drop;
create temp table bank_fixtures(i integer primary key,request_id uuid,payment_id uuid,original jsonb,
  operation_id uuid,expires_at timestamptz,intent_id uuid) on commit drop;
grant select,insert on pg_temp.bank_results to authenticated,anon;
grant select on pg_temp.bank_fixtures to authenticated,anon;
create function pg_temp.bank_assert(label text,ok boolean) returns void
language plpgsql security invoker as $$
begin
  if ok is distinct from true then raise exception 'TEST_FAIL: %',label; end if;
  insert into pg_temp.bank_results values(label);
end;
$$;
create function pg_temp.bank_error(label text,sql text,expected_state text,expected_message text default null)
returns void language plpgsql security invoker as $$
declare s text; m text;
begin
  begin execute sql;
  exception when others then get stacked diagnostics s=returned_sqlstate,m=message_text;
  end;
  if s is distinct from expected_state or (expected_message is not null and m is distinct from expected_message) then
    raise exception 'TEST_FAIL: %, expected % %, got % %',label,expected_state,expected_message,s,m;
  end if;
  perform pg_temp.bank_assert(label,true);
end;
$$;

select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);
insert into auth.users(id,email) select ('91000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
  'bank-foundation-test-'||i||'@example.invalid' from generate_series(1,4) i;
insert into public.rescuer_profiles(user_id,full_name,contact_phone,verification_status) values
 ('91000000-0000-4000-8000-000000000003','Synthetic rescuer','0900000003','approved');
insert into public.rescuer_vehicles(id,rescuer_id,kind,display_name,license_plate,verification_status) values
 ('96000000-0000-4000-8000-000000000003','91000000-0000-4000-8000-000000000003',
  'service_motorbike','Synthetic vehicle','GD6AFIXTURE','approved');
do $fixtures$
declare i integer; c uuid; r uuid; a uuid; q uuid; t timestamptz:=clock_timestamp(); d jsonb;
begin
  for i in 1..12 loop
    c:=case when i=2 then '91000000-0000-4000-8000-000000000002'::uuid
       else '91000000-0000-4000-8000-000000000001'::uuid end;
    r:=('92000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
    a:=('93000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
    q:=('94000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
    insert into public.rescue_requests(id,customer_id,client_request_id,vehicle_kind,service_code,
      location_text,location_confirmed,contact_name,contact_phone,status,provider_id)
    values(r,c,gen_random_uuid(),'motorbike','tire','Synthetic bank fixture',true,'Fixture','0900000001',
      'in_progress','91000000-0000-4000-8000-000000000003');
    insert into public.rescue_request_assignments(id,request_id,rescuer_id,vehicle_id,state,accepted_at,en_route_at,arrived_at,in_progress_at)
    values(a,r,'91000000-0000-4000-8000-000000000003','96000000-0000-4000-8000-000000000003','in_progress',t,t,t,t);
    insert into public.rescue_quotes(id,assignment_id,request_id,rescuer_id,revision,total_vnd,items)
    values(q,a,r,'91000000-0000-4000-8000-000000000003',1,100000*i,
      jsonb_build_array(jsonb_build_object('service_code','tire','quantity',1,'unit_price_vnd',100000*i)));
    update public.rescue_request_assignments set state='completed',completed_at=t,current_quote_id=q,completion_quote_id=q where id=a;
    update public.rescue_requests set status='completed',quoted_price=100000*i where id=r;
    perform set_config('request.jwt.claim.sub',c::text,true);
    d:=public.customer_prepare_payment(r);
    insert into pg_temp.bank_fixtures(i,request_id,payment_id,original,operation_id,expires_at)
    select i,r,p.id,to_jsonb(p),gen_random_uuid(),t+interval '1 hour' from public.payments p where p.id=(d->>'payment_id')::uuid;
  end loop;
end;
$fixtures$;
set constraints all immediate;
select set_config('request.jwt.claim.sub','',true);

-- All beneficiary values below are synthetic, rollback-only fixtures.
create temp table bank_outputs(label text primary key,value jsonb) on commit drop;
grant select,insert on bank_outputs to authenticated;
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select pg_temp.bank_assert('absent config fails closed',
 (public.customer_get_bank_capability((select request_id from bank_fixtures where i=1))->>'available')::boolean=false);
select pg_temp.bank_error('absent config cannot select',
 $$select public.customer_select_bank_transfer(request_id,payment_id,1,operation_id) from bank_fixtures where i=1$$,'P0001','BANK_UNAVAILABLE');
reset role;
insert into private.payment_bank_config(bank_bin,bank_code,bank_name,account_number,account_name)
 values('970436','TESTBANK','Synthetic test bank','123456789012','SYNTHETIC BENEFICIARY');
set local role authenticated;
select pg_temp.bank_error('disabled config cannot select',
 $$select public.customer_select_bank_transfer(request_id,payment_id,1,operation_id) from bank_fixtures where i=1$$,'P0001','BANK_UNAVAILABLE');
reset role;
update private.payment_bank_config set enabled=true;
set local role authenticated;
select pg_temp.bank_assert('enabled owner capability',
 (public.customer_get_bank_capability((select request_id from bank_fixtures where i=1))->>'available')::boolean);
select pg_temp.bank_error('other owner blocked select',
 $$select public.customer_select_bank_transfer(request_id,payment_id,1,operation_id) from bank_fixtures where i=2$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.bank_error('other owner blocked getter',
 $$select public.customer_get_bank_payment(request_id) from bank_fixtures where i=2$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.bank_error('other owner blocked capability',
 $$select public.customer_get_bank_capability(request_id) from bank_fixtures where i=2$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.bank_error('wrong payment binding',
 $$select public.customer_select_bank_transfer(f.request_id,g.payment_id,1,f.operation_id) from bank_fixtures f,bank_fixtures g where f.i=1 and g.i=2$$,
 '42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.bank_error('version conflict',
 $$select public.customer_select_bank_transfer(request_id,payment_id,2,operation_id) from bank_fixtures where i=1$$,'P0001','VERSION_CONFLICT');
select pg_temp.bank_error('missing operation',
 $$select public.customer_select_bank_transfer(request_id,payment_id,1,null) from bank_fixtures where i=1$$,'22023','IDEMPOTENCY_KEY_REQUIRED');
insert into bank_outputs select 'selected',public.customer_select_bank_transfer(request_id,payment_id,1,operation_id) from bank_fixtures where i=1;
insert into bank_outputs select 'retry',public.customer_select_bank_transfer(request_id,payment_id,1,operation_id) from bank_fixtures where i=1;
insert into bank_outputs select 'getter',public.customer_get_bank_payment(request_id) from bank_fixtures where i=1;
select pg_temp.bank_assert('owner selection awaiting never paid',
 (select value->'payment'->>'method'='bank_transfer' and value->'payment'->>'status'='awaiting_payment'
 and value->'payment'->>'version'='2' and (value->>'changed')::boolean from bank_outputs where label='selected'));
select pg_temp.bank_assert('same payload retry deterministic',
 (select a.value->'payment'=b.value->'payment' and (b.value->>'changed')::boolean=false
 from bank_outputs a,bank_outputs b where a.label='selected' and b.label='retry'));
select pg_temp.bank_error('changed retry payload conflicts',
 $$select public.customer_select_bank_transfer(request_id,payment_id,2,operation_id) from bank_fixtures where i=1$$,'22023','IDEMPOTENCY_CONFLICT');
select pg_temp.bank_error('new key bank selection does not create obligation',
 $$select public.customer_select_bank_transfer(request_id,payment_id,2,gen_random_uuid()) from bank_fixtures where i=1$$,'P0001','PAYMENT_NOT_ELIGIBLE');
select pg_temp.bank_error('bank cannot switch cash',
 $$select public.customer_select_payment_method(request_id,payment_id,'cash',2,gen_random_uuid()) from bank_fixtures where i=1$$,'P0001','PAYMENT_NOT_ELIGIBLE');
select pg_temp.bank_error('shared receipt namespace',
 $$select public.customer_select_payment_method(request_id,payment_id,'cash',1,operation_id) from bank_fixtures where i=1$$,'22023','IDEMPOTENCY_CONFLICT');
select pg_temp.bank_assert('getter exact safe fields',
 (select array_agg(k order by k)=array(select unnest(array['payment_id','payment_code','request_id','payment_status','payment_method',
 'amount_expected','currency','bank_intent_status','bank_reference','bank_code','bank_bin','bank_name','account_number','account_name',
 'transfer_content','expires_at','server_time','available','qr_payload','version','bank_intent_version']) order by 1)
 from bank_outputs,jsonb_object_keys(value) k where label='getter'));
reset role;
select pg_temp.bank_assert('one active intent one snapshot one bank event',
 (select count(*)=1 from private.payment_bank_intents) and (select count(*)=1 from private.payment_bank_qr_snapshots)
 and (select count(*)=1 from public.payment_events where event_type='bank_qr_created'));
select pg_temp.bank_assert('amount reference beneficiary bindings',exists(
 select 1 from private.payment_bank_intents i join public.payments p on p.id=i.payment_id
 join private.payment_bank_qr_snapshots s on s.intent_id=i.id where i.expected_amount=p.amount_expected
 and i.request_id=p.request_id and i.currency='VND' and i.reference ~ '^BK-[0-9A-F]{32}$'
 and i.status='ready' and i.version=2 and s.transfer_content ~ '^BK[0-9]{19}$'
 and s.account_number='123456789012' and s.qr_payload=private.payment_bank_vietqr(s.bank_bin,s.account_number,p.amount_expected,s.transfer_content)));
select pg_temp.bank_assert('CRC known vector',private.payment_bank_crc16('123456789')='29B1');
select pg_temp.bank_assert('QR contains server amount and exact content',
 (select position('5406100000' in value->>'qr_payload')>0
 and position('62250821'||(value->>'transfer_content') in value->>'qr_payload')>0
 and right(value->>'qr_payload',4)=private.payment_bank_crc16(left(value->>'qr_payload',length(value->>'qr_payload')-4))
 from bank_outputs where label='getter'));
select pg_temp.bank_error('QR rejects overflowing EMV amount',
 $$select private.payment_bank_vietqr('970436','123456789012',10000000000000,'BK1')$$,'22023','BANK_QR_VALUE_INVALID');
select pg_temp.bank_error('snapshot immutable',
 $$update private.payment_bank_qr_snapshots set account_number='999999999'$$,'23514','BANK_QR_SNAPSHOT_IMMUTABLE');
select pg_temp.bank_error('bank cannot mark paid even owner writer',
 $$update public.payments set status='paid',version=version+1 where method='bank_transfer'$$,'23514','PAYMENT_MUTATION_NOT_ENABLED');
select pg_temp.bank_error('intent cannot verify',
 $$update private.payment_bank_intents set status='verified',version=version+1$$,'23514','BANK_INTENT_TRANSITION_NOT_ENABLED');
update private.payment_bank_config set bank_name='Changed config',account_number='987654321098';
select pg_temp.bank_assert('snapshot unaffected by config rotation',
 (public.customer_get_bank_payment((select request_id from bank_fixtures where i=1))->>'account_number')='123456789012');
update private.payment_bank_config set enabled=false;
select pg_temp.bank_assert('kill switch hides existing QR',
 (public.customer_get_bank_payment((select request_id from bank_fixtures where i=1))->>'qr_payload') is null);
select pg_temp.bank_assert('retry after disabled config is acknowledgement only',
 (public.customer_select_bank_transfer((select request_id from bank_fixtures where i=1),(select payment_id from bank_fixtures where i=1),
 1,(select operation_id from bank_fixtures where i=1))->>'changed')::boolean=false);
update private.payment_bank_config set enabled=true;

-- Cash regression through unchanged public RPCs on the final GD6B schema.
set local role authenticated;
select public.customer_select_payment_method(request_id,payment_id,'cash',1,operation_id) from bank_fixtures where i=3;
select pg_temp.bank_error('cash cannot switch bank',
 $$select public.customer_select_bank_transfer(request_id,payment_id,2,gen_random_uuid()) from bank_fixtures where i=3$$,'P0001','PAYMENT_NOT_ELIGIBLE');
select pg_temp.bank_assert('bank getter cash returns null',public.customer_get_bank_payment((select request_id from bank_fixtures where i=3)) is null);
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000003',true);
select pg_temp.bank_error('cash amount mismatch unchanged',
 $$select public.rescuer_confirm_cash_received(request_id,payment_id,1,2,operation_id) from bank_fixtures where i=3$$,'P0001','PAYMENT_AMOUNT_MISMATCH');
select public.rescuer_confirm_cash_received(request_id,payment_id,300000,2,operation_id) from bank_fixtures where i=3;
select public.rescuer_confirm_cash_received(request_id,payment_id,300000,2,operation_id) from bank_fixtures where i=3;
reset role;
select pg_temp.bank_assert('cash paid once correct amount',
 (select p.status='paid' and p.method='cash' and p.version=3 and p.amount_received=300000
 from public.payments p join bank_fixtures f on f.payment_id=p.id where f.i=3)
 and (select count(*)=1 from public.payment_events where event_type='cash_received'));
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select pg_temp.bank_error('paid payment blocked bank',
 $$select public.customer_select_bank_transfer(request_id,payment_id,3,gen_random_uuid()) from bank_fixtures where i=3$$,'P0001','PAYMENT_ALREADY_SETTLED');
reset role;

-- Reuse an unissued GD6A reservation without changing reference/expiry.
update bank_fixtures set intent_id=private.payment_bank_create_intent(payment_id,operation_id,expires_at) where i=5;
select public.customer_select_bank_transfer(request_id,payment_id,1,gen_random_uuid()) from bank_fixtures where i=5;
select pg_temp.bank_assert('reuse foundation reservation',exists(select 1 from private.payment_bank_intents i join bank_fixtures f
 on f.intent_id=i.id where f.i=5 and i.status='ready' and i.expires_at=f.expires_at)
 and (select count(*)=1 from private.payment_bank_intents where payment_id=(select payment_id from bank_fixtures where i=5)));

-- Privileged fault injection is confined to rolled-back subtransactions.
do $states$
declare s text; v_request uuid; v_payment uuid;
begin
  select request_id,payment_id into v_request,v_payment from bank_fixtures where i=7;
  foreach s in array array['cancelled','refunded'] loop
    begin
      alter table public.payments disable trigger payment_core_guard;
      update public.payments set status=s,method=case when s='refunded' then 'cash' else null end where id=v_payment;
      alter table public.payments enable trigger payment_core_guard;
      perform pg_temp.bank_error(s||' bank blocked',format('select public.customer_select_bank_transfer(%L,%L,1,gen_random_uuid())',v_request,v_payment),
        'P0001',case when s='refunded' then 'PAYMENT_ALREADY_SETTLED' else 'PAYMENT_NOT_ELIGIBLE' end);
      raise exception using errcode='ZX001';
    exception when sqlstate 'ZX001' then null;
    end;
    perform pg_temp.bank_assert(s||' fixture restored',exists(select 1 from public.payments where id=v_payment and status='pending'));
  end loop;
  begin
    alter table public.payments disable trigger payment_core_guard;
    update public.payments set amount_expected=0 where id=v_payment;
    alter table public.payments enable trigger payment_core_guard;
    perform pg_temp.bank_error('zero blocked',format('select public.customer_select_bank_transfer(%L,%L,1,gen_random_uuid())',v_request,v_payment),
      'P0001','ZERO_AMOUNT_REQUIRES_POLICY');
    raise exception using errcode='ZX001';
  exception when sqlstate 'ZX001' then null;
  end;
  perform pg_temp.bank_assert('zero fixture restored',exists(select 1 from public.payments where id=v_payment and amount_expected>0));
end;
$states$;
do $expiry$
declare v_id uuid; v_request uuid; d jsonb;
begin
  select i.id,i.request_id into v_id,v_request from private.payment_bank_intents i join bank_fixtures f on f.payment_id=i.payment_id where f.i=1;
  begin
    alter table private.payment_bank_intents disable trigger bank_intent_guard;
    update private.payment_bank_intents set created_at=statement_timestamp()-interval '2 hours',
      updated_at=statement_timestamp()-interval '1 hour',expires_at=statement_timestamp()-interval '1 minute' where id=v_id;
    alter table private.payment_bank_intents enable trigger bank_intent_guard;
    d:=public.customer_get_bank_payment(v_request);
    if d->>'bank_intent_status'<>'expired' or d->>'qr_payload' is not null or d->>'payment_status'<>'awaiting_payment' then
      raise exception 'TEST_FAIL: server expiry';
    end if;
    raise exception using errcode='ZX001';
  exception when sqlstate 'ZX001' then null;
  end;
  perform pg_temp.bank_assert('server expiry suppresses QR without payment mutation',true);
end;
$expiry$;

-- Atomic rollback of intent, snapshot, payment, event and receipt on audit failure.
alter table public.payment_events add constraint bank_test_event_failure check(event_type<>'bank_qr_created') not valid;
select pg_temp.bank_error('atomic event failure',
 $$select public.customer_select_bank_transfer(request_id,payment_id,1,operation_id) from bank_fixtures where i=8$$,'P0001','PAYMENT_STATE_CONFLICT');
alter table public.payment_events drop constraint bank_test_event_failure;
select pg_temp.bank_assert('failure no orphan obligation',
 not exists(select 1 from private.payment_bank_intents where payment_id=(select payment_id from bank_fixtures where i=8))
 and (select status='pending' and version=1 from public.payments where id=(select payment_id from bank_fixtures where i=8))
 and not exists(select 1 from private.payment_rpc_receipts where payment_id=(select payment_id from bank_fixtures where i=8)));

do $acl$
declare r text; t text; f text;
begin
  foreach t in array array['payment_bank_intents','bank_transactions','payment_webhook_receipts','payment_bank_audit','payment_bank_config','payment_bank_qr_snapshots'] loop
    perform pg_temp.bank_assert('private RLS '||t,(select relrowsecurity from pg_class where oid=('private.'||t)::regclass)
      and not exists(select 1 from pg_policy where polrelid=('private.'||t)::regclass));
    foreach r in array array['anon','authenticated','service_role'] loop
      perform pg_temp.bank_assert('no private privileges '||r||t,not has_table_privilege(r,'private.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));
    end loop;
  end loop;
  foreach f in array array['public.customer_get_bank_capability(uuid)','public.customer_get_bank_payment(uuid)',
    'public.customer_select_bank_transfer(uuid,uuid,bigint,uuid)'] loop
    perform pg_temp.bank_assert('definer empty search path '||f,(select prosecdef and 'search_path=""'=any(proconfig) from pg_proc where oid=f::regprocedure));
    perform pg_temp.bank_assert('narrow execute '||f,has_function_privilege('authenticated',f,'execute')
      and not has_function_privilege('anon',f,'execute') and not has_function_privilege('service_role',f,'execute'));
  end loop;
end;
$acl$;
set local role authenticated;
do $client$
declare t text;
begin
  foreach t in array array['payment_bank_intents','bank_transactions','payment_webhook_receipts','payment_bank_audit','payment_bank_config','payment_bank_qr_snapshots'] loop
    perform pg_temp.bank_error('effective unreadable '||t,'select * from private.'||t,'42501');
  end loop;
end;
$client$;
select pg_temp.bank_error('direct paid write denied',$$update public.payments set status='paid'$$,'42501');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.bank_error('auth uid required',$$select public.customer_get_bank_payment(null)$$,'42501','AUTHENTICATION_REQUIRED');
set local role anon;
select pg_temp.bank_error('anon getter denied',$$select public.customer_get_bank_payment(null)$$,'42501');
select pg_temp.bank_error('anon select denied',$$select public.customer_select_bank_transfer(null,null,1,null)$$,'42501');
reset role;
select pg_temp.bank_assert('no private or event publication',not exists(select 1 from pg_publication_tables
 where schemaname='private' or (schemaname='public' and tablename='payment_events')));
select pg_temp.bank_assert('no bank auto paid',not exists(select 1 from public.payments where method='bank_transfer'
 and (status<>'awaiting_payment' or paid_at is not null or verified_at is not null or amount_received is not null)));
select pg_temp.bank_assert('no webhook ingest',not exists(select 1 from private.payment_webhook_receipts)
 and not exists(select 1 from private.bank_transactions));
select pg_temp.bank_assert('guards restored',(select count(*)=2 from pg_trigger where tgenabled='O' and
 ((tgrelid='public.payments'::regclass and tgname='payment_core_guard') or (tgrelid='private.payment_bank_intents'::regclass and tgname='bank_intent_guard'))));
select 'PAYMENT_BANK_QR_PASS' result,count(*) assertions from bank_results;
rollback;
