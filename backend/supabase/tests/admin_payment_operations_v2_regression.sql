-- PRIVILEGED DISPOSABLE DATABASE ONLY. Requires the full payment + Admin migration chain.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
do $guard$
begin
  if current_setting('payment.test_mode',true) is distinct from 'local_disposable'
     or not exists(select 1 from pg_catalog.pg_roles where rolname=current_user and (rolsuper or rolbypassrls)) then
    raise exception 'PAYMENT_TEST_REFUSED: privileged local_disposable opt-in required';
  end if;
  if exists(select 1 from auth.users where id::text like 'a1400000-0000-4000-8000-%') then
    raise exception 'PAYMENT_TEST_REFUSED: fixture namespace occupied';
  end if;
end;
$guard$;

create temp table payment_ops_results(label text primary key) on commit drop;
create temp table payment_ops_fixture(payment_id uuid,request_id uuid,transaction_id uuid,
  payment_version bigint,transaction_version bigint) on commit drop;
grant select,insert on pg_temp.payment_ops_results to anon,authenticated;
grant select on pg_temp.payment_ops_fixture to anon,authenticated;
create function pg_temp.po_assert(p_label text,p_ok boolean) returns void language plpgsql security invoker as $$
begin
  if p_ok is distinct from true then raise exception 'TEST_FAIL: %',p_label; end if;
  insert into pg_temp.payment_ops_results values(p_label);
end;
$$;
create function pg_temp.po_error(p_label text,p_sql text,p_state text,p_message text default null)
returns void language plpgsql security invoker as $$
declare s text; m text;
begin
  begin execute p_sql;
  exception when others then get stacked diagnostics s=returned_sqlstate,m=message_text;
  end;
  if s is distinct from p_state or (p_message is not null and m is distinct from p_message) then
    raise exception 'TEST_FAIL: %, expected % %, got % %',p_label,p_state,p_message,s,m;
  end if;
  perform pg_temp.po_assert(p_label,true);
end;
$$;

select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);
insert into auth.users(id,email) values
 ('a1400000-0000-4000-8000-000000000001','ops-customer@example.invalid'),
 ('a1400000-0000-4000-8000-000000000002','ops-rescuer@example.invalid'),
 ('a1400000-0000-4000-8000-000000000003','ops-finance-one@example.invalid'),
 ('a1400000-0000-4000-8000-000000000004','ops-finance-two@example.invalid'),
 ('a1400000-0000-4000-8000-000000000005','ops-normal@example.invalid');
update public.customer_profiles set full_name='Payment Ops Customer'
  where user_id='a1400000-0000-4000-8000-000000000001';
insert into public.rescuer_profiles(user_id,full_name,contact_phone,verification_status) values
 ('a1400000-0000-4000-8000-000000000002','Payment Ops Rescuer','0900000102','approved');
insert into public.rescuer_vehicles(id,rescuer_id,kind,display_name,license_plate,verification_status) values
 ('a1460000-0000-4000-8000-000000000002','a1400000-0000-4000-8000-000000000002',
  'service_motorbike','Ops vehicle','OPS100','approved');
insert into public.admin_profiles(id,full_name,role,status) values
 ('a1400000-0000-4000-8000-000000000003','Ops Finance One','finance','active'),
 ('a1400000-0000-4000-8000-000000000004','Ops Finance Two','finance','active');

do $fixture$
declare req uuid:='a1420000-0000-4000-8000-000000000001';
  assignment uuid:='a1430000-0000-4000-8000-000000000001';
  quote uuid:='a1440000-0000-4000-8000-000000000001'; dto jsonb; payment uuid;
  intent uuid; snap private.payment_bank_qr_snapshots; receipt uuid; tx uuid;
  digest text:=encode(sha256(convert_to('payment-ops-late-fixture','UTF8')),'hex');
