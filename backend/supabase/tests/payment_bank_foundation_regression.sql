-- PRIVILEGED DISPOSABLE DATABASE ONLY. GD1..GD4 + GD6A required.
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
  for i in 1..7 loop
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

-- Catalog and ACL, including permissive deployment defaults.
do $catalog$
declare t text; r text; f text;
begin
  foreach t in array array['payment_bank_intents','bank_transactions','payment_webhook_receipts','payment_bank_audit'] loop
    perform pg_temp.bank_assert('RLS no policies '||t,
      (select relrowsecurity from pg_class where oid=('private.'||t)::regclass)
      and not exists(select 1 from pg_policy where polrelid=('private.'||t)::regclass));
    perform pg_temp.bank_assert('PUBLIC no privilege '||t,not exists(select 1 from pg_class c,aclexplode(c.relacl) x
      where c.oid=('private.'||t)::regclass and x.grantee=0));
    foreach r in array array['anon','authenticated','service_role'] loop
      if exists(select 1 from pg_roles where rolname=r) then
        perform pg_temp.bank_assert(r||' no table access '||t,
          not has_table_privilege(r,'private.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'));
      end if;
    end loop;
  end loop;
  foreach f in array array['private.payment_bank_create_intent(uuid,uuid,timestamptz)',
    'private.payment_bank_intent_guard()','private.payment_bank_record_guard()',
    'private.payment_bank_audit_guard()','private.payment_bank_append_audit()'] loop
    perform pg_temp.bank_assert('invoker empty search path '||f,
      (select not prosecdef and 'search_path=""'=any(proconfig) from pg_proc where oid=f::regprocedure));
    foreach r in array array['anon','authenticated','service_role'] loop
      if exists(select 1 from pg_roles where rolname=r) then
        perform pg_temp.bank_assert(r||' no helper access '||f,not has_function_privilege(r,f,'EXECUTE'));
      end if;
    end loop;
    perform pg_temp.bank_assert('PUBLIC no helper access '||f,not exists(select 1 from pg_proc p,aclexplode(p.proacl) x
      where p.oid=f::regprocedure and x.grantee=0));
  end loop;
end;
$catalog$;
select pg_temp.bank_assert('public payments exact safe inventory',
 (select array_agg(attname::text order by attname)=array(select unnest(array[
  'id','payment_code','request_id','assignment_id','customer_id','rescuer_id','quote_id',
  'amount_expected','amount_received','currency','method','status','version',
  'cash_received_by','cash_received_at','paid_at','verified_at','failed_at','cancelled_at','refunded_at',
  'failure_code','cancellation_reason_code','created_at','updated_at']) order by 1)
 from pg_attribute where attrelid='public.payments'::regclass and attnum>0 and not attisdropped));
select pg_temp.bank_assert('no public bank RPC',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('customer_prepare_bank_payment','get_customer_payment_qr','bank_payment_webhook')));
select pg_temp.bank_assert('no bank private or events publication',not exists(select 1 from pg_publication_tables
 where schemaname='private' or (schemaname='public' and tablename='payment_events')));
select pg_temp.bank_assert('public payments still realtime',exists(select 1 from pg_publication_tables
 where pubname='supabase_realtime' and schemaname='public' and tablename='payments'));
select pg_temp.bank_assert('no raw body or secret storage in new tables',not exists(select 1 from information_schema.columns
 where table_schema='private' and table_name in ('payment_bank_intents','bank_transactions','payment_webhook_receipts','payment_bank_audit')
 and column_name ~ '(secret|api_key|raw_body|raw_payload|metadata|service_role)'));

-- Effective SQL permissions, not only ACL introspection. Both owners/strangers blocked.
set local role authenticated;
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000001',true);
do $client$
declare t text;
begin
  foreach t in array array['payment_bank_intents','bank_transactions','payment_webhook_receipts','payment_bank_audit'] loop
    perform pg_temp.bank_error('authenticated SELECT '||t,'select * from private.'||t,'42501');
    perform pg_temp.bank_error('authenticated INSERT '||t,'insert into private.'||t||' default values','42501');
    perform pg_temp.bank_error('authenticated UPDATE '||t,'update private.'||t||' set id=id','42501');
    perform pg_temp.bank_error('authenticated DELETE '||t,'delete from private.'||t,'42501');
  end loop;
