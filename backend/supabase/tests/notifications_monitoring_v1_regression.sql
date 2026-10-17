-- Disposable privileged database only. All fixtures roll back.
begin;
set local statement_timeout='60s';
do $$ begin
  if current_setting('payment.test_mode',true) is distinct from 'local_disposable'
     or not exists(select 1 from pg_roles where rolname=current_user and (rolsuper or rolbypassrls)) then
    raise exception 'MONITORING_TEST_REFUSED';
  end if;
  if exists(select 1 from auth.users where id::text like 'a1600000-%') then raise exception 'MONITORING_FIXTURES_OCCUPIED'; end if;
end $$;

create temp table monitoring_results(label text primary key);
grant select,insert on pg_temp.monitoring_results to anon,authenticated;
create function pg_temp.mo_assert(label text,ok boolean) returns void language plpgsql as $$
begin
  if ok is distinct from true then raise exception 'TEST_FAIL: %',label; end if;
  insert into pg_temp.monitoring_results values(label);
end $$;
create function pg_temp.mo_error(label text,sql text,expected text,message text default null) returns void language plpgsql as $$
declare state text; detail text;
begin
  begin execute sql; exception when others then get stacked diagnostics state=returned_sqlstate,detail=message_text; end;
  if state is distinct from expected or (message is not null and detail is distinct from message) then
    raise exception 'TEST_FAIL: %, expected % %, got % %',label,expected,message,state,detail;
  end if;
  perform pg_temp.mo_assert(label,true);
end $$;

select set_config('request.jwt.claim.sub','',true),set_config('request.jwt.claims','{}',true);
insert into auth.users(id,email) values
 ('a1600000-0000-4000-8000-000000000001','monitor-customer@example.invalid'),
 ('a1600000-0000-4000-8000-000000000002','monitor-rescuer@example.invalid'),
 ('a1600000-0000-4000-8000-000000000003','monitor-super@example.invalid'),
 ('a1600000-0000-4000-8000-000000000004','monitor-operator@example.invalid'),
 ('a1600000-0000-4000-8000-000000000005','monitor-finance@example.invalid'),
 ('a1600000-0000-4000-8000-000000000006','monitor-support@example.invalid');
insert into public.admin_profiles(id,full_name,role,status) values
 ('a1600000-0000-4000-8000-000000000003','Monitor super','super_admin','active'),
 ('a1600000-0000-4000-8000-000000000004','Monitor operator','operator','active'),
 ('a1600000-0000-4000-8000-000000000005','Monitor finance','finance','active'),
 ('a1600000-0000-4000-8000-000000000006','Monitor support','support','active');
insert into public.rescuer_profiles(user_id,full_name,contact_phone,verification_status)
 values('a1600000-0000-4000-8000-000000000002','Monitor rescuer','0900000160','approved');
insert into private.system_config_audit(actor_id,action,target,version,before_value,after_value,reason)
 values('a1600000-0000-4000-8000-000000000003','config_update','system',999,'{}','{}','monitoring fixture change');

select private.record_bank_webhook_attempt('sepay','monitoring_test',401,'invalid_signature','authenticate_normalize',repeat('a',64),12);
select private.record_bank_webhook_attempt('sepay','monitoring_test',401,'invalid_signature','authenticate_normalize',repeat('b',64),13);
select private.record_bank_webhook_attempt('sepay','monitoring_test',401,'invalid_signature','authenticate_normalize',repeat('c',64),14);
select private.record_bank_webhook_attempt('sepay','monitoring_test',500,'internal_failure','process_transaction',repeat('d',64),20);
select private.record_bank_webhook_attempt('sepay','monitoring_test',500,'internal_failure','process_transaction',repeat('e',64),21);
select private.record_bank_webhook_attempt('sepay','monitoring_test',500,'internal_failure','process_transaction',repeat('f',64),22);
select pg_temp.mo_assert('attempt rows recorded',(
  select count(*)=6 from private.system_webhook_attempts where provider_scope='monitoring_test'));
select pg_temp.mo_assert('telemetry table has no raw payload/header/secret columns',not exists(
  select 1 from information_schema.columns where table_schema='private' and table_name='system_webhook_attempts'
    and column_name in ('raw_body','payload','headers','signature','secret','account_number')));
select pg_temp.mo_error('attempt metadata validation',
  'select private.record_bank_webhook_attempt(''sepay'',''x'',418,''teapot'',''request_validation'',null,1)','22023','SYSTEM_WEBHOOK_ATTEMPT_INVALID');

set local role anon;
select pg_temp.mo_error('anon read denied','select public.admin_get_system_monitoring(24,100)','42501');
select pg_temp.mo_error('anon ack denied','select public.admin_acknowledge_system_alert(''x:y'',repeat(''a'',64),gen_random_uuid())','42501');
select pg_temp.mo_error('anon private telemetry denied','select count(*) from private.system_webhook_attempts','42501');
reset role;

select set_config('request.jwt.claim.sub','a1600000-0000-4000-8000-000000000001',true);
set local role authenticated;
select pg_temp.mo_error('customer read denied','select public.admin_get_system_monitoring(24,100)','42501','ADMIN_FORBIDDEN');
reset role;
select set_config('request.jwt.claim.sub','a1600000-0000-4000-8000-000000000002',true);
set local role authenticated;
select pg_temp.mo_error('rescuer read denied','select public.admin_get_system_monitoring(24,100)','42501','ADMIN_FORBIDDEN');
reset role;
select set_config('request.jwt.claim.sub','a1600000-0000-4000-8000-000000000006',true);
set local role authenticated;
select pg_temp.mo_error('restricted support read denied','select public.admin_get_system_monitoring(24,100)','42501','ADMIN_FORBIDDEN');
reset role;

