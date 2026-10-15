-- Disposable only. Never run against a linked/live project. All fixtures roll back.
begin;
set local statement_timeout='60s';
do $$ begin
 if current_setting('payment.test_mode',true) is distinct from 'local_disposable' or
    not exists(select 1 from pg_roles where rolname=current_user and (rolsuper or rolbypassrls)) then
   raise exception 'SYSTEM_TEST_REFUSED'; end if;
 if exists(select 1 from auth.users where id::text like 'a1500000-%') then raise exception 'SYSTEM_FIXTURES_OCCUPIED'; end if;
end $$;
create temp table system_results(label text primary key);
grant select,insert on pg_temp.system_results to anon,authenticated;
create function pg_temp.sc_assert(label text,ok boolean) returns void language plpgsql as $$
begin
 if ok is distinct from true then raise exception 'TEST_FAIL: %',label; end if;
 insert into pg_temp.system_results values(label);
end $$;
create function pg_temp.sc_error(label text,sql text,expected text,message text default null) returns void language plpgsql as $$
declare state text; detail text;
begin
 begin execute sql; exception when others then get stacked diagnostics state=returned_sqlstate,detail=message_text; end;
 if state is distinct from expected or (message is not null and detail is distinct from message) then
  raise exception 'TEST_FAIL: %, expected % %, got % %',label,expected,message,state,detail; end if;
 perform pg_temp.sc_assert(label,true);
