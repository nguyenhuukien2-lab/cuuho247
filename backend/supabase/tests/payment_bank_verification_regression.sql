-- PRIVILEGED DISPOSABLE DATABASE ONLY. GD1..GD4 + GD6A + GD6B + GD6C required.
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
  for i in 1..30 loop
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


-- SYNTHETIC INTERNAL NORMALIZED OBSERVATIONS ONLY, NOT PROVIDER WEBHOOK FIXTURES.
insert into private.payment_bank_config(bank_bin,bank_code,bank_name,account_number,account_name,enabled)
 values('970436','TESTBANK','Synthetic test bank','123456789012','SYNTHETIC BENEFICIARY',true);
select pg_temp.bank_assert('verification off by default',not (select verification_enabled from private.payment_bank_config));
do $select_bank$
declare f record;
begin
  for f in select * from bank_fixtures where i<>30 loop
    perform set_config('request.jwt.claim.sub',case when f.i=2 then '91000000-0000-4000-8000-000000000002'
      else '91000000-0000-4000-8000-000000000001' end,true);
    perform public.customer_select_bank_transfer(f.request_id,f.payment_id,1,f.operation_id);
  end loop;
end;
$select_bank$;
select set_config('request.jwt.claim.sub','',true);
create temp table bank_inputs(i integer primary key,n jsonb) on commit drop;
grant select on bank_inputs to anon,authenticated,service_role;
insert into bank_inputs select f.i,jsonb_build_object(
  'provider','test_only','provider_scope','disposable','provider_transaction_id','tx-'||f.i,
  'provider_event_id','event-'||f.i,'delivery_id','delivery-'||f.i,
  'amount',p.amount_expected::text,'currency','VND','direction','credit','transfer_reference',s.transfer_content,
  'occurred_at',to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  'beneficiary_bank_bin',s.bank_bin,'beneficiary_account_number',s.account_number,
  'authentication_verified',true,'signature_verified',false,'authentication_method','token',
  'raw_payload_sha256',encode(sha256(convert_to('internal-observation-'||f.i,'UTF8')),'hex'))
 from bank_fixtures f join public.payments p on p.id=f.payment_id
 join private.payment_bank_intents b on b.payment_id=p.id join private.payment_bank_qr_snapshots s on s.intent_id=b.id;
select pg_temp.bank_error('disabled refuses internal ingest',
 $$select private.process_verified_bank_transaction(n) from bank_inputs where i=1$$,'55000','BANK_VERIFICATION_DISABLED');
select pg_temp.bank_assert('disabled leaves no inbox',not exists(select 1 from private.payment_webhook_receipts));