end;
$client$;
select pg_temp.bank_error('owner cannot call private creation',
 $$select private.payment_bank_create_intent(payment_id,operation_id,expires_at) from pg_temp.bank_fixtures where i=1$$,'42501');
select pg_temp.bank_error('direct method DML denied', $$update public.payments set method='bank_transfer'$$,'42501');
select pg_temp.bank_error('direct paid DML denied', $$update public.payments set status='paid'$$,'42501');
select pg_temp.bank_error('bank selection remains unavailable',
 $$select public.customer_select_payment_method(request_id,payment_id,'bank_transfer',1,operation_id) from pg_temp.bank_fixtures where i=1$$,
 '22023','METHOD_NOT_IMPLEMENTED');
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000004',true);
select pg_temp.bank_error('unrelated customer cannot create intent',
 $$select private.payment_bank_create_intent(payment_id,operation_id,expires_at) from pg_temp.bank_fixtures where i=1$$,'42501');
select pg_temp.bank_error('unrelated customer getter remains blocked',
 $$select public.customer_get_payment(request_id) from pg_temp.bank_fixtures where i=1$$,'42501','PAYMENT_NOT_ACCESSIBLE');
select pg_temp.bank_assert('unrelated customer SELECT empty',not exists(select 1 from public.payments));
set local role anon;
do $anon$
declare t text;
begin
  foreach t in array array['payment_bank_intents','bank_transactions','payment_webhook_receipts','payment_bank_audit'] loop
    perform pg_temp.bank_error('anon SELECT '||t,'select * from private.'||t,'42501');
    perform pg_temp.bank_error('anon INSERT '||t,'insert into private.'||t||' default values','42501');
    perform pg_temp.bank_error('anon UPDATE '||t,'update private.'||t||' set id=id','42501');
    perform pg_temp.bank_error('anon DELETE '||t,'delete from private.'||t,'42501');
  end loop;
end;
$anon$;
select pg_temp.bank_error('anon helper blocked',
 $$select private.payment_bank_create_intent(payment_id,operation_id,expires_at) from pg_temp.bank_fixtures where i=1$$,'42501');
reset role;
select set_config('request.jwt.claim.sub','',true);

-- Backend path means the trusted database owner here; no service_role grant yet.
update pg_temp.bank_fixtures set intent_id=private.payment_bank_create_intent(payment_id,operation_id,expires_at) where i=1;
select pg_temp.bank_assert('owner internal creation works',exists(select 1 from private.payment_bank_intents i
 join pg_temp.bank_fixtures f on f.intent_id=i.id where f.i=1 and i.status='created' and i.version=1
 and i.provider is null and i.provider_scope is null and i.provider_intent_id is null));
select pg_temp.bank_assert('snapshot derives from payments',exists(select 1 from private.payment_bank_intents i
 join public.payments p on p.id=i.payment_id where i.request_id=p.request_id and i.expected_amount=p.amount_expected and i.currency=p.currency));
select pg_temp.bank_assert('reference server generated',
 (select reference ~ '^BK-[0-9A-F]{32}$' from private.payment_bank_intents limit 1));
select pg_temp.bank_assert('same operation returns same intent',
 (select private.payment_bank_create_intent(payment_id,operation_id,expires_at)=intent_id from pg_temp.bank_fixtures where i=1));
select pg_temp.bank_assert('replay creates no audit duplicate',(select count(*)=1 from private.payment_bank_audit));
select pg_temp.bank_error('same key changed payment',
 $$select private.payment_bank_create_intent(f2.payment_id,f1.operation_id,f1.expires_at)
 from pg_temp.bank_fixtures f1,pg_temp.bank_fixtures f2 where f1.i=1 and f2.i=2$$,'22023','IDEMPOTENCY_CONFLICT');
select pg_temp.bank_error('same key changed expiry',
 $$select private.payment_bank_create_intent(payment_id,operation_id,expires_at+interval '1 second') from pg_temp.bank_fixtures where i=1$$,
 '22023','IDEMPOTENCY_CONFLICT');
select pg_temp.bank_error('new key cannot create second active intent',
 $$select private.payment_bank_create_intent(payment_id,gen_random_uuid(),expires_at) from pg_temp.bank_fixtures where i=1$$,
 'P0001','BANK_INTENT_ALREADY_ACTIVE');
