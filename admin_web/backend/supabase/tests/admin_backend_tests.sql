-- Admin backend SQL regression. LOCAL DISPOSABLE DATABASE ONLY.
-- Requires all 7 shared migrations + Admin migration. Uses synthetic UUIDs.
-- Execute as trusted migration role; fixtures and all mutations ROLLBACK.
-- For psql: -X -v ON_ERROR_STOP=1 -f tests/admin_backend_tests.sql
-- Enable explicitly on the SAME connection first:
--   select set_config('admin.test_mode','local_disposable',false);
-- This opt-in is not host detection. Check the connection before enabling.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
do $guard$
begin
  if current_setting('admin.test_mode',true) is distinct from 'local_disposable' then
    raise exception 'TEST_REFUSED: set admin.test_mode=local_disposable on a disposable local database only';
  end if;
end;
$guard$;

-- Manual inventory, also asserted below.
select name,to_regclass('public.'||name) as relation from unnest(array[
 'admin_profiles','admin_audit_logs','admin_notifications','rescue_services','admin_service_catalog',
 'admin_rescue_requests_view','admin_customers_view','admin_rescuers_view',
 'admin_quotes_view','admin_reviews_view','admin_services_view','admin_rescuer_documents_view'
]) name;
select p.proname from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and (p.proname in ('is_admin','has_admin_role') or p.proname like 'admin\_%' escape '\');
select c.relname,c.relrowsecurity from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in ('admin_profiles','admin_audit_logs','admin_notifications','admin_service_catalog','rescue_services');

create function pg_temp.check_true(ok boolean,label text) returns void
language plpgsql security invoker as $$
begin if ok is distinct from true then raise exception 'TEST_FAIL: %',label; end if; end;
$$;
create function pg_temp.expect_error(statement text,expected_state text) returns void
language plpgsql security invoker as $$
declare actual_state text; message text;
begin
  begin
    execute statement;
  exception when others then
    get stacked diagnostics actual_state=returned_sqlstate,message=message_text;
    if actual_state=expected_state then return; end if;
    raise exception 'TEST_FAIL: expected SQLSTATE %, got % (%) in %',expected_state,actual_state,message,statement;
  end;
  raise exception 'TEST_FAIL: unexpectedly succeeded: %',statement;
end;
$$;

do $inventory$
declare n text;
begin
  foreach n in array array['admin_profiles','admin_audit_logs','admin_notifications','admin_service_catalog','rescue_services'] loop
    perform pg_temp.check_true((select relrowsecurity from pg_catalog.pg_class where oid=to_regclass('public.'||n)),'RLS '||n);
  end loop;
  perform pg_temp.check_true(not has_function_privilege('authenticated','public.admin_log_action(text,text,uuid,jsonb)','EXECUTE'),'internal logger inaccessible');
  perform pg_temp.check_true(not has_function_privilege('anon','public.admin_get_dashboard_stats()','EXECUTE'),'anonymous RPC denied');
  perform pg_temp.check_true(not has_table_privilege('authenticated','public.admin_audit_logs','INSERT'),'cannot forge audit');
  perform pg_temp.check_true(not has_table_privilege('authenticated','public.admin_audit_logs','UPDATE'),'audit immutable to clients');
  perform pg_temp.check_true(not has_table_privilege('authenticated','public.admin_audit_logs','DELETE'),'audit not deletable');
  perform pg_temp.check_true(not has_table_privilege('authenticated','public.rescue_services','UPDATE'),'shared catalog status RPC-only');
  perform pg_temp.check_true((select count(*)=6 from public.admin_service_catalog where admin_code like 'SRV-%'),'six default admin services');
  perform pg_temp.check_true((select count(*)=2 from public.rescue_services where code in ('locksmith','mechanic') and not is_active),'new unsupported services disabled');
end;
$inventory$;

-- Fixture identities 1..5 = roles, 6 = blocked, 7 = ordinary customer,
-- 8,9 = submitted rescuer, 10 = active rescuer, 11..16 = customer fixtures.
insert into auth.users(id,email)
select ('e1000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'admin-test-'||i||'@example.invalid'
from generate_series(1,16) i;
insert into public.admin_profiles(id,full_name,role,status)
select ('e1000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'Admin test '||i,
  (array['super_admin','operator','support','partner_reviewer','finance','operator'])[i],
  case when i=6 then 'blocked' else 'active' end
from generate_series(1,6) i;
insert into public.rescuer_profiles(user_id,full_name,contact_phone,verification_status)
select ('e1000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'Rescuer test '||i,'0900000000',
  case when i=10 then 'approved' else 'submitted' end
from generate_series(8,10) i;
insert into public.rescuer_vehicles(id,rescuer_id,kind,display_name,license_plate,verification_status)
values('e2000000-0000-4000-8000-000000000010','e1000000-0000-4000-8000-000000000010','tow_truck','Test tow','TEST10','approved');
insert into public.rescuer_online_status(rescuer_id,is_online,session_id,vehicle_id,last_seen_at)
values('e1000000-0000-4000-8000-000000000010',true,gen_random_uuid(),'e2000000-0000-4000-8000-000000000010',now());
insert into public.rescue_requests(id,customer_id,client_request_id,vehicle_kind,service_code,location_text,
  location_confirmed,contact_name,contact_phone,status,provider_id)
select ('e3000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
  ('e1000000-0000-4000-8000-'||lpad((10+i)::text,12,'0'))::uuid,
  gen_random_uuid(),'car','towing','Test address',true,'Test customer','0900000000',
  (array['searching','accepted','arriving','in_progress','completed','cancelled'])[i],
  case when i=2 then 'e1000000-0000-4000-8000-000000000010'::uuid end
from generate_series(1,6) i;
insert into public.rescue_request_assignments(id,request_id,rescuer_id,vehicle_id,state)
values('e4000000-0000-4000-8000-000000000002','e3000000-0000-4000-8000-000000000002',
 'e1000000-0000-4000-8000-000000000010','e2000000-0000-4000-8000-000000000010','accepted');
insert into public.rescuer_assignment_events(assignment_id,version,event_kind,state,actor_kind,actor_id)
values('e4000000-0000-4000-8000-000000000002',1,'claimed','accepted','rescuer','e1000000-0000-4000-8000-000000000010');
insert into public.rescue_quotes(id,assignment_id,request_id,rescuer_id,revision,total_vnd,items,note)
values('e5000000-0000-4000-8000-000000000002','e4000000-0000-4000-8000-000000000002',
 'e3000000-0000-4000-8000-000000000002','e1000000-0000-4000-8000-000000000010',2,500000,
 '[{"service_code":"towing","quantity":1,"unit_price_vnd":500000}]','Finance test');
update public.rescue_request_assignments set current_quote_id='e5000000-0000-4000-8000-000000000002'
 where id='e4000000-0000-4000-8000-000000000002';
update public.rescue_requests set quoted_price=500000 where id='e3000000-0000-4000-8000-000000000002';
-- Old revision must not inflate dashboard revenue. It stays visible only in the
-- finance view for historical audit; current_quote_id stays on the issued quote.
insert into public.rescue_quotes(id,assignment_id,request_id,rescuer_id,revision,status,total_vnd,items,note)
values('e5000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000002',
 'e3000000-0000-4000-8000-000000000002','e1000000-0000-4000-8000-000000000010',1,'superseded',700000,
 '[{"service_code":"towing","quantity":1,"unit_price_vnd":700000}]','Superseded test');
insert into public.rescuer_documents(id,rescuer_id,document_type,storage_path,content_type,byte_size)
values('e6000000-0000-4000-8000-000000000008','e1000000-0000-4000-8000-000000000008','identity',
 'e1000000-0000-4000-8000-000000000008/e6000000-0000-4000-8000-000000000008','image/jpeg',1000);
-- Review trigger requires the actual customer identity even for fixtures.
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000015',true);
insert into public.customer_request_reviews(request_id,customer_id,rating,comment)
values('e3000000-0000-4000-8000-000000000005','e1000000-0000-4000-8000-000000000015',5,'Test completed review');
select set_config('request.jwt.claim.sub','',true);
set constraints all immediate;
set constraints all deferred;

set local role anon;
select pg_temp.expect_error('select * from public.admin_profiles','42501');
select pg_temp.expect_error('select * from public.admin_customers_view','42501');
select pg_temp.expect_error('select public.admin_get_dashboard_stats()','42501');
reset role;

set local role authenticated;
-- No JWT, ordinary customer, ordinary rescuer, blocked admin: no Admin data.
do $denied$
declare who text; v_name text;
begin
  foreach who in array array['','e1000000-0000-4000-8000-000000000007',
    'e1000000-0000-4000-8000-000000000008','e1000000-0000-4000-8000-000000000006'] loop
    perform set_config('request.jwt.claim.sub',who,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',who,'role','authenticated')::text,true);
    perform pg_temp.check_true(not public.is_admin(),'denied identity is_admin');
    perform pg_temp.check_true(not public.has_admin_role(array['super_admin','operator']),'denied identity role');
    perform pg_temp.check_true((select count(*)=0 from public.admin_profiles),'no admin profiles');
    perform pg_temp.check_true((select count(*)=0 from public.admin_audit_logs),'no audit rows');
    perform pg_temp.check_true((select count(*)=0 from public.admin_notifications),'no notifications');
    foreach v_name in array array['admin_rescue_requests_view','admin_customers_view','admin_rescuers_view',
      'admin_quotes_view','admin_reviews_view','admin_services_view','admin_rescuer_documents_view'] loop
      execute format('select pg_temp.check_true(count(*)=0,%L) from public.%I','no rows in '||v_name,v_name);
    end loop;
    perform pg_temp.expect_error('select public.admin_get_dashboard_stats()','42501');
    perform pg_temp.expect_error('select public.admin_approve_rescuer(''e1000000-0000-4000-8000-000000000008'')','42501');
    perform pg_temp.expect_error('select public.admin_cancel_request(''e3000000-0000-4000-8000-000000000001'',''test'')','42501');
    perform pg_temp.expect_error('select public.admin_log_action(''forged'')','42501');
    perform pg_temp.expect_error('insert into public.admin_profiles(id,full_name,role) values (''e1000000-0000-4000-8000-000000000007'',''Escalation'',''super_admin'')','42501');
  end loop;
end;
$denied$;

-- Role matrix: each view returns rows only for its allowed roles.
do $roles$
declare i int; stats jsonb;
begin
  for i in 1..5 loop
    perform set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-'||lpad(i::text,12,'0'),true);
    perform pg_temp.check_true(public.is_admin(),'active role '||i);
    perform pg_temp.check_true((select count(*)=6 from public.admin_profiles),'admin directory');
    perform pg_temp.check_true((select (count(*)>0)=(i in (1,2,3)) from public.admin_customers_view),'customer gate '||i);
    perform pg_temp.check_true((select (count(*)>0)=(i in (1,2,4)) from public.admin_rescuers_view),'rescuer gate '||i);
    perform pg_temp.check_true((select (count(*)>0)=(i in (1,5)) from public.admin_quotes_view),'finance gate '||i);
    perform pg_temp.check_true((select (count(*)>0)=(i in (1,2,3)) from public.admin_reviews_view),'reviews gate '||i);
    perform pg_temp.check_true((select (count(*)>0)=(i in (1,4)) from public.admin_rescuer_documents_view),'document metadata gate '||i);
    if i in (2,3) then
      perform pg_temp.check_true((select count(*)=0 from public.admin_rescue_requests_view where quote_amount is not null),'no finance leakage from request view');
    end if;
    stats:=public.admin_get_dashboard_stats();
    perform pg_temp.check_true((stats->>'revenue_visible')::boolean=(i in (1,5)),'revenue visibility');
    perform pg_temp.check_true((stats->>'today_revenue')::numeric=case when i in (1,5) then 500000 else 0 end,'revenue amount');
    if i not in (1,2) then
      perform pg_temp.expect_error('select public.admin_cancel_request(''e3000000-0000-4000-8000-000000000001'',''wrong role'')','42501');
      perform pg_temp.expect_error('select public.admin_block_rescuer(''e1000000-0000-4000-8000-000000000008'',''wrong role'')','42501');
      perform pg_temp.expect_error('select public.admin_toggle_service((select service_id from public.admin_services_view limit 1),false)','42501');
    end if;
    if i not in (1,4) then
      perform pg_temp.expect_error('select public.admin_approve_rescuer(''e1000000-0000-4000-8000-000000000008'')','42501');
      perform pg_temp.expect_error('select public.admin_reject_rescuer(''e1000000-0000-4000-8000-000000000009'',''wrong role'')','42501');
    end if;
    if i not in (1,2,3) then
      perform pg_temp.expect_error('insert into public.admin_notifications(title,body,target_type) values (''test'',''test'',''all'')','42501');
    end if;
  end loop;
end;
$roles$;

-- Additional malformed metadata and SQL client grant checks.
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000001',true);
select pg_temp.expect_error('update public.admin_service_catalog set base_price=-1 where service_code=''towing''','23514');
select pg_temp.expect_error('update public.admin_service_catalog set admin_code=''FORGED'' where service_code=''towing''','42501');
select pg_temp.expect_error('update public.admin_profiles set role=''root'' where id=''e1000000-0000-4000-8000-000000000002''','23514');
select pg_temp.expect_error('update public.admin_profiles set id=gen_random_uuid() where id=auth.uid()','42501');
select pg_temp.expect_error('insert into public.admin_notifications(title,body,target_type,priority) values (''t'',''b'',''all'',''urgent'')','23514');
-- Reviewer mutations + retry does not create another version/audit log.
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000004',true);
select public.admin_approve_rescuer('e1000000-0000-4000-8000-000000000008');
select pg_temp.check_true((public.admin_approve_rescuer('e1000000-0000-4000-8000-000000000008')->>'changed')::boolean=false,'approval retry');
select pg_temp.check_true((select count(*)=1 from public.admin_audit_logs where action='approve_rescuer'),'one approval audit');
select pg_temp.expect_error('select public.admin_reject_rescuer(''e1000000-0000-4000-8000-000000000009'',''  '')','22023');
select public.admin_reject_rescuer('e1000000-0000-4000-8000-000000000009','Thiếu hồ sơ xác minh');
select pg_temp.expect_error('select public.admin_approve_rescuer(''e1000000-0000-4000-8000-000000000009'')','22023');
select pg_temp.expect_error('select public.admin_approve_rescuer(''e1000000-0000-4000-8000-000000000099'')','P0002');

-- Operator: cannot approve; block busy partner must fail before mutation.
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000002',true);
select pg_temp.expect_error('select public.admin_block_rescuer(''e1000000-0000-4000-8000-000000000010'',''busy test'')','P0001');
select public.admin_block_rescuer('e1000000-0000-4000-8000-000000000008','Kiểm tra tuân thủ');
select pg_temp.check_true((select approval_status='suspended' from public.admin_rescuers_view where rescuer_id='e1000000-0000-4000-8000-000000000008'),'blocked mapped to suspended');
select pg_temp.expect_error('select public.admin_toggle_service(null,true)','22023');
select pg_temp.expect_error('select public.admin_toggle_service(''e2000000-0000-4000-8000-000000000099'',false)','P0002');
select public.admin_toggle_service((select service_id from public.admin_services_view where app_service_code='towing'),false);
select pg_temp.check_true((select not is_active from public.admin_services_view where app_service_code='towing'),'toggle off');
update public.admin_service_catalog set base_price=550000 where service_code='towing';
select pg_temp.check_true((select count(*)=1 from public.admin_audit_logs where action='update_system_setting'),'metadata update audited');
select pg_temp.expect_error('update public.rescue_services set is_active=true where code=''towing''','42501');
select pg_temp.expect_error('insert into public.admin_audit_logs(action) values (''forged'')','42501');
select pg_temp.expect_error('delete from public.admin_audit_logs','42501');
select pg_temp.expect_error('select public.admin_cancel_request(''e3000000-0000-4000-8000-000000000001'','' '')','22023');
select pg_temp.expect_error('select public.admin_cancel_request(''e3000000-0000-4000-8000-000000000099'',''missing'')','P0002');
select public.admin_cancel_request('e3000000-0000-4000-8000-000000000001','Hủy đơn searching');
select public.admin_cancel_request('e3000000-0000-4000-8000-000000000002','Hủy đơn có phân công');
select public.admin_cancel_request('e3000000-0000-4000-8000-000000000003','Hủy đơn arriving');
select pg_temp.expect_error('select public.admin_cancel_request(''e3000000-0000-4000-8000-000000000004'',''in progress'')','22023');
select pg_temp.expect_error('select public.admin_cancel_request(''e3000000-0000-4000-8000-000000000005'',''completed'')','22023');
select pg_temp.expect_error('select public.admin_cancel_request(''e3000000-0000-4000-8000-000000000006'',''cancelled'')','22023');
select pg_temp.expect_error('select public.admin_cancel_request(''e3000000-0000-4000-8000-000000000001'',''retry'')','22023');
select public.admin_block_rescuer('e1000000-0000-4000-8000-000000000010','Ca trực đã kết thúc');

-- Support creates notifications, cannot forge actor or target, cannot modify roles.
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000003',true);
insert into public.admin_notifications(title,body,target_type,priority) values('  Cảnh báo  ','Nội dung kiểm thử','all','high');
select pg_temp.check_true((select created_by=auth.uid() and title='Cảnh báo' from public.admin_notifications limit 1),'notification actor/title');
select pg_temp.expect_error('insert into public.admin_notifications(title,body,target_type,created_by) values (''t'',''b'',''all'',''e1000000-0000-4000-8000-000000000001'')','42501');
select pg_temp.expect_error('insert into public.admin_notifications(title,body,target_type) values (''t'',''b'',''single_customer'')','P0002');
select pg_temp.expect_error('insert into public.admin_notifications(title,body,target_type,target_user_id) values (''t'',''b'',''single_rescuer'',''e1000000-0000-4000-8000-000000000007'')','P0002');
insert into public.admin_notifications(title,body,target_type,target_user_id)
values('Riêng','Nội dung','single_customer','e1000000-0000-4000-8000-000000000007');
update public.admin_profiles set role='super_admin' where id=auth.uid();
select pg_temp.check_true(not public.has_admin_role(array['super_admin']),'support cannot self-promote');

-- Super admin provisions a new operator, blocks and revokes it immediately.
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000001',true);
select pg_temp.expect_error('update public.admin_profiles set status=''blocked'' where id=auth.uid()','22023');
insert into public.admin_profiles(id,full_name,role) values('e1000000-0000-4000-8000-000000000007','New operator','operator');
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000007',true);
select pg_temp.check_true(public.is_admin(),'provisioned operator');
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000001',true);
update public.admin_profiles set status='blocked' where id='e1000000-0000-4000-8000-000000000007';
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000007',true);
select pg_temp.check_true(not public.is_admin(),'blocked immediately loses access');
select pg_temp.expect_error('select public.admin_get_dashboard_stats()','42501');
reset role;
select set_config('request.jwt.claim.sub','',true);

-- Trusted inspection of side effects; check deferred shared constraints too.
set constraints all immediate;
select pg_temp.check_true((select state='cancelled' and version=2 and cancellation_reason_code='system_cancelled'
  from public.rescue_request_assignments where id='e4000000-0000-4000-8000-000000000002'),'assignment sync');
select pg_temp.check_true((select count(*)=1 from public.request_status_events
  where request_id='e3000000-0000-4000-8000-000000000002' and status='cancelled'),'exactly one tracking event');
select pg_temp.check_true((select count(*)=1 from public.rescuer_assignment_events
  where assignment_id='e4000000-0000-4000-8000-000000000002' and state='cancelled'),'exactly one assignment event');
select pg_temp.check_true((select count(*)=3 from public.admin_audit_logs where action='cancel_request'),'cancel audit count');
select pg_temp.check_true((select metadata->>'reason'='Hủy đơn có phân công' and admin_id='e1000000-0000-4000-8000-000000000002'
  from public.admin_audit_logs where action='cancel_request' and target_id='e3000000-0000-4000-8000-000000000002'),'reason/actor audit');
select pg_temp.check_true((select not is_online from public.rescuer_online_status where rescuer_id='e1000000-0000-4000-8000-000000000010'),'blocked partner offline');
select pg_temp.check_true((select count(*)=2 from public.admin_audit_logs where action='send_notification'),'notifications audited');
select pg_temp.check_true((select status='in_progress' from public.rescue_requests where id='e3000000-0000-4000-8000-000000000004'),'denied mutation left state unchanged');

-- Shared customer owner RLS still limits the original table, even with Admin views.
set local role authenticated;
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000011',true);
select pg_temp.check_true((select count(*)=1 from public.customer_profiles),'customer owner profile');
select pg_temp.check_true((select count(*)=1 from public.rescue_requests),'customer owner requests');
select pg_temp.check_true((select count(*)=0 from public.rescue_services where code='towing'),'inactive service hidden');
select pg_temp.check_true((select count(*)=0 from public.admin_rescue_requests_view),'no escalation through views');
reset role;
rollback;
select 'PASS: Admin SQL/RLS/roles/RPC/audit regression; fixtures rolled back' as result;

-- Additional manual integration gates (not asserted by this single-session test):
-- 1. Login with real local Supabase Auth JWTs through PostgREST, including anon.
-- 2. Concurrent sessions: approve vs profile edit; cancel vs claim/status/quote;
--    revoke admin role vs RPC; validate lock timeout and retry behavior.
-- 3. Storage document object download remains owner-only; do not weaken its
--    restrictive policy to implement a reviewer download shortcut.
-- 4. Notification INSERT logs intent only, not FCM delivery.