begin
  insert into public.rescue_requests(id,customer_id,client_request_id,vehicle_kind,service_code,
    location_text,location_confirmed,contact_name,contact_phone,status,provider_id)
  values(req,'a1400000-0000-4000-8000-000000000001',gen_random_uuid(),'motorbike','tire',
    'Payment operations fixture',true,'Payment Ops Customer','0900000101','in_progress',
    'a1400000-0000-4000-8000-000000000002');
  insert into public.rescue_request_assignments(id,request_id,rescuer_id,vehicle_id,state,accepted_at,en_route_at,arrived_at,in_progress_at)
  values(assignment,req,'a1400000-0000-4000-8000-000000000002','a1460000-0000-4000-8000-000000000002',
    'in_progress',clock_timestamp(),clock_timestamp(),clock_timestamp(),clock_timestamp());
  insert into public.rescue_quotes(id,assignment_id,request_id,rescuer_id,revision,total_vnd,items)
  values(quote,assignment,req,'a1400000-0000-4000-8000-000000000002',1,120000,
    jsonb_build_array(jsonb_build_object('service_code','tire','quantity',1,'unit_price_vnd',120000)));
  update public.rescue_request_assignments set state='completed',completed_at=clock_timestamp(),
    current_quote_id=quote,completion_quote_id=quote where id=assignment;
  update public.rescue_requests set status='completed',quoted_price=120000 where id=req;
  perform set_config('request.jwt.claim.sub','a1400000-0000-4000-8000-000000000001',true);
  dto:=public.customer_prepare_payment(req); payment:=(dto->>'payment_id')::uuid;
  perform set_config('request.jwt.claim.sub','',true);
  insert into private.payment_bank_config(bank_bin,bank_code,bank_name,account_number,account_name,enabled,
    verification_enabled,verification_provider,verification_scope,require_beneficiary)
  values('970436','TESTBANK','Operations Test Bank','123456789012','OPS BENEFICIARY',true,
    true,'test_only','payment_ops',true);
  perform set_config('request.jwt.claim.sub','a1400000-0000-4000-8000-000000000001',true);
  dto:=public.customer_select_bank_transfer(req,payment,1,gen_random_uuid());
  perform set_config('request.jwt.claim.sub','',true);
  select i.id into intent from private.payment_bank_intents i where i.payment_id=payment;
  select s.* into snap from private.payment_bank_qr_snapshots s where s.intent_id=intent;
  insert into private.payment_webhook_receipts(provider,provider_scope,delivery_id,event_id,body_sha256,
    signature_verified,status,authentication_verified,authentication_method,normalized_sha256,result_code)
  values('test_only','payment_ops','ops-delivery-1','ops-event-1',digest,true,'received',true,'signature',digest,null)
  returning id into receipt;
  insert into private.bank_transactions(provider,provider_scope,external_transaction_id,receipt_id,amount,
    currency,direction,transfer_reference,occurred_at,status,beneficiary_bank_bin,
    beneficiary_account_number,normalized_sha256)
  values('test_only','payment_ops','ops-late-transaction-1',receipt,120000,'VND','credit',
    snap.transfer_content,clock_timestamp(),'unverified',snap.bank_bin,snap.account_number,digest)
  returning id into tx;
  update private.bank_transactions set status='rejected',rejection_code='intent_expired',version=version+1 where id=tx;
  insert into pg_temp.payment_ops_fixture
    select payment,req,tx,p.version,t.version from public.payments p cross join private.bank_transactions t
    where p.id=payment and t.id=tx;
end;
$fixture$;
set constraints all immediate;

-- Contract, ACL, fixed search_path and absence of a payment settlement writer.
do $contracts$
declare f text;
begin
  foreach f in array array[
    'public.admin_list_payment_reconciliation(text,text,timestamptz,timestamptz,integer,jsonb)',
    'public.admin_get_payment_operations_report(timestamptz,timestamptz)',
    'public.admin_list_payment_refunds(uuid,text,timestamptz,timestamptz,integer)',
    'public.admin_get_payment_operations_timeline(uuid)',
    'public.admin_resolve_late_payment(uuid,bigint,bigint,text,text,uuid)',
    'public.admin_request_payment_refund(uuid,uuid,bigint,text,bigint,uuid)',
    'public.admin_transition_payment_refund(uuid,bigint,text,text,text,uuid)'
  ] loop
    perform pg_temp.po_assert('secure definer fixed path '||f,(select prosecdef
      and 'search_path=pg_catalog, public, private'=any(proconfig)
      from pg_catalog.pg_proc where oid=f::regprocedure));
    perform pg_temp.po_assert('public denied '||f,not pg_catalog.has_function_privilege('public',f,'execute'));
    perform pg_temp.po_assert('anon denied '||f,not pg_catalog.has_function_privilege('anon',f,'execute'));
    perform pg_temp.po_assert('service role denied '||f,not pg_catalog.has_function_privilege('service_role',f,'execute'));
    perform pg_temp.po_assert('authenticated invoke '||f,pg_catalog.has_function_privilege('authenticated',f,'execute'));
  end loop;
  foreach f in array array[
    'private.payment_operations_immutable_guard()',
    'private.payment_admin_receipt_guard()',
    'private.payment_reconciliation_guard()',
    'private.payment_refund_guard()'
  ] loop
    perform pg_temp.po_assert('private helper anon denied '||f,
      not pg_catalog.has_function_privilege('anon',f,'execute'));
    perform pg_temp.po_assert('private helper authenticated denied '||f,
      not pg_catalog.has_function_privilege('authenticated',f,'execute'));
    perform pg_temp.po_assert('private helper service role denied '||f,
      not pg_catalog.has_function_privilege('service_role',f,'execute'));
  end loop;
