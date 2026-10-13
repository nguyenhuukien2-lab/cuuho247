-- PRIVILEGED DISPOSABLE DATABASE ONLY. Requires Admin foundation/display codes and GD1..GD6C + Admin Payment V1.
-- SET payment.test_mode='local_disposable' on this connection. Everything rolls back.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
do $guard$
begin
  if current_setting('payment.test_mode',true) is distinct from 'local_disposable'
     or not exists(select 1 from pg_catalog.pg_roles where rolname=current_user and (rolsuper or rolbypassrls)) then
    raise exception 'PAYMENT_TEST_REFUSED: privileged local_disposable opt-in required';
  end if;
  if exists(select 1 from auth.users where id::text like 'a1200000-0000-4000-8000-%') then
    raise exception 'PAYMENT_TEST_REFUSED: fixture namespace occupied';
  end if;
end;
$guard$;

create temp table admin_payment_results(label text primary key) on commit drop;
create temp table admin_payment_fixtures(i integer primary key,request_id uuid,payment_id uuid,operation_id uuid) on commit drop;
grant select,insert on pg_temp.admin_payment_results to anon,authenticated;
grant select on pg_temp.admin_payment_fixtures to anon,authenticated;
create function pg_temp.ap_assert(p_label text,p_ok boolean) returns void language plpgsql security invoker as $$
begin
  if p_ok is distinct from true then raise exception 'TEST_FAIL: %',p_label; end if;
  insert into pg_temp.admin_payment_results values(p_label);
end;
$$;
create function pg_temp.ap_error(p_label text,p_sql text,p_state text,p_message text default null)
returns void language plpgsql security invoker as $$
declare s text; m text;
begin
  begin execute p_sql;
  exception when others then get stacked diagnostics s=returned_sqlstate,m=message_text;
  end;
  if s is distinct from p_state or (p_message is not null and m is distinct from p_message) then
    raise exception 'TEST_FAIL: %, expected % %, got % %',p_label,p_state,p_message,s,m;
  end if;
  perform pg_temp.ap_assert(p_label,true);
end;
$$;

select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);
insert into auth.users(id,email) values
 ('a1200000-0000-4000-8000-000000000001','customer-admin-payment@example.invalid'),
 ('a1200000-0000-4000-8000-000000000002','rescuer-admin-payment@example.invalid'),
 ('a1200000-0000-4000-8000-000000000003','finance-admin-payment@example.invalid'),
 ('a1200000-0000-4000-8000-000000000004','normal-admin-payment@example.invalid'),
 ('a1200000-0000-4000-8000-000000000005','operator-admin-payment@example.invalid'),
 ('a1200000-0000-4000-8000-000000000006','super-admin-payment@example.invalid');
update public.customer_profiles
set full_name='Admin payment customer',phone='0900000001'
where user_id='a1200000-0000-4000-8000-000000000001';
insert into public.rescuer_profiles(user_id,full_name,contact_phone,verification_status) values
 ('a1200000-0000-4000-8000-000000000002','Admin payment rescuer','0900000002','approved');
insert into public.rescuer_vehicles(id,rescuer_id,kind,display_name,license_plate,verification_status) values
 ('a1260000-0000-4000-8000-000000000002','a1200000-0000-4000-8000-000000000002',
  'service_motorbike','Admin payment vehicle','APV100','approved');
insert into public.admin_profiles(id,full_name,role,status) values
 ('a1200000-0000-4000-8000-000000000003','Finance fixture','finance','active'),
 ('a1200000-0000-4000-8000-000000000005','Operator fixture','operator','active'),
 ('a1200000-0000-4000-8000-000000000006','Super fixture','super_admin','active');