select pg_temp.bank_error('unique index independently blocks second active intent',
 $$insert into private.payment_bank_intents(payment_id,operation_id,expires_at)
 select payment_id,gen_random_uuid(),expires_at from pg_temp.bank_fixtures where i=1$$,'23505');
select pg_temp.bank_error('supplied duplicate reference rejected',
 $$insert into private.payment_bank_intents(payment_id,operation_id,expires_at,reference)
 select f.payment_id,f.operation_id,f.expires_at,i.reference from pg_temp.bank_fixtures f,private.payment_bank_intents i where f.i=2$$,
 '23514','BANK_REFERENCE_SERVER_ASSIGNED');
select pg_temp.bank_assert('reference has independent unique constraint',exists(select 1 from pg_constraint
 where conrelid='private.payment_bank_intents'::regclass and contype='u'
 and conkey=array[(select attnum from pg_attribute where attrelid='private.payment_bank_intents'::regclass and attname='reference')]::smallint[]));
select pg_temp.bank_error('mismatched amount blocked',
 $$insert into private.payment_bank_intents(payment_id,operation_id,expires_at,expected_amount)
 select payment_id,operation_id,expires_at,1 from pg_temp.bank_fixtures where i=2$$,'23514','BANK_INTENT_SNAPSHOT_MISMATCH');
select pg_temp.bank_error('mismatched request blocked',
 $$insert into private.payment_bank_intents(payment_id,operation_id,expires_at,request_id)
 select payment_id,operation_id,expires_at,gen_random_uuid() from pg_temp.bank_fixtures where i=2$$,'23514','BANK_INTENT_SNAPSHOT_MISMATCH');
select pg_temp.bank_error('mismatched currency blocked',
 $$insert into private.payment_bank_intents(payment_id,operation_id,expires_at,currency)
 select payment_id,operation_id,expires_at,'USD' from pg_temp.bank_fixtures where i=2$$,'23514','BANK_INTENT_SNAPSHOT_MISMATCH');
select pg_temp.bank_error('missing payment blocked',
 $$select private.payment_bank_create_intent(gen_random_uuid(),gen_random_uuid(),clock_timestamp()+interval '1 hour')$$,
 '23514','BANK_PAYMENT_NOT_ELIGIBLE');
select pg_temp.bank_error('missing operation blocked',
 $$select private.payment_bank_create_intent(payment_id,null,expires_at) from pg_temp.bank_fixtures where i=2$$,
 '22023','IDEMPOTENCY_KEY_REQUIRED');
select pg_temp.bank_error('expired new intent blocked',
 $$select private.payment_bank_create_intent(payment_id,operation_id,clock_timestamp()-interval '1 second') from pg_temp.bank_fixtures where i=2$$,
 '23514','BANK_INTENT_EXPIRY_INVALID');
select pg_temp.bank_error('infinite expiry blocked',
 $$select private.payment_bank_create_intent(payment_id,operation_id,'infinity') from pg_temp.bank_fixtures where i=2$$,
 '23514','BANK_INTENT_EXPIRY_INVALID');

select pg_temp.bank_error('amount snapshot immutable', $$update private.payment_bank_intents set expected_amount=1$$,'23514','BANK_INTENT_SNAPSHOT_IMMUTABLE');
select pg_temp.bank_error('reference immutable', $$update private.payment_bank_intents set reference='BK-00000000000000000000000000000000'$$,'23514','BANK_INTENT_SNAPSHOT_IMMUTABLE');
select pg_temp.bank_error('expiry cannot silently extend', $$update private.payment_bank_intents set expires_at=expires_at+interval '1 hour'$$,'23514','BANK_INTENT_SNAPSHOT_IMMUTABLE');
select pg_temp.bank_error('provider cannot attach yet', $$update private.payment_bank_intents set provider='test_source',provider_scope='test'$$,'23514','BANK_INTENT_SNAPSHOT_IMMUTABLE');
select pg_temp.bank_error('ready blocked', $$update private.payment_bank_intents set status='ready',version=version+1$$,'23514','BANK_INTENT_TRANSITION_NOT_ENABLED');
select pg_temp.bank_error('matched blocked', $$update private.payment_bank_intents set status='matched',version=version+1$$,'23514','BANK_INTENT_TRANSITION_NOT_ENABLED');
select pg_temp.bank_error('verified blocked', $$update private.payment_bank_intents set status='verified',version=version+1$$,'23514','BANK_INTENT_TRANSITION_NOT_ENABLED');
select pg_temp.bank_error('early expiry blocked', $$update private.payment_bank_intents set status='expired',version=version+1$$,'23514','BANK_INTENT_TRANSITION_NOT_ENABLED');
select pg_temp.bank_error('skipped version blocked', $$update private.payment_bank_intents set status='cancelled',version=version+2$$,'23514','BANK_INTENT_TRANSITION_NOT_ENABLED');
update private.payment_bank_intents set updated_at='2000-01-01';
select pg_temp.bank_assert('no-op has no new audit',(select count(*)=1 from private.payment_bank_audit));
update private.payment_bank_intents set status='cancelled',version=version+1;
select pg_temp.bank_assert('cancellation audited',(select count(*)=1 from private.payment_bank_audit
 where old_status='created' and new_status='cancelled' and resource_version=2));