end;
$contracts$;
select pg_temp.po_assert('new RPCs cannot update payments',not exists(
  select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in ('admin_resolve_late_payment','admin_request_payment_refund','admin_transition_payment_refund')
    and pg_catalog.pg_get_functiondef(p.oid) ~* 'update[[:space:]]+public[.]payments'));
select pg_temp.po_assert('reconciliation race has lock plus unique winner',
  pg_catalog.pg_get_functiondef('public.admin_resolve_late_payment(uuid,bigint,bigint,text,text,uuid)'::regprocedure) ~* 'for update'
  and exists(select 1 from pg_catalog.pg_index i where i.indrelid='private.payment_reconciliation_cases'::regclass
    and i.indisunique and pg_catalog.pg_get_indexdef(i.indexrelid) like '%(bank_transaction_id)%'));
select pg_temp.po_assert('operation replay serialized per actor and key',
  pg_catalog.pg_get_functiondef('public.admin_resolve_late_payment(uuid,bigint,bigint,text,text,uuid)'::regprocedure) ~ 'pg_advisory_xact_lock'
  and exists(select 1 from pg_catalog.pg_constraint c where c.conrelid='private.payment_admin_operation_receipts'::regclass
    and c.contype='p'));
select pg_temp.po_assert('private direct grants absent',not pg_catalog.has_table_privilege('authenticated','private.payment_refunds','select,insert,update,delete')
  and not pg_catalog.has_table_privilege('service_role','private.payment_refunds','select,insert,update,delete')
  and not pg_catalog.has_table_privilege('authenticated','private.payment_reconciliation_cases','select,insert,update,delete'));

set local role anon;
select pg_temp.po_error('anon report denied',$$select public.admin_get_payment_operations_report(null,null)$$,'42501');
reset role;

-- The shared authenticated database role may invoke Admin RPCs, but each
-- customer/rescuer/non-admin principal must fail the server-side membership guard.
select set_config('request.jwt.claim.sub','a1400000-0000-4000-8000-000000000001',true);
set local role authenticated;
select pg_temp.po_error('customer admin read denied',
  $$select public.admin_list_payment_reconciliation(null,null,null,null,50,null)$$,'42501','ADMIN_FORBIDDEN');
select pg_temp.po_error('customer reconciliation mutation denied',
  $$select public.admin_resolve_late_payment(null,null,null,null,null,null)$$,'42501','ADMIN_FORBIDDEN');
select pg_temp.po_error('customer refund mutation denied',
  $$select public.admin_request_payment_refund(null,null,null,null,null,null)$$,'42501','ADMIN_FORBIDDEN');
select pg_temp.po_error('customer payment write remains denied',
  $$update public.payments set status='paid'$$,'42501');
reset role;

select set_config('request.jwt.claim.sub','a1400000-0000-4000-8000-000000000002',true);
set local role authenticated;
select pg_temp.po_error('rescuer admin read denied',
  $$select public.admin_list_payment_reconciliation(null,null,null,null,50,null)$$,'42501','ADMIN_FORBIDDEN');
select pg_temp.po_error('rescuer reconciliation mutation denied',
  $$select public.admin_resolve_late_payment(null,null,null,null,null,null)$$,'42501','ADMIN_FORBIDDEN');
select pg_temp.po_error('rescuer refund mutation denied',
  $$select public.admin_request_payment_refund(null,null,null,null,null,null)$$,'42501','ADMIN_FORBIDDEN');
select pg_temp.po_error('rescuer payment write remains denied',
  $$update public.payments set status='paid'$$,'42501');
reset role;

select set_config('request.jwt.claim.sub','a1400000-0000-4000-8000-000000000005',true);
set local role authenticated;
select pg_temp.po_error('normal user denied',$$select public.admin_list_payment_reconciliation(null,null,null,null,50,null)$$,'42501','ADMIN_FORBIDDEN');
select pg_temp.po_error('normal user reconciliation mutation denied',
  $$select public.admin_resolve_late_payment(null,null,null,null,null,null)$$,'42501','ADMIN_FORBIDDEN');
select pg_temp.po_error('normal user refund mutation denied',
  $$select public.admin_request_payment_refund(null,null,null,null,null,null)$$,'42501','ADMIN_FORBIDDEN');