do $fixtures$
declare i integer; req uuid; assignment uuid; quote uuid; dto jsonb; t timestamptz:=clock_timestamp()-interval '1 minute';
begin
  for i in 1..3 loop
    req:=('a1220000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
    assignment:=('a1230000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
    quote:=('a1240000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
    insert into public.rescue_requests(id,customer_id,client_request_id,vehicle_kind,service_code,
      location_text,location_confirmed,contact_name,contact_phone,status,provider_id,created_at)
    values(req,'a1200000-0000-4000-8000-000000000001',gen_random_uuid(),'motorbike','tire',
      'Admin payment fixture',true,'Admin payment customer','0900000001','in_progress',
      'a1200000-0000-4000-8000-000000000002',t+make_interval(secs=>i));
    insert into public.rescue_request_assignments(id,request_id,rescuer_id,vehicle_id,state,accepted_at,en_route_at,arrived_at,in_progress_at)
    values(assignment,req,'a1200000-0000-4000-8000-000000000002','a1260000-0000-4000-8000-000000000002',
      'in_progress',t,t,t,t);
    insert into public.rescue_quotes(id,assignment_id,request_id,rescuer_id,revision,total_vnd,items)
    values(quote,assignment,req,'a1200000-0000-4000-8000-000000000002',1,100000*i,
      jsonb_build_array(jsonb_build_object('service_code','tire','quantity',1,'unit_price_vnd',100000*i)));
    update public.rescue_request_assignments set state='completed',completed_at=t,current_quote_id=quote,completion_quote_id=quote where id=assignment;
    update public.rescue_requests set status='completed',quoted_price=100000*i where id=req;
    perform set_config('request.jwt.claim.sub','a1200000-0000-4000-8000-000000000001',true);
    dto:=public.customer_prepare_payment(req);
    insert into pg_temp.admin_payment_fixtures values(i,req,(dto->>'payment_id')::uuid,gen_random_uuid());
  end loop;
end;
$fixtures$;
set constraints all immediate;

select set_config('request.jwt.claim.sub','a1200000-0000-4000-8000-000000000001',true);
select public.customer_select_payment_method(request_id,payment_id,'cash',1,operation_id)
  from pg_temp.admin_payment_fixtures where i=1;
select set_config('request.jwt.claim.sub','a1200000-0000-4000-8000-000000000002',true);
select public.rescuer_confirm_cash_received(request_id,payment_id,100000,2,gen_random_uuid())
  from pg_temp.admin_payment_fixtures where i=1;

select set_config('request.jwt.claim.sub','',true);
insert into private.payment_bank_config(bank_bin,bank_code,bank_name,account_number,account_name,enabled,
  verification_enabled,verification_provider,verification_scope)
values('970436','TESTBANK','Admin Payment Test Bank','123456789012','ADMIN PAYMENT BENEFICIARY',true,
  true,'test_only','admin_payment');
select set_config('request.jwt.claim.sub','a1200000-0000-4000-8000-000000000001',true);
select public.customer_select_bank_transfer(request_id,payment_id,1,operation_id)
  from pg_temp.admin_payment_fixtures where i in (2,3) order by i;
select set_config('request.jwt.claim.sub','',true);

create temp table admin_payment_bank_inputs(i integer primary key,n jsonb) on commit drop;
insert into admin_payment_bank_inputs
select f.i,jsonb_build_object('provider','test_only','provider_scope','admin_payment',
  'provider_transaction_id','admin-payment-tx-'||f.i,'provider_event_id','admin-payment-event-'||f.i,
  'delivery_id','admin-payment-delivery-'||f.i,'amount',case when f.i=2 then p.amount_expected::text else '999' end,
  'currency','VND','direction','credit','transfer_reference',case when f.i=2 then s.transfer_content else 'NO-MATCH-REFERENCE' end,
  'occurred_at',to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  'beneficiary_bank_bin',s.bank_bin,'beneficiary_account_number',s.account_number,
  'authentication_verified',true,'signature_verified',false,'authentication_method','token',
  'raw_payload_sha256',encode(sha256(convert_to('admin-payment-input-'||f.i,'UTF8')),'hex'))
from pg_temp.admin_payment_fixtures f join public.payments p on p.id=f.payment_id
join private.payment_bank_intents bi on bi.payment_id=p.id
join private.payment_bank_qr_snapshots s on s.intent_id=bi.id where f.i in (2,3);
select private.process_verified_bank_transaction(n) from admin_payment_bank_inputs order by i;

-- Function shape and ACL: authenticated may invoke, every call still checks the server-side Admin membership.
do $contracts$
declare f text;
begin
  foreach f in array array[
    'public.admin_get_payment_overview(timestamptz,timestamptz,text)',
    'public.admin_list_payments(text,text,text,timestamptz,timestamptz,numeric,numeric,integer,jsonb)',
    'public.admin_get_payment_detail(uuid)',
    'public.admin_list_bank_transactions(text,text,text,text,timestamptz,timestamptz,numeric,numeric,integer,jsonb)'
  ] loop
    perform pg_temp.ap_assert('contract secure definer '||f,(select prosecdef and 'search_path=""'=any(proconfig)
      and prorettype='jsonb'::regtype from pg_catalog.pg_proc where oid=f::regprocedure));
    perform pg_temp.ap_assert('no qualified conditional expression '||f,
      pg_catalog.pg_get_functiondef(f::regprocedure) !~* 'pg_catalog\.(coalesce|nullif|greatest|least)[[:space:]]*\(');
    perform pg_temp.ap_assert('public execute revoked '||f,not exists(select 1
      from pg_catalog.pg_proc p cross join lateral pg_catalog.aclexplode(coalesce(p.proacl,pg_catalog.acldefault('f',p.proowner))) a
      where p.oid=f::regprocedure and a.grantee=0 and a.privilege_type='EXECUTE'));
    perform pg_temp.ap_assert('anon execute revoked '||f,not pg_catalog.has_function_privilege('anon',f,'execute'));
    perform pg_temp.ap_assert('authenticated narrow execute '||f,pg_catalog.has_function_privilege('authenticated',f,'execute'));
  end loop;
end;
$contracts$;

set local role anon;
select pg_temp.ap_error('anon denied',
  $$select public.admin_get_payment_overview(null,null,'day')$$,'42501');
reset role;
select set_config('request.jwt.claim.sub','a1200000-0000-4000-8000-000000000004',true);
set local role authenticated;
select pg_temp.ap_error('normal authenticated denied',
  $$select public.admin_get_payment_overview(null,null,'day')$$,'42501','ADMIN_FORBIDDEN');
select pg_temp.ap_error('normal detail denied',
  $$select public.admin_get_payment_detail((select payment_id from pg_temp.admin_payment_fixtures where i=1))$$,'42501','ADMIN_FORBIDDEN');
select pg_temp.ap_error('normal bank list denied',
  $$select public.admin_list_bank_transactions(null,null,null,null,null,null,null,null,50,null)$$,'42501','ADMIN_FORBIDDEN');
reset role;
select set_config('request.jwt.claim.sub','a1200000-0000-4000-8000-000000000005',true);
set local role authenticated;
select pg_temp.ap_error('operator denied',
  $$select public.admin_list_payments(null,null,null,null,null,null,null,50,null)$$,'42501','ADMIN_FORBIDDEN');
reset role;

select set_config('request.jwt.claim.sub','a1200000-0000-4000-8000-000000000003',true);
set local role authenticated;
create temp table overview_result on commit drop as select public.admin_get_payment_overview(clock_timestamp()-interval '1 hour',clock_timestamp()+interval '1 hour','day') value;
select pg_temp.ap_assert('overview totals and split',(select value->'summary' @> '{"total_payment_count":3,"paid_count":2,"total_paid_amount":"300000","cash_paid_amount":"100000","bank_paid_amount":"200000","awaiting_count":1,"verifying_count":0,"issue_count":1}'::jsonb from overview_result));
select pg_temp.ap_assert('overview chart rows',(select jsonb_array_length(value->'chart')>=1 from overview_result));
select pg_temp.ap_assert('overview recent rows',(select jsonb_array_length(value->'recent_payments')=3 from overview_result));
select pg_temp.ap_assert('overview date range excludes fixtures',((public.admin_get_payment_overview(clock_timestamp()+interval '1 day',clock_timestamp()+interval '2 days','day')->'summary'->>'total_payment_count')::integer=0));

create temp table list_result on commit drop as select public.admin_list_payments('Admin payment customer','cash','paid',clock_timestamp()-interval '1 hour',clock_timestamp()+interval '1 hour',100000,100000,1,null) value;
select pg_temp.ap_assert('list search method status date amount',(select value->'summary'->>'total_count'='1' and value->'rows'->0->>'amount_expected'='100000' from list_result));
create temp table list_page1 on commit drop as select public.admin_list_payments(null,null,null,null,null,null,null,1,null) value;
create temp table list_page2 on commit drop as select public.admin_list_payments(null,null,null,null,null,null,null,1,
  (select value->'next_cursor' from list_page1)) value;
select pg_temp.ap_assert('list pagination first page',(select (value->>'has_more')::boolean and jsonb_array_length(value->'rows')=1 from list_page1));
select pg_temp.ap_assert('list pagination cursor',(select jsonb_array_length(b.value->'rows')=1
  and a.value->'rows'->0->>'payment_id'<>b.value->'rows'->0->>'payment_id' from list_page1 a cross join list_page2 b));
select pg_temp.ap_error('invalid payment method',
  $$select public.admin_list_payments(null,'card',null,null,null,null,null,50,null)$$,'22023','ADMIN_PAYMENT_INVALID_FILTER');
select pg_temp.ap_error('invalid payment status',
  $$select public.admin_list_payments(null,null,'invented',null,null,null,null,50,null)$$,'22023','ADMIN_PAYMENT_INVALID_FILTER');
select pg_temp.ap_error('invalid payment cursor',
  $$select public.admin_list_payments(null,null,null,null,null,null,null,50,'{"id":"bad"}')$$,'22023','ADMIN_PAYMENT_INVALID_CURSOR');

select pg_temp.ap_assert('cash detail and timeline',exists(select 1 from pg_temp.admin_payment_fixtures f where f.i=1
  and public.admin_get_payment_detail(f.payment_id)->'cash'->>'confirmed'='true'
  and jsonb_array_length(public.admin_get_payment_detail(f.payment_id)->'timeline')>=2));
select pg_temp.ap_assert('finance contact redacted',exists(select 1 from pg_temp.admin_payment_fixtures f where f.i=1
  and public.admin_get_payment_detail(f.payment_id)->'customer'->'phone'='null'::jsonb
  and public.admin_get_payment_detail(f.payment_id)->'customer'->'email'='null'::jsonb));
select pg_temp.ap_assert('bank detail safe',exists(select 1 from pg_temp.admin_payment_fixtures f where f.i=2
  and public.admin_get_payment_detail(f.payment_id)->'bank'->>'verification_status'='verified'
  and public.admin_get_payment_detail(f.payment_id)->'bank'->>'masked_account_number' like '%9012'));
select pg_temp.ap_assert('detail not found',public.admin_get_payment_detail('a1290000-0000-4000-8000-000000000099') is null);

create temp table bank_result on commit drop as select public.admin_list_bank_transactions('admin-payment','test_only',null,null,
  clock_timestamp()-interval '1 hour',clock_timestamp()+interval '1 hour',1,300000,1,null) value;
select pg_temp.ap_assert('bank filters and pagination',(select value->'summary'->>'total_count'='2' and (value->>'has_more')::boolean from bank_result));
create temp table bank_page2 on commit drop as select public.admin_list_bank_transactions('admin-payment','test_only',null,null,
  clock_timestamp()-interval '1 hour',clock_timestamp()+interval '1 hour',1,300000,1,(select value->'next_cursor' from bank_result)) value;
select pg_temp.ap_assert('bank pagination cursor',(select jsonb_array_length(b.value->'rows')=1
  and a.value->'rows'->0->>'transaction_id'<>b.value->'rows'->0->>'transaction_id' from bank_result a cross join bank_page2 b));
select pg_temp.ap_assert('bank verified filter',(public.admin_list_bank_transactions(null,'test_only','verified','matched_exact',null,null,null,null,50,null)->'summary'->>'total_count')='1');
select pg_temp.ap_assert('bank unmatched filter',(public.admin_list_bank_transactions(null,'test_only','rejected','unmatched',null,null,null,null,50,null)->'summary'->>'total_count')='1');
select pg_temp.ap_error('invalid bank filter',
  $$select public.admin_list_bank_transactions(null,'BAD!',null,null,null,null,null,null,50,null)$$,'22023','ADMIN_BANK_TRANSACTION_INVALID_FILTER');
select pg_temp.ap_assert('safe bank allowlist',not exists(select 1 from jsonb_array_elements(public.admin_list_bank_transactions(null,null,null,null,null,null,null,null,50,null)->'rows') r
  where r ?| array['raw_payload','headers','webhook_headers','auth_token','token','signature','secret','body_sha256','normalized_sha256','beneficiary_account_number']));
select pg_temp.ap_assert('secret canary absent',strpos(public.admin_list_bank_transactions(null,null,null,null,null,null,null,null,50,null)::text,'ADMIN PAYMENT BENEFICIARY')=0);
select pg_temp.ap_error('authenticated private select denied',$$select * from private.bank_transactions$$,'42501');
select pg_temp.ap_error('authenticated payment update denied',$$update public.payments set amount_expected=1$$,'42501');
reset role;

select set_config('request.jwt.claim.sub','a1200000-0000-4000-8000-000000000006',true);
set local role authenticated;
select pg_temp.ap_assert('super admin allowed and contact visible',exists(select 1 from pg_temp.admin_payment_fixtures f where f.i=1
  and public.admin_get_payment_detail(f.payment_id)->'customer'->>'phone'='0900000001'));
reset role;

select pg_temp.ap_assert('no admin payment mutation RPC',not exists(select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname ~ '^admin_.*(confirm|mark|paid|update|delete|refund|settle).*(cash|bank|payment)|^admin_(confirm|mark|update|delete|refund|settle)'));
select pg_temp.ap_assert('private bank direct grants absent',not pg_catalog.has_table_privilege('anon','private.bank_transactions','select')
  and not pg_catalog.has_table_privilege('authenticated','private.bank_transactions','select'));

select 'ADMIN_PAYMENT_READ_API_REGRESSION_PASS' result,count(*) assertions from pg_temp.admin_payment_results;
rollback;