end $$;
select set_config('request.jwt.claim.sub','',true),set_config('request.jwt.claims','{}',true);
insert into auth.users(id,email) select ('a1500000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'system-'||n||'@example.invalid' from generate_series(1,9) n;
insert into public.admin_profiles(id,full_name,role,status) values
 ('a1500000-0000-4000-8000-000000000003','System super','super_admin','active'),
 ('a1500000-0000-4000-8000-000000000004','System operator','operator','active'),
 ('a1500000-0000-4000-8000-000000000005','System finance','finance','active'),
 ('a1500000-0000-4000-8000-000000000006','System support','support','active'),
 ('a1500000-0000-4000-8000-000000000007','System reviewer','partner_reviewer','active'),
 ('a1500000-0000-4000-8000-000000000008','System blocked','super_admin','blocked');
insert into public.rescuer_profiles(user_id,full_name,contact_phone,verification_status)
 values('a1500000-0000-4000-8000-000000000002','System rescuer','0900000002','approved');
insert into public.rescuer_vehicles(id,rescuer_id,kind,display_name,license_plate,verification_status)
 values('a1560000-0000-4000-8000-000000000002','a1500000-0000-4000-8000-000000000002',
 'service_motorbike','System fixture vehicle','SYS100','approved');

-- Full cash lifecycle on the final schema; existing stage suites separately assert historical ACLs.
do $cash_final$
declare req uuid:=gen_random_uuid(); assignment uuid:=gen_random_uuid(); quote uuid:=gen_random_uuid(); photo uuid:=gen_random_uuid();
 dto jsonb; payment uuid; selection uuid:=gen_random_uuid(); confirmation uuid:=gen_random_uuid(); original jsonb;
begin
 select values into original from private.system_config where singleton;
 insert into public.rescue_requests(id,customer_id,client_request_id,vehicle_kind,service_code,
  location_text,location_confirmed,contact_name,contact_phone,status,provider_id)
 values(req,'a1500000-0000-4000-8000-000000000001',gen_random_uuid(),'motorbike','tire',
 'System fixture',true,'System Customer','0900000001','in_progress','a1500000-0000-4000-8000-000000000002');
 update private.system_config set values=original||'{"security.kill_new_jobs":true}';
 perform pg_temp.sc_error('new assignment kill enforced',format('insert into public.rescue_request_assignments(request_id,rescuer_id,vehicle_id) values(%L,%L,%L)',
  req,'a1500000-0000-4000-8000-000000000002','a1560000-0000-4000-8000-000000000002'),'P0001','SYSTEM_NEW_JOBS_DISABLED');
 update private.system_config set values=original;
 insert into public.rescue_request_assignments(id,request_id,rescuer_id,vehicle_id,state,accepted_at,en_route_at,arrived_at,in_progress_at)
 values(assignment,req,'a1500000-0000-4000-8000-000000000002','a1560000-0000-4000-8000-000000000002',
 'in_progress',clock_timestamp(),clock_timestamp(),clock_timestamp(),clock_timestamp());
 update private.system_config set values=original||'{"rescuer.quote_min_vnd":200000}';
 perform pg_temp.sc_error('quote limits enforced',format('insert into public.rescue_quotes(assignment_id,request_id,rescuer_id,revision,total_vnd,items) values(%L,%L,%L,1,120000,''[]'')',
  assignment,req,'a1500000-0000-4000-8000-000000000002'),'22023','SYSTEM_QUOTE_LIMIT');
 update private.system_config set values=original||'{"rescuer.quotes_enabled":false}';
 perform pg_temp.sc_error('quote flag enforced',format('insert into public.rescue_quotes(assignment_id,request_id,rescuer_id,revision,total_vnd,items) values(%L,%L,%L,1,120000,''[]'')',
  assignment,req,'a1500000-0000-4000-8000-000000000002'),'P0001','SYSTEM_QUOTES_DISABLED');
 update private.system_config set values=original||'{"customer.max_photos":0}';
 perform set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000001',true);
 execute 'set local role authenticated';
 perform pg_temp.sc_error('photo limit zero enforced',format('select public.reserve_customer_request_photo(%L,%L,''image/jpeg'',100)',req,photo),'22023','PHOTO_LIMIT_REACHED');
 execute 'reset role';
 update private.system_config set values=original||'{"customer.max_photos":1}';
 execute 'set local role authenticated';
 perform public.reserve_customer_request_photo(req,photo,'image/jpeg',100);
 perform pg_temp.sc_error('photo limit one enforced',format('select public.reserve_customer_request_photo(%L,%L,''image/jpeg'',100)',req,gen_random_uuid()),'22023','PHOTO_LIMIT_REACHED');
 execute 'reset role';
 update private.system_config set values=original||'{"customer.max_photos":0}';
 execute 'set local role authenticated';
 perform public.reserve_customer_request_photo(req,photo,'image/jpeg',100);
 perform pg_temp.sc_assert('existing photo reservation retry preserved',true);
 execute 'reset role';
 perform set_config('request.jwt.claim.sub','',true);
 update private.system_config set values=original||'{"rescuer.online_enabled":false}';
 perform pg_temp.sc_error('online disabled enforced','insert into public.rescuer_online_status(rescuer_id,is_online) values(''a1500000-0000-4000-8000-000000000002'',true)','P0001','SYSTEM_ONLINE_DISABLED');
 update private.system_config set values=original;
 insert into public.rescue_quotes(id,assignment_id,request_id,rescuer_id,revision,total_vnd,items)
 values(quote,assignment,req,'a1500000-0000-4000-8000-000000000002',1,120000,
 jsonb_build_array(jsonb_build_object('service_code','tire','quantity',1,'unit_price_vnd',120000)));
 perform pg_temp.sc_assert('prospective quote policy captured',exists(select 1 from private.system_quote_policy_snapshots where quote_id=quote and config_version=1 and platform_fee_bps=0));
 update public.rescue_request_assignments set state='completed',completed_at=clock_timestamp(),current_quote_id=quote,completion_quote_id=quote where id=assignment;
 update public.rescue_requests set status='completed',quoted_price=120000 where id=req;
 perform set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000001',true);
 execute 'set local role authenticated';
 dto:=public.customer_prepare_payment(req); payment:=(dto->>'payment_id')::uuid;
 perform pg_temp.sc_assert('final schema prepares cash payment',dto->>'status'='pending');
 execute 'reset role';
 select values into original from private.system_config where singleton;
 update private.system_config set values=values||'{"payment.cash_enabled":false}';
 execute 'set local role authenticated';
 perform pg_temp.sc_error('cash disabled server gate',format('select public.customer_select_payment_method(%L,%L,''cash'',1,%L)',req,payment,selection),'P0001','SYSTEM_CASH_DISABLED');
 execute 'reset role';
 update private.system_config set values=original||'{"payment.max_vnd":100000}';
 execute 'set local role authenticated';
 perform pg_temp.sc_error('payment amount limit server gate',format('select public.customer_select_payment_method(%L,%L,''cash'',1,%L)',req,payment,selection),'22023','SYSTEM_PAYMENT_LIMIT');
 execute 'reset role';
 update private.system_config set values=original;
 execute 'set local role authenticated';
 dto:=public.customer_select_payment_method(req,payment,'cash',1,selection);
 perform pg_temp.sc_assert('cash selected on final schema',dto->'payment'->>'method'='cash');
 execute 'reset role';
 -- A later limit/maintenance/new-method kill cannot invalidate already selected cash.
 update private.system_config set values=original||'{"payment.cash_enabled":false,"payment.max_vnd":100000,"customer.maintenance":true,"payment.cash_confirmation_enabled":false}';
 perform set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000002',true);
 execute 'set local role authenticated';
 perform pg_temp.sc_error('cash confirmation emergency server gate',format('select public.rescuer_confirm_cash_received(%L,%L,120000,2,%L)',req,payment,confirmation),'P0001','SYSTEM_CASH_CONFIRMATION_DISABLED');
 execute 'reset role';
 update private.system_config set values=values||'{"payment.cash_confirmation_enabled":true}';
 execute 'set local role authenticated';
 dto:=public.rescuer_confirm_cash_received(req,payment,120000,2,confirmation);
 perform pg_temp.sc_assert('existing cash settlement survives new limits',dto->'payment'->>'status'='paid');
 dto:=public.rescuer_confirm_cash_received(req,payment,120000,2,confirmation);
 perform pg_temp.sc_assert('cash receipt replay preserved',dto->'payment'->>'status'='paid');
 execute 'reset role';
 update private.system_config set values=original;
 perform pg_temp.sc_assert('payment amount unchanged',exists(select 1 from public.payments where id=payment and amount_expected=120000 and amount_received=120000));
 update private.system_config set values=original||'{"business.refunds_enabled":false}';
 perform set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000005',true);
 execute 'set local role authenticated';
 perform pg_temp.sc_error('refund policy enforced',format('select public.admin_request_payment_refund(%L,null,120000,''test_policy'',3,%L)',payment,gen_random_uuid()),'P0001','SYSTEM_REFUNDS_DISABLED');
 execute 'reset role';
 update private.system_config set values=original;
 perform set_config('request.jwt.claim.sub','',true);
end;
$cash_final$;

select pg_temp.sc_assert('private tables RLS and no direct DML',not exists(
 select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='private' and c.relname like 'system_%'
 and c.relkind='r' and (not c.relrowsecurity or has_table_privilege('authenticated',c.oid,'select,insert,update,delete,truncate') or
 has_table_privilege('anon',c.oid,'select,insert,update,delete,truncate') or has_table_privilege('service_role',c.oid,'select,insert,update,delete,truncate'))));
select pg_temp.sc_assert('new definer search_path fixed',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where (n.nspname='private' and p.proname like 'system_%' or n.nspname='public' and (p.proname like 'admin_%system%' or p.proname in ('get_public_system_config','system_session_allowed')))
 and (not p.prosecdef or not ('search_path=""'=any(p.proconfig)))));
