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

-- Uses the original V1 disposable fixture prefix (users, roles, assertion helpers).
INSERT INTO public.rescue_requests(id,customer_id,client_request_id,vehicle_kind,service_code,
 location_text,location_confirmed,contact_name,contact_phone,status)
VALUES('a1590000-0000-4000-8000-000000000001','a1500000-0000-4000-8000-000000000001',
 gen_random_uuid(),'motorbike','tire','Local gate fixture',true,'Gate fixture','0900000001','searching');
SELECT set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000001',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.sc_assert('active customer display codes allowed',
 (SELECT count(*)=1 FROM public.customer_request_display_codes(ARRAY['a1590000-0000-4000-8000-000000000001'::uuid])));
SELECT pg_temp.sc_assert('active customer nearby allowed',
 (SELECT count(*)>=0 FROM public.get_nearby_providers(21.0285,105.8542,15)));
SELECT pg_temp.sc_error('invalid nearby radius','select * from public.get_nearby_providers(21,105,''Infinity'')','22023');
SELECT pg_temp.sc_error('invalid nearby coordinate','select * from public.get_nearby_providers(''NaN'',105,10)','22023');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000009',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.sc_assert('other customer cannot see display codes',
 (SELECT count(*)=0 FROM public.customer_request_display_codes(ARRAY['a1590000-0000-4000-8000-000000000001'::uuid])));
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000002',true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.sc_error('rescuer cannot use customer nearby','select * from public.get_nearby_providers(21,105,10)','42501','SYSTEM_CUSTOMER_REQUIRED');
RESET ROLE;
SET LOCAL ROLE anon;
SELECT pg_temp.sc_error('anon display codes denied','select * from public.customer_request_display_codes(null)','42501');
SELECT pg_temp.sc_error('anon nearby denied','select * from public.get_nearby_providers(21,105,10)','42501');
RESET ROLE;

-- Audit and execute every non-extension authenticated application RPC under
-- locked and suspended customer/rescuer identities, not just the two repaired RPCs.
DO $$
DECLARE actor uuid; status_value text; f record; invocation text;
BEGIN
 FOREACH actor IN ARRAY ARRAY['a1500000-0000-4000-8000-000000000001'::uuid,'a1500000-0000-4000-8000-000000000002'::uuid] LOOP
  FOREACH status_value IN ARRAY ARRAY['locked','suspended'] LOOP
   PERFORM set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000003',true);
   EXECUTE 'set local role authenticated';
   PERFORM public.admin_apply_system_account_control(actor,status_value,null,false,
    (public.admin_get_system_account_control(actor)->>'version')::bigint,'full RPC session matrix',true);
   EXECUTE 'reset role';
   PERFORM set_config('request.jwt.claim.sub',actor::text,true);
   FOR f IN SELECT p.oid,p.proname,p.proargtypes,p.prosecdef,p.proconfig,l.lanname
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace JOIN pg_language l ON l.oid=p.prolang
    WHERE n.nspname='public' AND p.prokind='f' AND p.prorettype<>'trigger'::regtype
     AND has_function_privilege('authenticated',p.oid,'execute')
     AND p.proname NOT IN ('get_public_system_config','system_session_allowed','is_admin','has_admin_role')
     AND NOT EXISTS(SELECT 1 FROM pg_depend d WHERE d.classid='pg_proc'::regclass AND d.objid=p.oid AND d.deptype='e') LOOP
    invocation:=format('select public.%I(%s)',f.proname,
      (SELECT string_agg('null::'||format_type(t,null),',' ORDER BY ord) FROM unnest(f.proargtypes::oid[]) WITH ORDINALITY x(t,ord)));
    IF NOT f.prosecdef THEN
     -- The review RPC is SECURITY INVOKER and protected by restrictive RLS.
     -- Use valid input so argument validation does not mask the RLS denial.
     IF f.proname<>'submit_customer_request_review' THEN RAISE EXCEPTION 'Unreviewed invoker RPC: %',f.proname; END IF;
     invocation:='select public.submit_customer_request_review(''a1590000-0000-4000-8000-000000000001'',5,null)';
    END IF;
    EXECUTE 'set local role authenticated';
    PERFORM pg_temp.sc_error(status_value||' '||actor||' '||f.oid::regprocedure,invocation,'42501',CASE WHEN f.prosecdef THEN 'SYSTEM_SESSION_DENIED' ELSE NULL END);
    EXECUTE 'reset role';
   END LOOP;
  END LOOP;
 END LOOP;
END $$;

SELECT pg_temp.sc_assert('all client definers fixed search_path',NOT EXISTS(
 SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef
 AND has_function_privilege('authenticated',p.oid,'execute')
 AND NOT EXISTS(SELECT 1 FROM pg_depend d WHERE d.classid='pg_proc'::regclass AND d.objid=p.oid AND d.deptype='e')
 AND NOT EXISTS(SELECT 1 FROM unnest(p.proconfig) v WHERE v LIKE 'search_path=%')));
SELECT pg_temp.sc_assert('only intentional public config permits anon',NOT EXISTS(
 SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef
 AND p.prorettype<>'trigger'::regtype AND has_function_privilege('anon',p.oid,'execute') AND p.proname<>'get_public_system_config'
 AND NOT EXISTS(SELECT 1 FROM pg_depend d WHERE d.classid='pg_proc'::regclass AND d.objid=p.oid AND d.deptype='e')));
SELECT pg_temp.sc_assert('repaired entrypoints deny service_role',
 NOT has_function_privilege('service_role','public.customer_request_display_codes(uuid[])','execute') AND
 NOT has_function_privilege('service_role','public.get_nearby_providers(double precision,double precision,double precision)','execute'));

SELECT set_config('request.jwt.claim.sub','a1500000-0000-4000-8000-000000000003',true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE roles jsonb; permissions jsonb; n integer:=0;
BEGIN
 FOREACH roles IN ARRAY ARRAY['["super_admin",null]'::jsonb,'[null]','["config.read",null]',
 '["config.read","config.write",null]','["super_admin",""]','["super_admin","invalid"]',
 '["super_admin",1]','["super_admin",{}]','["super_admin",[]]','["super_admin",true]',
 '["super_admin","operator","operator"]',to_jsonb(ARRAY['super_admin',NULL]::text[])] LOOP
  n:=n+1;
  permissions:=jsonb_build_object('customer',roles,'rescuer',jsonb_build_array('super_admin'),
    'payment',jsonb_build_array('super_admin'),'security',jsonb_build_array('super_admin'));
  PERFORM pg_temp.sc_error('permission invalid elements '||n,
    format('select public.admin_apply_system_config(%L,1,''negative permission matrix'',true)',jsonb_build_object('security.role_permissions',permissions)),
    '22023','SYSTEM_CONFIG_INVALID_PERMISSIONS');
 END LOOP;
 PERFORM pg_temp.sc_assert('valid permission array compatible',public.admin_apply_system_config(
  '{"security.role_permissions":{"customer":["super_admin","support"],"rescuer":["super_admin"],"payment":["super_admin","finance"],"security":["super_admin"]}}',
  1,'positive permission matrix',true)->>'version'='2');
END $$;
RESET ROLE;
SELECT 'SYSTEM_SECURITY_RPC_HARDENING_PASS' AS result,count(*) AS assertions FROM pg_temp.system_results;
ROLLBACK;