select pg_temp.bank_error('terminal cannot reopen', $$update private.payment_bank_intents set status='created',version=version+1$$,'23514','BANK_INTENT_TRANSITION_NOT_ENABLED');
select pg_temp.bank_assert('terminal operation replay never creates again',
 (select private.payment_bank_create_intent(payment_id,operation_id,expires_at)=intent_id from pg_temp.bank_fixtures where i=1));
select private.payment_bank_create_intent(payment_id,gen_random_uuid(),expires_at) from pg_temp.bank_fixtures where i=1;
select pg_temp.bank_assert('new operation after closure gets new permanent reference',
 (select count(*)=2 and count(distinct reference)=2 from private.payment_bank_intents));

-- Atomic audit failure must roll back creation. Test-only constraint is rolled back.
do $atomic$
begin
  begin
    alter table private.payment_bank_audit add constraint synthetic_audit_failure check(false) not valid;
    perform pg_temp.bank_error('audit failure rejects entire creation',
      'select private.payment_bank_create_intent(payment_id,operation_id,expires_at) from pg_temp.bank_fixtures where i=2','23514');
    perform pg_temp.bank_assert('no orphan intent after audit failure',not exists(select 1 from private.payment_bank_intents
      where payment_id=(select payment_id from pg_temp.bank_fixtures where i=2)));
    alter table private.payment_bank_audit drop constraint synthetic_audit_failure;
  end;
end;
$atomic$;

-- Synthetic source names are fixtures only. No provider configuration is seeded.
insert into private.payment_webhook_receipts(id,provider,provider_scope,delivery_id,event_id,body_sha256,signature_verified,received_at)
 values('97000000-0000-4000-8000-000000000001','test_source','test_account','delivery-1','event-1',repeat('a',64),false,'2000-01-01'),
 ('97000000-0000-4000-8000-000000000002','test_source','test_account','delivery-2','event-2',repeat('b',64),true,'2000-01-01');
select pg_temp.bank_assert('receipt time server assigned',
 (select bool_and(received_at>'2000-01-02'::timestamptz and received_at=updated_at) from private.payment_webhook_receipts));
select pg_temp.bank_error('delivery replay unique',
 $$insert into private.payment_webhook_receipts(provider,provider_scope,delivery_id,body_sha256)
 values('test_source','test_account','delivery-1',repeat('a',64))$$,'23505');
select pg_temp.bank_error('event replay different delivery unique',
 $$insert into private.payment_webhook_receipts(provider,provider_scope,delivery_id,event_id,body_sha256)
 values('test_source','test_account','delivery-3','event-1',repeat('a',64))$$,'23505');
select pg_temp.bank_error('body hash not replaceable', $$update private.payment_webhook_receipts set body_sha256=repeat('c',64)$$,'23514','BANK_RECORD_IMMUTABLE');
select pg_temp.bank_error('signature cannot elevate on replay', $$update private.payment_webhook_receipts set signature_verified=true where not signature_verified$$,'23514','BANK_RECORD_IMMUTABLE');
select pg_temp.bank_error('processed disabled', $$update private.payment_webhook_receipts set status='processed',version=version+1$$,'23514','BANK_PROCESSING_NOT_ENABLED');
select pg_temp.bank_error('raw body cannot be written', $$insert into private.payment_webhook_receipts(raw_body) values('{}')$$,'42703');
select pg_temp.bank_error('unverified receipt cannot feed transaction',
 $$insert into private.bank_transactions(provider,provider_scope,external_transaction_id,receipt_id,amount,currency,direction)
 values('test_source','test_account','tx-bad','97000000-0000-4000-8000-000000000001',100000,'VND','credit')$$,
 '23514','BANK_RECEIPT_NOT_VERIFIED');