select pg_temp.po_error('frontend direct refund DML denied',$$insert into private.payment_refunds(payment_id,source_kind,amount,currency,reason_code,requested_by)
  select payment_id,'paid_payment',1,'VND','fake','a1400000-0000-4000-8000-000000000005' from pg_temp.payment_ops_fixture$$,'42501');
reset role;

select set_config('request.jwt.claim.sub','a1400000-0000-4000-8000-000000000003',true);
set local role authenticated;
select pg_temp.po_error('admin frontend direct reconciliation DML denied',
  $$delete from private.payment_reconciliation_cases$$,'42501');
select pg_temp.po_error('admin frontend direct refund DML denied',
  $$delete from private.payment_refunds$$,'42501');
select pg_temp.po_error('admin frontend direct bank transaction DML denied',
  $$update private.bank_transactions set status=status$$,'42501');
select pg_temp.po_assert('rejected queue exposes safe evidence',exists(
  select 1 from pg_temp.payment_ops_fixture f where
    public.admin_list_payment_reconciliation(null,'pending',null,null,50,null)->'rows'->0->>'transaction_id'=f.transaction_id::text
    and public.admin_list_payment_reconciliation(null,'pending',null,null,50,null)->'rows'->0->>'rejection_code'='intent_expired'
    and public.admin_list_payment_reconciliation(null,'pending',null,null,50,null)->'rows'->0->'receipt'->>'authentication_verified'='true'));
select pg_temp.po_assert('reconciliation response excludes secrets',not (public.admin_list_payment_reconciliation(null,null,null,null,50,null)->'rows'->0)
  ?| array['beneficiary_account_number','body_sha256','normalized_sha256','signature','raw_payload','headers']);
select pg_temp.po_error('stale transaction reconciliation blocked',format(
  'select public.admin_resolve_late_payment(%L::uuid,1,null,%L,%L,%L::uuid)',
  (select transaction_id from pg_temp.payment_ops_fixture),'refund_required','customer_return_required',gen_random_uuid()),'40001','STALE_VERSION');

create temp table resolved on commit drop as
select public.admin_resolve_late_payment(f.transaction_id,f.transaction_version,null,
  'refund_required','customer_return_required','a1480000-0000-4000-8000-000000000001') value
from pg_temp.payment_ops_fixture f;
select pg_temp.po_assert('late payment resolved without settlement',(select value->>'status'='refund_required' from resolved));
select pg_temp.po_assert('late resolution leaves payment unchanged',exists(select 1 from pg_temp.payment_ops_fixture f
  where public.admin_get_payment_detail(f.payment_id)->'payment'->>'status'='awaiting_payment'
    and public.admin_get_payment_detail(f.payment_id)->'payment'->'paid_at'='null'::jsonb));
select pg_temp.po_assert('late resolution replay idempotent',exists(select 1 from resolved r cross join pg_temp.payment_ops_fixture f
  where public.admin_resolve_late_payment(f.transaction_id,f.transaction_version,null,
    'refund_required','customer_return_required','a1480000-0000-4000-8000-000000000001')=r.value)
  and jsonb_array_length(public.admin_list_payment_reconciliation(null,'refund_required',null,null,50,null)->'rows')=1);
select pg_temp.po_error('reconciliation operation conflict',format(
  'select public.admin_resolve_late_payment(%L::uuid,%s,null,%L,%L,%L::uuid)',
  (select transaction_id from pg_temp.payment_ops_fixture),(select transaction_version from pg_temp.payment_ops_fixture),
  'dismissed','not_customer_payment','a1480000-0000-4000-8000-000000000001'),'22023','IDEMPOTENCY_CONFLICT');

create temp table requested on commit drop as
select public.admin_request_payment_refund(f.payment_id,f.transaction_id,120000,'late_payment_return',
  f.payment_version,'a1480000-0000-4000-8000-000000000002') value from pg_temp.payment_ops_fixture f;
select pg_temp.po_assert('refund request replay idempotent',exists(select 1 from requested r cross join pg_temp.payment_ops_fixture f
  where public.admin_request_payment_refund(f.payment_id,f.transaction_id,120000,'late_payment_return',
    f.payment_version,'a1480000-0000-4000-8000-000000000002')=r.value)
  and jsonb_array_length(public.admin_list_payment_refunds(null,null,null,null,100)->'rows')=1);