select pg_temp.sc_assert('private helpers not executable',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='private' and p.proname like 'system_%' and (has_function_privilege('authenticated',p.oid,'execute') or has_function_privilege('anon',p.oid,'execute'))));
select pg_temp.sc_assert('all existing client definer RPCs guarded',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 join pg_language l on l.oid=p.prolang where n.nspname='public' and l.lanname='plpgsql' and p.prosecdef and p.prorettype<>'trigger'::regtype
 and has_function_privilege('authenticated',p.oid,'execute') and p.proname not in ('get_public_system_config','system_session_allowed')
 and p.prosrc not like '%private.system_require_session()%'));
select pg_temp.sc_assert('legacy admin column DML revoked',not has_any_column_privilege('authenticated','public.admin_profiles','insert,update'));
select pg_temp.sc_error('immutable audit owner UPDATE','update private.system_config_audit set reason=''forged''','23514','SYSTEM_AUDIT_IMMUTABLE');
select pg_temp.sc_error('immutable audit owner DELETE','delete from private.system_config_audit','23514','SYSTEM_AUDIT_IMMUTABLE');
select pg_temp.sc_error('immutable audit TRUNCATE','truncate private.system_config_audit','23514','SYSTEM_AUDIT_IMMUTABLE');
select pg_temp.sc_error('quote policy snapshots immutable','update private.system_quote_policy_snapshots set platform_fee_bps=1','23514','SYSTEM_AUDIT_IMMUTABLE');