do $acl$
declare r text; t text;
begin
  foreach r in array array['anon','authenticated','service_role'] loop
    perform pg_temp.bank_assert('processor execute denied '||r,not has_function_privilege(r,'private.process_verified_bank_transaction(jsonb)','execute'));
    foreach t in array array['payment_bank_intents','bank_transactions','payment_webhook_receipts','payment_bank_audit','payment_bank_config','payment_bank_qr_snapshots'] loop
      perform pg_temp.bank_assert('private table denied '||r||t,not has_table_privilege(r,'private.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));
    end loop;
  end loop;
end;
$acl$;
set local role anon;
select pg_temp.bank_error('anon effective processor denied',$$select private.process_verified_bank_transaction('{}')$$,'42501');
select pg_temp.bank_error('anon private unreadable',$$select * from private.bank_transactions$$,'42501');
set local role authenticated;
select pg_temp.bank_error('authenticated effective processor denied',$$select private.process_verified_bank_transaction('{}')$$,'42501');
select pg_temp.bank_error('authenticated private unreadable',$$select * from private.payment_webhook_receipts$$,'42501');
select pg_temp.bank_error('customer cannot set paid',$$update public.payments set status='paid'$$,'42501');
reset role;
-- Enable only inside disposable rollback transaction, never production/config seed.
update private.payment_bank_config set verification_enabled=true,verification_provider='test_only',verification_scope='disposable';
select private.record_bank_auth_failure('test_only','disposable',repeat('f',64));
select pg_temp.bank_assert('failed auth audit without canonical receipt',
 exists(select 1 from private.payment_bank_audit where action='auth_failed') and not exists(select 1 from private.payment_webhook_receipts));
select pg_temp.bank_error('untrusted evidence rejected',
 $$select private.process_verified_bank_transaction(n||'{"authentication_verified":false}') from bank_inputs where i=1$$,'22023','BANK_NORMALIZED_INPUT_INVALID');
select pg_temp.bank_error('fake signature claim rejected',
 $$select private.process_verified_bank_transaction(n||'{"authentication_method":"signature"}') from bank_inputs where i=1$$,'22023','BANK_NORMALIZED_INPUT_INVALID');
select pg_temp.bank_error('raw payload refused',
 $$select private.process_verified_bank_transaction(n||'{"raw_payload":{"sensitive":"fixture"}}') from bank_inputs where i=1$$,'22023','BANK_NORMALIZED_INPUT_INVALID');
do $malformed$
declare v jsonb;
begin
  for v in select value from jsonb_array_elements('[{"amount":100000},{"amount":"1.1"},{"amount":"9223372036854775808"},
    {"amount":"0"},{"occurred_at":"infinity"},{"occurred_at":"2026-02-30T00:00:00Z"},
    {"occurred_at":"2026-10-11T24:00:00Z"},{"occurred_at":"2026-10-11T00:00:60Z"},{"signature_verified":null}]') loop
    perform pg_temp.bank_error('malformed '||v::text,
      format('select private.process_verified_bank_transaction(n||%L::jsonb) from bank_inputs where i=1',v::text),'22023','BANK_NORMALIZED_INPUT_INVALID');
  end loop;
end;
$malformed$;
select pg_temp.bank_assert('valid exact match paid',(private.process_verified_bank_transaction((select n from bank_inputs where i=1))->>'result')='paid');
select pg_temp.bank_assert('exact amount server paid time version once',exists(
 select 1 from public.payments p join bank_fixtures f on f.payment_id=p.id where f.i=1 and p.status='paid'
 and p.amount_received=100000 and p.version=3 and p.paid_at=p.verified_at and p.paid_at>=p.created_at
 and p.paid_at<=clock_timestamp() and p.cash_received_by is null and p.cash_received_at is null));
select pg_temp.bank_assert('intent transaction verified bind request',exists(
 select 1 from private.bank_transactions t join private.payment_bank_intents i on i.id=t.matched_intent_id
 join public.payments p on p.id=t.matched_payment_id and p.request_id=i.request_id
 where t.external_transaction_id='tx-1' and t.status='verified' and i.status='verified'));
select pg_temp.bank_assert('token not falsely labelled signed',(select authentication_verified and not signature_verified
 from private.payment_webhook_receipts where event_id='event-1'));
select pg_temp.bank_assert('same delivery replay',(private.process_verified_bank_transaction((select n from bank_inputs where i=1))->>'result')='duplicate_event');
select pg_temp.bank_assert('same event new delivery replay',(private.process_verified_bank_transaction(
 (select n||'{"delivery_id":"retry-delivery"}' from bank_inputs where i=1))->>'result')='duplicate_event');
select pg_temp.bank_assert('changed body same event conflict',(private.process_verified_bank_transaction(
 (select n||jsonb_build_object('raw_payload_sha256',repeat('c',64)) from bank_inputs where i=1))->>'result')='identity_conflict');
select pg_temp.bank_assert('changed normalized amount same event conflict',(private.process_verified_bank_transaction(
 (select n||'{"amount":"100001"}' from bank_inputs where i=1))->>'result')='identity_conflict');
select pg_temp.bank_assert('new event same transaction deduped',(private.process_verified_bank_transaction(
 (select n||'{"provider_event_id":"event-1-new","delivery_id":"delivery-1-new"}' from bank_inputs where i=1))->>'result')='duplicate_transaction');
select pg_temp.bank_assert('transaction cannot settle second payment',(private.process_verified_bank_transaction(
 (select n||jsonb_build_object('provider_event_id','conflicting-event','delivery_id','conflicting-delivery',
 'transfer_reference',(select n->>'transfer_reference' from bank_inputs where i=2),'amount','200000') from bank_inputs where i=1))->>'result')='transaction_conflict');
select pg_temp.bank_assert('second payment untouched',(select p.status='awaiting_payment' and p.version=2 from public.payments p join bank_fixtures f on f.payment_id=p.id where f.i=2));
select pg_temp.bank_assert('new transaction on already paid rejected',(private.process_verified_bank_transaction(
 (select n||'{"provider_transaction_id":"tx-second","provider_event_id":"event-second","delivery_id":"delivery-second"}' from bank_inputs where i=1))->>'result')='already_paid');
select pg_temp.bank_assert('single settlement after duplicates',
 (select count(*)=1 from private.bank_transactions where status='verified')
 and (select count(*)=1 from public.payment_events where event_type='bank_payment_verified')
 and (select p.version=3 from public.payments p join bank_fixtures f on f.payment_id=p.id where f.i=1));

-- Each mismatch gets its own canonical identity. Preserve facts, never paid.
create temp table bank_cases(i integer primary key,patch jsonb,expected text) on commit drop;
insert into bank_cases values
 (3,'{"amount":"299999"}','amount_mismatch'),(4,'{"amount":"400001"}','amount_mismatch'),
 (5,'{"currency":"USD"}','currency_mismatch'),(6,'{"transfer_reference":null}','reference_unmatched'),
 (7,'{"transfer_reference":"WRONG"}','reference_unmatched'),
 (8,jsonb_build_object('transfer_reference',lower((select n->>'transfer_reference' from bank_inputs where i=8))),'reference_unmatched'),
 (9,jsonb_build_object('transfer_reference','prefix'||(select n->>'transfer_reference' from bank_inputs where i=9)),'reference_unmatched'),
 (10,jsonb_build_object('transfer_reference',(select n->>'transfer_reference' from bank_inputs where i=2)),'amount_mismatch'),
 (11,'{"beneficiary_account_number":"999999999999"}','beneficiary_mismatch'),
 (12,'{"beneficiary_bank_bin":"000000"}','beneficiary_mismatch'),
 (13,'{"beneficiary_account_number":null}','beneficiary_mismatch'),(14,'{"direction":"debit"}','not_credit'),
 (15,'{"occurred_at":"2000-01-01T00:00:00Z"}','transaction_time_invalid'),
 (16,'{}','intent_expired'),(17,'{}','intent_ineligible'),
 (18,jsonb_build_object('transfer_reference',(select n->>'transfer_reference' from bank_inputs where i=18)||' '),'reference_unmatched');
-- Explicit privileged expiry fault injection, restored immediately. No time-based sleeps.
alter table private.payment_bank_intents disable trigger bank_intent_guard;
update private.payment_bank_intents set created_at=clock_timestamp()-interval '2 hours',
 updated_at=clock_timestamp(),expires_at=clock_timestamp()-interval '1 hour'
 where payment_id=(select payment_id from bank_fixtures where i=16);
alter table private.payment_bank_intents enable trigger bank_intent_guard;
update private.payment_bank_intents set status='cancelled',version=version+1 where payment_id=(select payment_id from bank_fixtures where i=17);
do $cases$
declare f record; v jsonb;
begin
  for f in select c.*,b.n from bank_cases c join bank_inputs b using(i) loop
    v:=private.process_verified_bank_transaction(f.n||f.patch);
    perform pg_temp.bank_assert('mismatch '||f.i||' '||f.expected,v->>'result'=f.expected and v->>'changed'='false');
    perform pg_temp.bank_assert('mismatch preserved '||f.i,exists(select 1 from private.bank_transactions
      where external_transaction_id='tx-'||f.i and status='rejected' and rejection_code=f.expected and matched_payment_id is null));
    perform pg_temp.bank_assert('mismatch unpaid '||f.i,exists(select 1 from public.payments p join bank_fixtures b
      on b.payment_id=p.id where b.i=f.i and p.status='awaiting_payment' and p.amount_received is null and p.version=2));
  end loop;
end;
$cases$;

select pg_temp.bank_assert('body hash fallback paid',(private.process_verified_bank_transaction(
 (select n-array['provider_event_id','delivery_id'] from bank_inputs where i=19))->>'result')='paid');
select pg_temp.bank_assert('body fallback replay',(private.process_verified_bank_transaction(
 (select n-array['provider_event_id','delivery_id'] from bank_inputs where i=19))->>'result')='duplicate_event');
select pg_temp.bank_assert('body fallback namespaced',(select delivery_id like 'body:%' from private.payment_webhook_receipts where event_id is null));

-- Audit/event failure must roll back receipt, observation, intent AND payment.
alter table public.payment_events add constraint gd6c_event_failure check(event_type<>'bank_payment_verified') not valid;
select pg_temp.bank_error('atomic event append failure',
 $$select private.process_verified_bank_transaction(n) from bank_inputs where i=20$$,'23514');
alter table public.payment_events drop constraint gd6c_event_failure;
select pg_temp.bank_assert('failed settlement leaves no receipt or observation',
 not exists(select 1 from private.bank_transactions where external_transaction_id='tx-20')
 and not exists(select 1 from private.payment_webhook_receipts where event_id='event-20')
 and (select p.status='awaiting_payment' and p.version=2 from public.payments p join bank_fixtures f on f.payment_id=p.id where f.i=20));
select pg_temp.bank_assert('retry after rollback succeeds',(private.process_verified_bank_transaction((select n from bank_inputs where i=20))->>'result')='paid');
alter table private.payment_bank_audit add constraint gd6c_audit_failure check(action<>'payment_transitioned') not valid;
select pg_temp.bank_error('atomic audit append failure',
 $$select private.process_verified_bank_transaction(n) from bank_inputs where i=21$$,'23514');
alter table private.payment_bank_audit drop constraint gd6c_audit_failure;
select pg_temp.bank_assert('failed audit leaves no receipt',not exists(select 1 from private.payment_webhook_receipts where event_id='event-21'));

update private.payment_bank_config set account_number='987654321098';
select pg_temp.bank_assert('rotated account fails closed',(private.process_verified_bank_transaction((select n from bank_inputs where i=22))->>'result')='config_mismatch');
update private.payment_bank_config set account_number='123456789012';
select pg_temp.bank_error('wrong provider scope fails closed',
 $$select private.process_verified_bank_transaction(n||'{"provider_scope":"untrusted-account"}') from bank_inputs where i=23$$,'55000','BANK_VERIFICATION_DISABLED');
select pg_temp.bank_assert('wrong scope leaves no receipt',not exists(select 1 from private.payment_webhook_receipts where event_id='event-23'));
-- Explicit owner policy only: verified provider scope binds BIN/account if the
-- actual contract supplies no beneficiary. Default requires both identifiers.
update private.payment_bank_config set require_beneficiary=false;
select pg_temp.bank_assert('scope-bound missing beneficiary policy',(private.process_verified_bank_transaction(
 (select n-array['beneficiary_bank_bin','beneficiary_account_number'] from bank_inputs where i=23))->>'result')='paid');
select pg_temp.bank_assert('available beneficiary always checked',(private.process_verified_bank_transaction(
 (select n||'{"beneficiary_account_number":"wrong"}' from bank_inputs where i=24))->>'result')='beneficiary_mismatch');
update private.payment_bank_config set require_beneficiary=true;
alter table public.payments disable trigger payment_core_guard;
update public.payments set method='cash' where id=(select payment_id from bank_fixtures where i=25);
alter table public.payments enable trigger payment_core_guard;
select pg_temp.bank_assert('bank cannot settle cash method',(private.process_verified_bank_transaction((select n from bank_inputs where i=25))->>'result')='method_mismatch');
select pg_temp.bank_assert('future provider timestamp rejected',(private.process_verified_bank_transaction(
 (select n||'{"occurred_at":"9999-01-01T00:00:00Z"}' from bank_inputs where i=26))->>'result')='transaction_time_invalid');
update private.payment_bank_config set verification_enabled=false;
select pg_temp.bank_error('verification kill switch refuses new ingress',
 $$select private.process_verified_bank_transaction(n) from bank_inputs where i=27$$,'55000','BANK_VERIFICATION_DISABLED');
select pg_temp.bank_assert('kill switch keeps QR enabled',(select enabled from private.payment_bank_config));
update private.payment_bank_config set verification_enabled=true;
select pg_temp.bank_error('intent payment request binding immutable',
 $$update private.payment_bank_intents set request_id=(select request_id from bank_fixtures where i=2)
 where payment_id=(select payment_id from bank_fixtures where i=27)$$,'23514','BANK_INTENT_SNAPSHOT_IMMUTABLE');
-- Closing the QR display does not undo transfers already instructed by a valid
-- immutable snapshot; the verification kill switch is separate.
update private.payment_bank_config set enabled=false;
select pg_temp.bank_assert('QR display switch does not discard valid transfer',(private.process_verified_bank_transaction((select n from bank_inputs where i=27))->>'result')='paid');
update private.payment_bank_config set enabled=true;
-- Same timestamp expressed in another timezone remains the same observation.
select pg_temp.bank_assert('equivalent timestamp normalized for dedupe',(private.process_verified_bank_transaction(
 (select n||jsonb_build_object('provider_event_id','timezone-retry','delivery_id','timezone-retry',
 'occurred_at',to_char((n->>'occurred_at')::timestamptz at time zone 'Asia/Bangkok','YYYY-MM-DD"T"HH24:MI:SS.US')||'+07:00')
 from bank_inputs where i=1))->>'result')='duplicate_transaction');

select pg_temp.bank_error('verified transaction amount immutable',
 $$update private.bank_transactions set amount=amount+1 where external_transaction_id='tx-1'$$,'23514','BANK_RECORD_IMMUTABLE');
select pg_temp.bank_error('verified transaction cannot rebind',
 $$update private.bank_transactions set matched_payment_id=(select payment_id from bank_fixtures where i=2) where external_transaction_id='tx-1'$$,'23514','BANK_RECORD_IMMUTABLE');
select pg_temp.bank_error('immutable receipt hash',
 $$update private.payment_webhook_receipts set body_sha256=repeat('e',64) where event_id='event-1'$$,'23514','BANK_RECORD_IMMUTABLE');
select pg_temp.bank_error('events immutable',$$update public.payment_events set metadata='{}'$$,'23514','PAYMENT_EVENT_IMMUTABLE');
select pg_temp.bank_error('events cannot delete',$$delete from public.payment_events$$,'23514','PAYMENT_EVENT_IMMUTABLE');
select pg_temp.bank_error('audit immutable',$$delete from private.payment_bank_audit$$,'23514','BANK_AUDIT_IMMUTABLE');
select pg_temp.bank_error('paid cannot settle twice',
 $$update public.payments set version=version+1 where id=(select payment_id from bank_fixtures where i=1)$$,'23514','PAYMENT_MUTATION_NOT_ENABLED');
select pg_temp.bank_assert('all required audit actions present',not exists(
 select unnest(array['webhook_received','auth_verified','auth_failed','duplicate','conflict','transaction_normalized',
 'match_succeeded','match_rejected','payment_transitioned']) except select action from private.payment_bank_audit));
select pg_temp.bank_assert('safe public bank event',not exists(select 1 from public.payment_events where event_type='bank_payment_verified'
 and (metadata<>'{}' or actor_type<>'system' or actor_id is not null or new_status<>'paid')));
select pg_temp.bank_assert('payment event uses server timestamp',not exists(select 1 from public.payment_events e
 join public.payments p on p.id=e.payment_id where e.event_type='bank_payment_verified' and e.created_at<>p.paid_at));
select pg_temp.bank_assert('raw data absent in public schema',not exists(select 1 from information_schema.columns
 where table_schema='public' and table_name in ('payments','payment_events')
 and column_name in ('raw_payload','body_sha256','sender_info','signature','signature_verified','provider_token','provider_transaction_id')));
select pg_temp.bank_assert('no private realtime',not exists(select 1 from pg_publication_tables where schemaname='private'));
select pg_temp.bank_assert('no events realtime',not exists(select 1 from pg_publication_tables where schemaname='public' and tablename='payment_events'));
select pg_temp.bank_assert('payments remain realtime',exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='payments'));

select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select pg_temp.bank_assert('customer authoritative getter paid',
 (public.customer_get_payment((select request_id from bank_fixtures where i=1))->>'status')='paid');
select pg_temp.bank_assert('paid QR suppressed',(public.customer_get_bank_payment((select request_id from bank_fixtures where i=1))->>'qr_payload') is null);
select public.customer_select_payment_method(request_id,payment_id,'cash',1,operation_id) from bank_fixtures where i=30;
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000003',true);
select public.rescuer_confirm_cash_received(request_id,payment_id,3000000,2,operation_id) from bank_fixtures where i=30;
select public.rescuer_confirm_cash_received(request_id,payment_id,3000000,2,operation_id) from bank_fixtures where i=30;
reset role;
select pg_temp.bank_assert('cash still paid once',exists(select 1 from public.payments p join bank_fixtures f on f.payment_id=p.id
 where f.i=30 and p.method='cash' and p.status='paid' and p.version=3 and p.amount_received=3000000 and p.verified_at is null)
 and (select count(*)=1 from public.payment_events where event_type='cash_received'));
select pg_temp.bank_assert('guards enabled',(select count(*)=3 from pg_trigger where tgenabled='O'
 and tgname in ('payment_core_guard','bank_intent_guard','bank_transaction_guard')));
-- True multi-connection races are in the native runner, never simulated by
-- repeated calls in this single-session SQL suite.
select 'PAYMENT_BANK_VERIFICATION_PASS' result,count(*) assertions from bank_results;
rollback;