select pg_temp.po_error('refund over source amount blocked',format(
  'select public.admin_request_payment_refund(%L::uuid,%L::uuid,1,%L,%s,%L::uuid)',
  (select payment_id from pg_temp.payment_ops_fixture),(select transaction_id from pg_temp.payment_ops_fixture),
  'late_payment_return',(select payment_version from pg_temp.payment_ops_fixture),gen_random_uuid()),
  '22023','ADMIN_REFUND_AMOUNT_EXCEEDS_AVAILABLE');
select pg_temp.po_error('requester cannot approve own refund',format(
  'select public.admin_transition_payment_refund(%L::uuid,1,%L,null,null,%L::uuid)',
  (select (value->>'refund_id')::uuid from requested),'approve',gen_random_uuid()),
  '42501','PAYMENT_REFUND_TWO_PERSON_REQUIRED');
reset role;

select set_config('request.jwt.claim.sub','a1400000-0000-4000-8000-000000000004',true);
set local role authenticated;
create temp table approved on commit drop as select public.admin_transition_payment_refund(
  (select (value->>'refund_id')::uuid from requested),1,'approve',null,null,
  'a1480000-0000-4000-8000-000000000003') value;
select pg_temp.po_assert('approve replay idempotent',(select value=public.admin_transition_payment_refund(
  (select (value->>'refund_id')::uuid from requested),1,'approve',null,null,
  'a1480000-0000-4000-8000-000000000003') from approved));
select pg_temp.po_error('stale refund transition blocked',format(
  'select public.admin_transition_payment_refund(%L::uuid,1,%L,null,null,%L::uuid)',
  (select (value->>'refund_id')::uuid from requested),'start_processing',gen_random_uuid()),'40001','STALE_VERSION');
select public.admin_transition_payment_refund((select (value->>'refund_id')::uuid from requested),
  2,'start_processing',null,null,'a1480000-0000-4000-8000-000000000004');
select pg_temp.po_error('refunded requires evidence',format(
  'select public.admin_transition_payment_refund(%L::uuid,3,%L,null,null,%L::uuid)',
  (select (value->>'refund_id')::uuid from requested),'record_refunded',gen_random_uuid()),
  '22023','ADMIN_REFUND_TRANSITION_INVALID_INPUT');
select public.admin_transition_payment_refund((select (value->>'refund_id')::uuid from requested),
  3,'record_refunded','BANK-CONFIRMATION-REFERENCE',null,'a1480000-0000-4000-8000-000000000005');
select pg_temp.po_assert('refund terminal state and audit',exists(select 1 from jsonb_array_elements(
  public.admin_list_payment_refunds(null,null,null,null,100)->'rows') f
  where f->>'refund_id'=(select value->>'refund_id' from requested) and f->>'status'='refunded'
    and f->>'version'='4' and f->>'requested_by'<>f->>'approved_by'
    and f->>'evidence_reference'='BANK-CONFIRMATION-REFERENCE')
  and exists(select 1 from pg_temp.payment_ops_fixture x where 4=(select count(*) from jsonb_array_elements(
    public.admin_get_payment_operations_timeline(x.payment_id)->'rows') e where e->>'event_type' like 'refund_%')));
select pg_temp.po_assert('operations report includes all categories',(select x->>'bank_total'='0'
  and x->>'cash_total'='0' and x->>'paid_count'='0' and x->>'unpaid_count'='1'
  and x->>'rejected_transactions'='1' and x->>'late_payments'='1'
  and x->>'refund_total'='120000' from (select public.admin_get_payment_operations_report(
    clock_timestamp()-interval '1 hour',clock_timestamp()+interval '1 hour') x) q));
select pg_temp.po_assert('unified timeline includes bank and refund events',exists(select 1 from pg_temp.payment_ops_fixture f
  where jsonb_array_length(public.admin_get_payment_operations_timeline(f.payment_id)->'rows')>=6));
select pg_temp.po_assert('refund read model safe',not exists(select 1 from jsonb_array_elements(
  public.admin_list_payment_refunds(null,null,null,null,100)->'rows') r
  where r ?| array['raw_payload','headers','secret','service_role']));
reset role;

select pg_temp.po_error('audit cannot be deleted',
  $$delete from private.payment_operations_audit$$,'23514','PAYMENT_OPERATIONS_AUDIT_IMMUTABLE');
select pg_temp.po_assert('SePay verification config untouched',exists(select 1 from private.payment_bank_config c
  where c.require_beneficiary and c.verification_enabled and c.verification_provider='test_only'
    and c.verification_scope='payment_ops'));
select 'ADMIN_PAYMENT_OPERATIONS_V2_REGRESSION_PASS' result,count(*) assertions
  from pg_temp.payment_ops_results;
rollback;