select set_config('request.jwt.claim.sub','a1600000-0000-4000-8000-000000000005',true);
set local role authenticated;
do $finance$
declare d jsonb;
begin
  d:=public.admin_get_system_monitoring(24,100);
  perform pg_temp.mo_assert('finance read allowed',d->>'generated_at' is not null);
  perform pg_temp.mo_assert('finance cannot acknowledge',(d->>'can_acknowledge')::boolean=false);
  perform pg_temp.mo_assert('401 burst critical',exists(select 1 from jsonb_array_elements(d->'alerts') x where x->>'code'='multiple_invalid_signature' and x->>'severity'='critical'));
  perform pg_temp.mo_assert('500 burst critical',exists(select 1 from jsonb_array_elements(d->'alerts') x where x->>'code'='multiple_webhook_failures' and x->>'severity'='critical'));
  perform pg_temp.mo_assert('info severity security alert',exists(select 1 from jsonb_array_elements(d->'alerts') x where x->>'code'='security_configuration_changed' and x->>'severity'='info'));
  perform pg_temp.mo_assert('summary exact attempt counts',(d->'summary'->>'webhook_4xx')::integer=3 and (d->'summary'->>'webhook_5xx')::integer=3);
  perform pg_temp.mo_assert('sensitive digest not projected',position(repeat('a',64) in d::text)=0 and position('body_sha256' in d::text)=0);
  perform pg_temp.mo_assert('delivery remains server-side',exists(select 1 from jsonb_array_elements(d->'delivery_channels') x where x->>'channel'='telegram' and x->>'status'='requires_server_configuration'));
end;
$finance$;
select pg_temp.mo_error('finance ack denied','select public.admin_acknowledge_system_alert(''webhook:401_burst'',repeat(''a'',64),gen_random_uuid())','42501','ADMIN_FORBIDDEN');
reset role;

select set_config('request.jwt.claim.sub','a1600000-0000-4000-8000-000000000004',true);
set local role authenticated;
do $operator$
declare d jsonb; a jsonb; op uuid:=gen_random_uuid(); first_result jsonb; second_result jsonb;
begin
  d:=public.admin_get_system_monitoring(24,100);
  perform pg_temp.mo_assert('operator read allowed and may ack',(d->>'can_acknowledge')::boolean);
  select x into a from jsonb_array_elements(d->'alerts') x where x->>'code'='multiple_invalid_signature' limit 1;
  first_result:=public.admin_acknowledge_system_alert(a->>'key',a->>'fingerprint',op);
  second_result:=public.admin_acknowledge_system_alert(a->>'key',a->>'fingerprint',op);
  perform pg_temp.mo_assert('ack first call changes',first_result->>'changed'='true');
  perform pg_temp.mo_assert('ack replay idempotent',second_result->>'changed'='false');
  d:=public.admin_get_system_monitoring(24,100);
  perform pg_temp.mo_assert('ack reflected in read',exists(select 1 from jsonb_array_elements(d->'alerts') x where x->>'code'='multiple_invalid_signature' and (x->>'acknowledged')::boolean));
  perform pg_temp.mo_assert('ack audited',exists(select 1 from public.admin_audit_logs where admin_id='a1600000-0000-4000-8000-000000000004' and action='acknowledge_system_alert'));
end;
$operator$;
select pg_temp.mo_error('stale alert rejected','select public.admin_acknowledge_system_alert(''webhook:missing'',repeat(''a'',64),gen_random_uuid())','40001','SYSTEM_ALERT_STALE');
reset role;

select pg_temp.mo_error('webhook attempts immutable','update private.system_webhook_attempts set duration_ms=1','23514','SYSTEM_MONITORING_AUDIT_IMMUTABLE');
select pg_temp.mo_error('ack audit immutable','delete from private.system_alert_acknowledgements','23514','SYSTEM_MONITORING_AUDIT_IMMUTABLE');
select pg_temp.mo_assert('fixed search path on public RPCs',not exists(
  select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in ('admin_get_system_monitoring','admin_acknowledge_system_alert')
    and not exists(select 1 from unnest(coalesce(p.proconfig,array[]::text[])) setting where setting like 'search_path=%')));
select pg_temp.mo_assert('authenticated only execute grants',
  has_function_privilege('authenticated','public.admin_get_system_monitoring(integer,integer)','EXECUTE')
  and not has_function_privilege('anon','public.admin_get_system_monitoring(integer,integer)','EXECUTE'));
select pg_temp.mo_assert('private tables have no API grants',not has_table_privilege('authenticated','private.system_webhook_attempts','SELECT')
  and not has_table_privilege('service_role','private.system_webhook_attempts','SELECT')
  and not has_table_privilege('authenticated','private.system_alert_acknowledgements','SELECT'));
select pg_temp.mo_assert('SePay processor preserved',to_regprocedure('private.process_verified_bank_transaction(jsonb)') is not null);
select 'NOTIFICATIONS_MONITORING_V1_PASS' result,count(*) assertions from pg_temp.monitoring_results;
rollback;