select pg_temp.bank_error('receipt provider binding enforced',
 $$insert into private.bank_transactions(provider,provider_scope,external_transaction_id,receipt_id,amount,currency,direction)
 values('different_test_source','test_account','tx-bad','97000000-0000-4000-8000-000000000002',100000,'VND','credit')$$,
 '23514','BANK_RECEIPT_NOT_VERIFIED');
insert into private.bank_transactions(provider,provider_scope,external_transaction_id,receipt_id,amount,currency,direction,transfer_reference)
 select 'test_source','test_account','tx-1','97000000-0000-4000-8000-000000000002',expected_amount,currency,'credit',reference
 from private.payment_bank_intents where status='created';
select pg_temp.bank_assert('verified signature plus exact fields still unverified and unmatched',
 (select bool_and(status='unverified' and matched_payment_id is null and matched_intent_id is null) from private.bank_transactions));
select pg_temp.bank_error('external transaction replay unique',
 $$insert into private.bank_transactions(provider,provider_scope,external_transaction_id,amount,currency,direction)
 values('test_source','test_account','tx-1',100000,'VND','credit')$$,'23505');
insert into private.bank_transactions(provider,provider_scope,external_transaction_id,amount,currency,direction)
 values('other_test_source','test_account','tx-1',1,'USD','debit'),
 ('test_source','other_test_account','tx-1',1,'VND','credit');
select pg_temp.bank_assert('provider and account identities independent; polling needs no webhook',
 (select count(*)=3 and count(*) filter(where receipt_id is null)=2 from private.bank_transactions));
select pg_temp.bank_error('transaction amount immutable', $$update private.bank_transactions set amount=1$$,'23514','BANK_RECORD_IMMUTABLE');
select pg_temp.bank_error('transaction verification blocked', $$update private.bank_transactions set status='verified',version=version+1$$,'23514','BANK_VERIFICATION_NOT_ENABLED');
select pg_temp.bank_error('transaction match blocked', $$update private.bank_transactions set status='matched',version=version+1$$,'23514','BANK_VERIFICATION_NOT_ENABLED');
select pg_temp.bank_error('supplied match binding blocked',
 $$update private.bank_transactions set matched_payment_id=(select payment_id from pg_temp.bank_fixtures where i=1)$$,'23514','BANK_RECORD_IMMUTABLE');
update private.payment_webhook_receipts set status='failed',version=version+1 where delivery_id='delivery-1';
update private.payment_webhook_receipts set status='received',version=version+1 where delivery_id='delivery-1';
update private.bank_transactions set status='rejected',version=version+1 where provider='other_test_source';
select pg_temp.bank_assert('receipt retry audit retains each version',(select count(*)=3 from private.payment_bank_audit
 where receipt_id='97000000-0000-4000-8000-000000000001'));
select pg_temp.bank_assert('transaction rejection audit',(select count(*)=1 from private.payment_bank_audit where new_status='rejected'));

do $immutability$
declare t text;
begin
  foreach t in array array['payment_bank_intents','bank_transactions','payment_webhook_receipts','payment_bank_audit'] loop
    perform pg_temp.bank_error('privileged DELETE forbidden '||t,'delete from private.'||t,'23514');
    perform pg_temp.bank_error('privileged TRUNCATE forbidden '||t,'truncate private.'||t||' cascade','23514');
  end loop;
end;
$immutability$;
select pg_temp.bank_error('audit cannot update', $$update private.payment_bank_audit set new_status='verified'$$,'23514','BANK_AUDIT_IMMUTABLE');
select pg_temp.bank_error('audit cannot forge direct append',
 $$insert into private.payment_bank_audit(intent_id,new_status,resource_version)
 select intent_id,'verified',999 from pg_temp.bank_fixtures where i=1$$,'23514','BANK_AUDIT_TRIGGER_ONLY');