set local role anon;
select pg_temp.sc_assert('anon safe projection',public.get_public_system_config('customer')->'values' ? 'customer.max_photos');
select pg_temp.sc_assert('no private config leak',not (public.get_public_system_config('customer')->'values' ?| array['security.role_permissions','security.max_token_age_seconds','business.platform_fee_bps','account_number','verification_provider','sepay_secret']));
select pg_temp.sc_assert('rescuer projection isolated',not (public.get_public_system_config('rescuer')->'values' ? 'customer.banner'));
select pg_temp.sc_error('invalid app','select public.get_public_system_config(''admin'')','22023','SYSTEM_INVALID_APP');
select pg_temp.sc_error('anon admin read denied','select public.admin_get_system_config()','42501');
select pg_temp.sc_error('anon mutation denied','select public.admin_apply_system_config(''{"customer.banner":"x"}'',1,''test reason'',true)','42501');
reset role;

-- Every membership category is exercised through authenticated role, not owner privileges.
do $$ declare uid uuid; i integer; result jsonb;
begin
 for i in 1..9 loop
  uid:=('a1500000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
  perform set_config('request.jwt.claim.sub',uid::text,true);
  execute 'set local role authenticated';
  if i in (1,2,8,9) then
   perform pg_temp.sc_error('non admin read denied '||i,'select public.admin_get_system_config()','42501','ADMIN_FORBIDDEN');
   perform pg_temp.sc_error('non admin write denied '||i,'select public.admin_apply_system_config(''{"customer.banner":"x"}'',1,''test reason'',true)','42501','ADMIN_FORBIDDEN');
  else
   result:=public.admin_get_system_config();
   perform pg_temp.sc_assert('admin read allowed '||i,result->>'version'='1');
   if i in (6,7) then
    perform pg_temp.sc_error('readonly role write denied '||i,'select public.admin_apply_system_config(''{"customer.banner":"x"}'',1,''test reason'',true)','42501','SYSTEM_CONFIG_FORBIDDEN');
   end if;
  end if;
  execute 'reset role';
 end loop;
end $$;

select set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000004',true);
set local role authenticated;
select pg_temp.sc_error('operator cannot payment','select public.admin_apply_system_config(''{"payment.cash_enabled":false}'',1,''test reason'',true)','42501','SYSTEM_CONFIG_FORBIDDEN');
select pg_temp.sc_error('operator cannot security','select public.admin_apply_system_config(''{"security.kill_new_requests":true}'',1,''test reason'',true)','42501','SYSTEM_CONFIG_FORBIDDEN');
select pg_temp.sc_assert('operator customer edit',public.admin_apply_system_config('{"customer.banner":"Hello"}',1,'test banner',false)->>'version'='2');
select pg_temp.sc_error('stale same version denied','select public.admin_apply_system_config(''{"customer.banner":"Lost update"}'',1,''test stale'',false)','40001','SYSTEM_CONFIG_VERSION_CONFLICT');
select pg_temp.sc_assert('stale write atomic',public.admin_get_system_config()->'values'->>'customer.banner'='Hello');
select pg_temp.sc_error('operator cannot account','select public.admin_get_system_account_control(''a1500000-0000-4000-8000-000000000001'')','42501','ADMIN_FORBIDDEN');
reset role;
select set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000005',true);
set local role authenticated;
select pg_temp.sc_error('finance cannot customer','select public.admin_apply_system_config(''{"customer.banner":"x"}'',2,''test reason'',true)','42501','SYSTEM_CONFIG_FORBIDDEN');
select pg_temp.sc_error('dangerous needs confirmation','select public.admin_apply_system_config(''{"payment.cash_enabled":false}'',2,''test reason'',false)','22023','SYSTEM_CONFIG_CONFIRMATION_REQUIRED');
select pg_temp.sc_assert('finance payment edit',public.admin_apply_system_config('{"payment.qr_expiry_seconds":600}',2,'test expiry',true)->>'version'='3');
reset role;
select set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000003',true);
set local role authenticated;
select pg_temp.sc_error('self admin demotion denied','select public.admin_apply_system_admin_access(''a1500000-0000-4000-8000-000000000003'',''support'',''active'',now(),''test access'',true)','22023','SYSTEM_CANNOT_CHANGE_OWN_ACCESS');
select pg_temp.sc_error('admin access stale timestamp','select public.admin_apply_system_admin_access(''a1500000-0000-4000-8000-000000000004'',''support'',''active'',''2000-01-01'',''test access'',true)','40001','SYSTEM_CONFIG_VERSION_CONFLICT');
select pg_temp.sc_assert('super can change role via RPC',public.admin_apply_system_admin_access('a1500000-0000-4000-8000-000000000004','support','active',
 (public.admin_get_system_account_control('a1500000-0000-4000-8000-000000000004')->'admin_access'->>'updated_at')::timestamptz,'test admin role',true)->'admin_access'->>'role'='support');
select pg_temp.sc_assert('super can restore role via RPC',public.admin_apply_system_admin_access('a1500000-0000-4000-8000-000000000004','operator','active',
 (public.admin_get_system_account_control('a1500000-0000-4000-8000-000000000004')->'admin_access'->>'updated_at')::timestamptz,'restore admin role',true)->'admin_access'->>'role'='operator');
select pg_temp.sc_error('unknown secret rejected','select public.admin_apply_system_config(''{"sepay_secret":"secret"}'',3,''test reason'',true)','22023','SYSTEM_CONFIG_UNKNOWN_KEY');
select pg_temp.sc_error('wrong boolean type','select public.admin_apply_system_config(''{"customer.maintenance":"false"}'',3,''test reason'',true)','22023');
select pg_temp.sc_error('fractional integer','select public.admin_apply_system_config(''{"customer.max_photos":1.5}'',3,''test reason'',true)','22023');
select pg_temp.sc_error('null value','select public.admin_apply_system_config(''{"customer.max_photos":null}'',3,''test reason'',true)','22023');
select pg_temp.sc_error('range checked','select public.admin_apply_system_config(''{"customer.max_photos":4}'',3,''test reason'',true)','22023');
select pg_temp.sc_error('one job compatibility','select public.admin_apply_system_config(''{"rescuer.max_active_jobs":2}'',3,''test reason'',true)','22023');
select pg_temp.sc_error('min max checked','select public.admin_apply_system_config(''{"payment.min_vnd":100,"payment.max_vnd":50}'',3,''test reason'',true)','22023','SYSTEM_CONFIG_INCONSISTENT');
select pg_temp.sc_error('quote limits checked','select public.admin_apply_system_config(''{"rescuer.quote_min_vnd":100,"rescuer.quote_max_vnd":50}'',3,''test reason'',true)','22023','SYSTEM_CONFIG_INCONSISTENT');
select pg_temp.sc_error('fee total checked','select public.admin_apply_system_config(''{"business.platform_fee_bps":6000,"business.rescuer_commission_bps":6000}'',3,''test reason'',true)','22023','SYSTEM_CONFIG_INCONSISTENT');
select pg_temp.sc_error('reason required','select public.admin_apply_system_config(''{"customer.banner":"x"}'',3,''x'',true)','22023');
select pg_temp.sc_error('null expected version','select public.admin_apply_system_config(''{"customer.banner":"x"}'',null,''test reason'',true)','22023');
select pg_temp.sc_error('permissions retain super','select public.admin_apply_system_config(''{"security.role_permissions":{"customer":["operator"],"rescuer":["super_admin"],"payment":["super_admin"],"security":["super_admin"]}}'',3,''test reason'',true)','22023');
select pg_temp.sc_error('cannot grant security to finance','select public.admin_apply_system_config(''{"security.role_permissions":{"customer":["super_admin"],"rescuer":["super_admin"],"payment":["super_admin"],"security":["super_admin","finance"]}}'',3,''test reason'',true)','22023');
select pg_temp.sc_error('MFA enrollment required','select public.admin_apply_system_config(''{"security.admin_mfa_required":true}'',3,''test reason'',true)','22023','SYSTEM_MFA_ENROLLMENT_REQUIRED');
select pg_temp.sc_assert('noop no new version',public.admin_apply_system_config('{"customer.banner":"Hello"}',3,'test noop',true)->>'version'='3');
select pg_temp.sc_assert('audit tracks exactly successful writes',jsonb_array_length(public.admin_list_system_config_audit()->'rows')=4);
select pg_temp.sc_error('audit page bounds','select public.admin_list_system_config_audit(null,101)','22023');
select pg_temp.sc_assert('public sees latest expiry',public.get_public_system_config('customer')->'values'->>'payment.qr_expiry_seconds'='600');
select pg_temp.sc_assert('kill request activated',public.admin_apply_system_config('{"security.kill_new_requests":true}',3,'test kill switch',true)->>'version'='4');
reset role;
select set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000001',true);
set local role authenticated;
select pg_temp.sc_error('kill enforced at request write',
 'select public.create_customer_rescue_request(gen_random_uuid(),''motorbike'',''tire'',''test address'','''',''Customer'',''0900000001'',null,null,null)',
 'P0001','SYSTEM_REQUESTS_DISABLED');
reset role;
select set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000003',true);
set local role authenticated;
select pg_temp.sc_assert('kill request cleared',public.admin_apply_system_config('{"security.kill_new_requests":false}',4,'test recovery',true)->>'version'='5');
select pg_temp.sc_error('self lock denied','select public.admin_apply_system_account_control(''a1500000-0000-4000-8000-000000000003'',''locked'',null,false,0,''test reason'',true)','22023','SYSTEM_CANNOT_CHANGE_OWN_ACCESS');
select pg_temp.sc_assert('new account version zero',public.admin_get_system_account_control('a1500000-0000-4000-8000-000000000001')->>'version'='0');
select pg_temp.sc_assert('super locks customer',public.admin_apply_system_account_control('a1500000-0000-4000-8000-000000000001','locked',null,false,0,'test account lock',true)->>'version'='1');
select pg_temp.sc_error('account version guard','select public.admin_apply_system_account_control(''a1500000-0000-4000-8000-000000000001'',''active'',null,false,0,''test reason'',true)','40001','SYSTEM_CONFIG_VERSION_CONFLICT');
reset role;
select set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000001',true);
set local role authenticated;
select pg_temp.sc_assert('locked customer RLS denied',not public.system_session_allowed() and not exists(select 1 from public.customer_profiles));
select pg_temp.sc_error('locked customer RPC denied','select public.customer_get_payment(gen_random_uuid())','42501','SYSTEM_SESSION_DENIED');
reset role;
select set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000003',true);
set local role authenticated;
select pg_temp.sc_assert('unlock and revoke',public.admin_apply_system_account_control('a1500000-0000-4000-8000-000000000001','active',null,true,1,'test revoke JWT',true)->>'version'='2');
select pg_temp.sc_assert('suspend rescuer',public.admin_apply_system_account_control('a1500000-0000-4000-8000-000000000002','suspended',null,false,0,'test suspension',true)->>'version'='1');
reset role;
select set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000002',true);
set local role authenticated;
select pg_temp.sc_assert('suspended rescuer RLS denied',not public.system_session_allowed() and not exists(select 1 from public.rescuer_profiles));
select pg_temp.sc_error('suspended rescuer RPC denied','select public.rescuer_get_active_job()','42501','SYSTEM_SESSION_DENIED');
reset role;
select set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000001',true),set_config('request.jwt.claims','{"iat":1}',true);
set local role authenticated;
select pg_temp.sc_assert('revoked old JWT denied',not public.system_session_allowed());
reset role;
select set_config('request.jwt.claims',jsonb_build_object('iat',ceil(extract(epoch from clock_timestamp()))+1)::text,true);
set local role authenticated;
select pg_temp.sc_assert('new JWT allowed',public.system_session_allowed());
reset role;
select set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000003',true),
 set_config('request.jwt.claims',jsonb_build_object('iat',floor(extract(epoch from clock_timestamp())))::text,true);
set local role authenticated;
select pg_temp.sc_assert('max token age configured',public.admin_apply_system_config('{"security.max_token_age_seconds":3600}',5,'test token age',true)->>'version'='6');
reset role;
select set_config('request.jwt.claims','{}',true);
set local role authenticated;
select pg_temp.sc_assert('missing token iat denied',not public.system_session_allowed());
reset role;
select set_config('request.jwt.claims',jsonb_build_object('iat',floor(extract(epoch from clock_timestamp()))-4000)::text,true);
set local role authenticated;
select pg_temp.sc_assert('old token denied',not public.system_session_allowed());
reset role;
select set_config('request.jwt.claims',jsonb_build_object('iat',floor(extract(epoch from clock_timestamp())),'aal','aal2')::text,true);
set local role authenticated;
select pg_temp.sc_assert('fresh token allowed',public.system_session_allowed());
select pg_temp.sc_assert('MFA enabled with AAL2',public.admin_apply_system_config('{"security.admin_mfa_required":true}',6,'test MFA enrolled',true)->>'version'='7');
reset role;
select set_config('request.jwt.claims',jsonb_build_object('iat',floor(extract(epoch from clock_timestamp())),'aal','aal1')::text,true);
set local role authenticated;
select pg_temp.sc_assert('AAL1 admin denied',not public.system_session_allowed() and not public.is_admin());
select pg_temp.sc_error('AAL1 config denied','select public.admin_get_system_config()','42501','SYSTEM_SESSION_DENIED');
reset role;
select 'SYSTEM_CONFIGURATION_SECURITY_V1_PASS' result,count(*) assertions from pg_temp.system_results;
rollback;