select pg_temp.bank_assert('bank operations leave entire public payment rows unchanged',not exists(
 select 1 from public.payments p join pg_temp.bank_fixtures f on f.payment_id=p.id where to_jsonb(p) is distinct from f.original));
select pg_temp.bank_assert('no public bank events or auto-paid',
 (select count(*)=7 and bool_and(event_type='payment_created') from public.payment_events)
 and not exists(select 1 from public.payments where status='paid'));

-- CASH on a payment with a private inert reservation is exactly the existing flow.
set local role authenticated;
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000001',true);
select pg_temp.bank_assert('cash selection unchanged with inert bank reservation',
 (select public.customer_select_payment_method(request_id,payment_id,'cash',1,gen_random_uuid())->>'changed'='true'
 from pg_temp.bank_fixtures where i=1));
select pg_temp.bank_assert('cash selection exact replay unchanged',
 (select public.customer_select_payment_method(request_id,payment_id,'cash',2,operation_id)->>'changed'='false'
 from pg_temp.bank_fixtures where i=1));
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000003',true);
select pg_temp.bank_error('cash amount mismatch still rejected',
 $$select public.rescuer_confirm_cash_received(request_id,payment_id,1,2,operation_id) from pg_temp.bank_fixtures where i=1$$,
 'P0001','PAYMENT_AMOUNT_MISMATCH');
select pg_temp.bank_assert('cash confirm unchanged',
 (select public.rescuer_confirm_cash_received(request_id,payment_id,100000,2,operation_id)->>'changed'='true'
 from pg_temp.bank_fixtures where i=1));
select pg_temp.bank_assert('cash exact retry unchanged',
 (select public.rescuer_confirm_cash_received(request_id,payment_id,100000,2,operation_id)->>'changed'='false'
 from pg_temp.bank_fixtures where i=1));
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000001',true);
select pg_temp.bank_assert('customer observes real cash paid',
 (select public.customer_get_payment(request_id)->>'status'='paid' from pg_temp.bank_fixtures where i=1));
reset role;
select pg_temp.bank_assert('one cash event and zero bank verified events',
 (select count(*) filter(where event_type='cash_received')=1 and count(*) filter(where event_type='bank_payment_verified')=0 from public.payment_events));

-- Invalid public snapshots are injected only in rollback subtransactions.
do $invalid$
declare s text; amount bigint; curr text; req uuid;
begin
  foreach s in array array['awaiting_payment','verifying','paid','failed','cancelled','refunded'] loop
    begin
      alter table public.payments disable trigger payment_core_guard;
      update public.payments set status=s,method='bank_transfer' where id=(select payment_id from pg_temp.bank_fixtures where i=3);
      alter table public.payments enable trigger payment_core_guard;
      perform pg_temp.bank_error('synthetic state rejected '||s,
       'select private.payment_bank_create_intent(payment_id,operation_id,expires_at) from pg_temp.bank_fixtures where i=3',
       '23514','BANK_PAYMENT_NOT_ELIGIBLE');
      raise exception sqlstate 'Z6001';
    exception when sqlstate 'Z6001' then null;
    end;
    perform pg_temp.bank_assert('invalid state subtransaction passed '||s,true);
  end loop;
  begin
    alter table public.payments disable trigger payment_core_guard;
    update public.payments set amount_expected=0 where id=(select payment_id from pg_temp.bank_fixtures where i=3);
    alter table public.payments enable trigger payment_core_guard;
    perform pg_temp.bank_error('zero amount cannot reserve',
      'select private.payment_bank_create_intent(payment_id,operation_id,expires_at) from pg_temp.bank_fixtures where i=3',
      '23514','BANK_PAYMENT_NOT_ELIGIBLE');
    raise exception sqlstate 'Z6001';
  exception when sqlstate 'Z6001' then null;
  end;
  perform pg_temp.bank_assert('zero amount fault injection passed',true);
end;
$invalid$;
select pg_temp.bank_assert('payment guard remains enabled',exists(select 1 from pg_trigger
 where tgrelid='public.payments'::regclass and tgname='payment_core_guard' and tgenabled='O'));
select pg_temp.bank_assert('private tables still unpublished',not exists(select 1 from pg_publication_tables where schemaname='private'));
set constraints all immediate;
select 'PAYMENT_BANK_FOUNDATION_PASS' as result,count(*) as assertions from pg_temp.bank_results;
rollback;
